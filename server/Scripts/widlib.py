# -*- coding: utf-8 -*-
"""
============================================================
wid.chr.cc 部署公共库（SSH / SFTP 封装）
创建时间: 2026-09-23
作用: 为 init_wid_db.py / deploy_wid_site.py / test_wid_api.py 提供统一的
      服务器连接、执行、上传工具。凭据沿用闲颜项目的约定
      （E:/project/flutter/f/xianyan/Scripts/upload_server_code.py）。
注意: 本文件只是副本改写，不修改闲颜项目任何文件。
用法:
  from widlib import connect, run, sftp
============================================================
"""
import os
import posixpath
import subprocess
import time

import paramiko

# ---------------- 服务器凭据（同闲颜项目） ----------------
HOST = '123.207.67.197'
PORT = 2026
USER = 'root'
PASS = '520kiss...'

# ---------------- 站点路径 ----------------
SITE_ROOT = '/www/wwwroot/wid.chr.cc'
STAGING_ROOT = '/www/wwwroot/_wid_staging'
BACKUP_ROOT = '/www/wwwroot/_backup_wid'
NGINX_EXT_DIR = '/www/server/panel/vhost/nginx/extension/wid.chr.cc'
NGINX_EXT_FILE = NGINX_EXT_DIR + '/deny_internal.conf'

# ---------------- 远端 PHP ----------------
PHP_BIN = '/www/server/php/74/bin/php'

# 站点域名（外网验证用）
SITE_DOMAIN = 'wid.chr.cc'

# 上传时跳过的本地路径片段（相对 src/）
SKIP_DIRS = {'.git', '__pycache__', 'node_modules', '.DS_Store', '.idea'}
SKIP_SUFFIX = ('.pyc', '.log', '.bak')


def connect(timeout=20):
    """建立 SSH 连接"""
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(HOST, port=PORT, username=USER, password=PASS, timeout=timeout)
    return ssh


class Remote:
    """一次性封装 SSH + SFTP，避免每个脚本重复样板代码"""

    def __init__(self, verbose=True):
        self.ssh = connect()
        self._sftp = None
        self.verbose = verbose

    # ---- 生命周期 ----
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    def close(self):
        try:
            if self._sftp:
                self._sftp.close()
        finally:
            self.ssh.close()

    @property
    def sftp(self):
        if self._sftp is None:
            self._sftp = self.ssh.open_sftp()
        return self._sftp

    # ---- 执行 ----
    def run(self, cmd, timeout=180, check=False):
        """执行命令，返回 (exit_code, stdout, stderr)"""
        stdin, stdout, stderr = self.ssh.exec_command(cmd, timeout=timeout)
        out = stdout.read().decode('utf-8', errors='ignore')
        err = stderr.read().decode('utf-8', errors='ignore')
        code = stdout.channel.recv_exit_status()
        if check and code != 0:
            raise RuntimeError('远程命令失败(%s): %s\n%s' % (code, cmd, err.strip()))
        return code, out, err

    def run_ok(self, cmd, timeout=180):
        """执行命令，返回 (是否成功, stdout, stderr)"""
        code, out, err = self.run(cmd, timeout=timeout)
        return code == 0, out, err

    # ---- 文件 ----
    def exists(self, path):
        try:
            self.sftp.stat(path)
            return True
        except IOError:
            return False

    def mkdir_p(self, path):
        if path in ('', '/', '.'):
            return
        try:
            self.sftp.stat(path)
            return
        except IOError:
            pass
        parent = posixpath.dirname(path)
        if parent and parent != path:
            self.mkdir_p(parent)
        try:
            self.sftp.mkdir(path)
        except IOError:
            pass

    def put(self, local_path, remote_path, mode=None):
        self.mkdir_p(posixpath.dirname(remote_path))
        self.sftp.put(local_path, remote_path)
        if mode is not None:
            self.sftp.chmod(remote_path, mode)
        return os.path.getsize(local_path)

    def put_text(self, text, remote_path, mode=None):
        self.mkdir_p(posixpath.dirname(remote_path))
        with self.sftp.open(remote_path, 'w') as fh:
            fh.write(text)
        if mode is not None:
            self.sftp.chmod(remote_path, mode)

    def read_text(self, remote_path):
        with self.sftp.open(remote_path, 'r') as fh:
            return fh.read().decode('utf-8', errors='ignore')

    def remove(self, remote_path):
        try:
            self.sftp.remove(remote_path)
            return True
        except IOError:
            return False

    # ---- 上传目录 ----
    def upload_tree(self, local_root, remote_root, skip_dirs=None, skip_suffix=None, log=None):
        """递归上传目录，返回 (上传数, 跳过数, 总字节)"""
        skip_dirs = skip_dirs or SKIP_DIRS
        skip_suffix = skip_suffix or SKIP_SUFFIX
        uploaded = skipped = total_bytes = 0
        self.mkdir_p(remote_root)
        for dirpath, dirnames, filenames in os.walk(local_root):
            dirnames[:] = [d for d in dirnames if d not in skip_dirs]
            rel_dir = os.path.relpath(dirpath, local_root).replace('\\', '/')
            remote_dir = remote_root if rel_dir == '.' else posixpath.join(remote_root, rel_dir)
            self.mkdir_p(remote_dir)
            for name in filenames:
                if name in skip_dirs or name.endswith(skip_suffix):
                    skipped += 1
                    continue
                local_file = os.path.join(dirpath, name)
                remote_file = posixpath.join(remote_dir, name)
                try:
                    size = self.put(local_file, remote_file)
                    uploaded += 1
                    total_bytes += size
                    if log:
                        log('  ↑ %s (%d B)' % (posixpath.relpath(remote_file, remote_root), size))
                except Exception as exc:  # noqa: BLE001
                    skipped += 1
                    if log:
                        log('  ! 上传失败 %s: %s' % (name, exc))
        return uploaded, skipped, total_bytes


def remote_lint(remote, root, log=print):
    """
    对远端目录下所有 .php 做语法检查。
    返回 (通过数, 失败列表[(相对路径, 错误摘要)])。
    先上传到 staging 再检查，保证「语法不过不落盘」。
    """
    code, out, err = remote.run(
        "find %s -name '*.php' -type f | sort" % root, timeout=60)
    files = [line.strip() for line in out.splitlines() if line.strip()]
    failed = []
    for path in files:
        code, out2, err2 = remote.run("%s -l %s" % (PHP_BIN, path), timeout=60)
        if code != 0:
            detail = (err2 or out2).strip().splitlines()
            failed.append((posixpath.relpath(path, root), detail[0] if detail else 'unknown'))
    return len(files) - len(failed), failed


def ts():
    return time.strftime('%Y%m%d_%H%M%S')


def log(msg, level='INFO'):
    print('[%s] [%s] %s' % (time.strftime('%H:%M:%S'), level, msg), flush=True)


# ============================================================
# HTTP 请求（外网）
# ============================================================
BROWSER_UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36')

_STATUS_MARK = '__HTTP_STATUS__'


def http_request(method, url, headers=None, body=None, timeout=20):
    """
    发一次 HTTP 请求，返回 (状态码, 响应文本)。

    默认走 curl 子进程而不是 Python urllib —— 与闲颜项目的结论一致：
    这条链路上 Python 的 TLS 栈偶发 `UNEXPECTED_EOF_WHILE_READING`，
    而 curl 直连稳定。请求头里带真实浏览器 UA，避免触发宝塔 WAF 的
    人机校验（无 UA 的非浏览器请求会被挑战页顶回）。
    """
    args = ['curl', '-sS', '--compressed', '-m', str(timeout), '-X', method,
            '-A', BROWSER_UA, '-w', '\n' + _STATUS_MARK + '%{http_code}']
    if body:
        args += ['-H', 'Content-Type: application/json', '--data-binary', body.decode('utf-8')
                 if isinstance(body, bytes) else body]
    for key, value in (headers or {}).items():
        args += ['-H', '%s: %s' % (key, value)]
    args.append(url)
    try:
        proc = subprocess.run(args, capture_output=True, timeout=timeout + 10)
        out = proc.stdout.decode('utf-8', errors='ignore')
        err = proc.stderr.decode('utf-8', errors='ignore')
        if _STATUS_MARK in out:
            text, _, status = out.rpartition(_STATUS_MARK)
            return int(status.strip() or 0), text.rstrip('\n')
        if err.strip():
            return 0, err.strip()
        return 0, out
    except Exception as exc:  # noqa: BLE001
        return 0, str(exc)
