# -*- coding: utf-8 -*-
"""
============================================================
Prue Widgets（win-muyu）服务器远程执行助手
创建时间: 2026-09-23
名称: ssh_client.py
作用: 在主服务器（123.207.67.197:2026）上执行单条 shell 命令，用于运维排查。
      凭据与连接细节集中在 Scripts/widlib.py。
      参考实现: E:/project/flutter/f/xianyan/Scripts/remote_exec.py
（本文件为副本改写，不修改闲颜项目任何文件）
依赖: paramiko（venv: C:/Users/无书/.workbuddy/binaries/python/envs/default）
用法:
  python Scripts/ssh_client.py "systemctl is-active nginx"     # 单条命令
  python Scripts/ssh_client.py --file /tmp/x.sh                # 多行脚本
============================================================
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from widlib import Remote  # noqa: E402


def run(cmd, timeout=180):
    """连接服务器执行命令，返回 (exit_code, stdout, stderr)"""
    with Remote(verbose=False) as remote:
        return remote.run(cmd, timeout=timeout)


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(2)
    if args[0] == '--file':
        with open(args[1], 'r', encoding='utf-8') as f:
            cmd = f.read()
    else:
        cmd = ' '.join(args)
    code, out, err = run(cmd)
    if out:
        print(out, end='' if out.endswith('\n') else '\n')
    if err:
        print('[stderr]', file=sys.stderr)
        print(err, end='' if err.endswith('\n') else '\n', file=sys.stderr)
    if code != 0:
        print(f'[exit={code}]', file=sys.stderr)
    sys.exit(code)


if __name__ == '__main__':
    main()
