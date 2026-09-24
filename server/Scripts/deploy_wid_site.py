# -*- coding: utf-8 -*-
"""
============================================================
wid.chr.cc 站点部署
创建时间: 2026-09-23
名称: deploy_wid_site.py
作用: 把本地 src/ 部署到 /www/wwwroot/wid.chr.cc：
      1) 上传到 staging 目录
      2) 远端 php -l 全量语法预检（任何文件不过即中止，绝不带病上线）
      3) 备份现有站点目录（tar 到 /www/wwwroot/_backup_wid/）
      4) 同步到站点目录并修正属主 / 权限
      5) 写入 app/config.php（已存在则保留，除非 --force-config）
      6) 写入 nginx extension 加固文件并 reload（先 nginx -t）
前置: 先执行 python Scripts/init_wid_db.py（需要 .wid_secrets.json）
用法:
  python Scripts/deploy_wid_site.py                  # 全量部署
  python Scripts/deploy_wid_site.py --no-nginx       # 只传文件，不动 nginx
  python Scripts/deploy_wid_site.py --force-config   # 重新生成 config.php
  python Scripts/deploy_wid_site.py --dry-run        # 只打印计划
依赖: paramiko
============================================================
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import widlib  # noqa: E402
from widlib import (BACKUP_ROOT, NGINX_EXT_DIR, NGINX_EXT_FILE, PHP_BIN,  # noqa: E402
                    SITE_ROOT, STAGING_ROOT, Remote, log, remote_lint, ts)

BASE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(BASE)
SRC = os.path.join(PROJECT, 'src')
SECRETS_FILE = os.path.join(BASE, '.wid_secrets.json')

# 站点根目录下不需要同步到线上的目录（本地专用）
SKIP_DIRS = {'__pycache__', '.git', 'node_modules', '.idea'}

NGINX_CONF = """# ==========================================================
# wid.chr.cc —— 站点内部隔离与路由
# 由 Scripts/deploy_wid_site.py 生成，宝塔面板改写 vhost 主文件时不受影响。
# 修改后执行: nginx -t && nginx -s reload
#
# ⚠️ 两个必须用 regex location 的坑（都实测过）：
#   1) 不能用 `location ^~ /api/`：^~ 优先级高于 PHP 的 regex location，
#      try_files 回落到 /api/index.php 后会被当成静态文件直出 PHP 源码。
#   2) 宝塔默认的 `location ~ .*\\.(js|css)?$` 里 (js|css)? 是可选的，
#      因此它会匹配**所有**路径，且 regex 优先于普通前缀 location，
#      导致 /dashboard 这类无扩展名路由直接 404。
#      本文件的 regex 在 include 顺序上位于它之前，故能先命中。
# ==========================================================

# 1) 应用代码 / 内容 / SQL 一律禁止外部访问
#    （app/config.php 含数据库口令，api-v3.md 与 schema.sql 属于内部资料）
location ^~ /app/     { return 404; }
location ^~ /content/ { return 404; }
location ^~ /sql/     { return 404; }

# 1.5) 关闭 FastCGI 错误页拦截。
#      宝塔的 nginx.conf 在 http 段全局写了 fastcgi_intercept_errors on，
#      导致 PHP 返回的 404 被替换成 HTML 错误页 —— 接口的 JSON 契约会被破坏
#      （实测 /api/v1/profile 设备不存在时拿到了 404.html 而不是业务错误 JSON）。
#      这里在 server 段覆盖为 off；nginx 生成的 404 仍会走 error_page /404.html。
#      注意：必须写在 server 段（不能只写进 location），
#      因为 try_files 内部重定向后生效的是 PHP location 的继承值。
fastcgi_intercept_errors off;

# 2) 接口前端控制器：/api/ 下除 index.php 以外的路径都交给它
#    REQUEST_URI 保持不变，路由据此还原真实路径
#    ⚠️ 末尾必须显式带上 ?$args：try_files 的最后一项是 URI，
#       不写 $args 的话查询串会在内部重定向时被丢掉（实测踩过，
#       表现为 /version?platform=windows 拿不到任何参数）。
location ~ ^/api/(?!index\\.php) {
    try_files $uri /api/index.php?$args;
}

# 3) 无扩展名的前台路由：/dashboard -> /dashboard.php
#    ⚠️ 绝不能用 `try_files $uri $uri/ $uri.php`：try_files 的**中间参数**
#       命中文件时会留在当前 location 里按静态文件返回，于是 .php 被当成
#       文本直出（实测 /changelog、/docs 泄露过整份源码）。
#       必须用 rewrite ... last 触发内部重定向，交给 PHP location 执行。
#    末尾的 [^/] 让带斜杠的目录路径（/admin/）继续走后面的默认处理。
location ~ ^/[^.]*[^/]$ {
    if (-f "${document_root}${uri}.php") {
        rewrite ^ "${uri}.php" last;
    }
    try_files $uri =404;
}

# 4) /sitemap.xml 走动态生成
location = /sitemap.xml {
    rewrite ^ /sitemap.php last;
}

# 5) 目录列表关闭；隐藏文件拒绝（.well-known 除外，保留证书验证能力）
autoindex off;
location ~ /\\.(?!well-known/) {
    deny all;
}

# 6) 基础安全响应头
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header X-Frame-Options "SAMEORIGIN" always;
"""


def load_secrets():
    if not os.path.isfile(SECRETS_FILE):
        log('缺少 %s，请先执行 python Scripts/init_wid_db.py' % SECRETS_FILE, 'ERROR')
        sys.exit(1)
    with open(SECRETS_FILE, 'r', encoding='utf-8') as fh:
        return json.load(fh)


def save_secrets(data):
    with open(SECRETS_FILE, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)


def build_config(template_text, secrets, admin_hash, session_secret):
    """用配置模板渲染最终 config.php"""
    out = template_text
    out = out.replace('__DB_PASS__', secrets.get('db_pass', 'wid'))
    out = out.replace('__ADMIN_PW_HASH__', admin_hash)
    out = out.replace('__SESSION_SECRET__', session_secret)
    # 模板里的单引号需要转义为 PHP 安全字面量
    out = out.replace("'__DB_PASS__'", "'%s'" % secrets.get('db_pass', 'wid'))
    return out


def php_hash_password(remote, password):
    """在服务器上用 PHP 自身生成 password_hash，保证与 password_verify 完全兼容"""
    cmd = "%s -r %s" % (PHP_BIN, sh_quote("echo password_hash('%s', PASSWORD_DEFAULT);" % password.replace("'", "\\'")))
    code, out, err = remote.run(cmd)
    hashed = out.strip()
    if code != 0 or not hashed.startswith('$'):
        log('生成口令哈希失败：%s' % (err.strip() or out.strip()), 'ERROR')
        sys.exit(1)
    return hashed


def sh_quote(text):
    return "'" + text.replace('\\', '\\\\').replace("'", "'\"'\"'") + "'"


def ensure_admin_password(secrets, force=False):
    """确保本地保存了后台口令；缺失则生成一个强口令。返回 (口令, 是否新生成)"""
    password = secrets.get('admin_password')
    if password and not force:
        return password, False
    import secrets as pysecrets
    alphabet = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    password = ''.join(pysecrets.choice(alphabet) for _ in range(20))
    secrets['admin_password'] = password
    return password, True


def write_config(remote, secrets, force=False):
    remote_template = os.path.join(SRC, 'app', 'config.dist.php')
    with open(remote_template, 'r', encoding='utf-8') as fh:
        template = fh.read()

    target = SITE_ROOT + '/app/config.php'
    if remote.exists(target) and not force:
        log('app/config.php 已存在，保留原文件（如需重建加 --force-config）')
        return False

    password, is_new = ensure_admin_password(secrets, force=force)
    admin_hash = php_hash_password(remote, password)
    session_secret = secrets.get('session_secret')
    if not session_secret or force:
        import secrets as pysecrets
        session_secret = pysecrets.token_hex(32)
    secrets['session_secret'] = session_secret

    content = build_config(template, secrets, admin_hash, session_secret)
    remote.put_text(content, target, mode=0o640)
    save_secrets(secrets)

    log('已写入 app/config.php（权限 640）')
    if is_new:
        log('-' * 58)
        log('后台口令（请立即保存，本地也已存于 Scripts/.wid_secrets.json）：')
        log('    %s' % password)
        log('后台地址：https://%s/admin/' % widlib.SITE_DOMAIN)
        log('-' * 58)
    return True


def main():
    args = sys.argv[1:]
    dry_run = '--dry-run' in args
    skip_nginx = '--no-nginx' in args
    force_config = '--force-config' in args

    if not os.path.isdir(SRC):
        log('找不到源码目录 %s' % SRC, 'ERROR')
        sys.exit(1)

    secrets = load_secrets()

    log('=' * 58)
    log('wid.chr.cc 站点部署')
    log('服务器: %s@%s:%s' % (widlib.USER, widlib.HOST, widlib.PORT))
    log('本地:   %s' % SRC)
    log('远端:   %s' % SITE_ROOT)
    if dry_run:
        log('模式:   DRY-RUN（只打印计划，不做任何改动）')
    log('=' * 58)

    if dry_run:
        total = 0
        for dirpath, dirnames, filenames in os.walk(SRC):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
            total += len(filenames)
        log('待上传文件约 %d 个' % total)
        log('nginx 配置将写入 %s' % NGINX_EXT_FILE)
        return

    remote = Remote()
    try:
        # ---------- 1. 上传到 staging ----------
        log('清空并重建 staging 目录 …')
        remote.run('rm -rf %s && mkdir -p %s' % (STAGING_ROOT, STAGING_ROOT))
        log('上传源码 …')
        uploaded, skipped, total_bytes = remote.upload_tree(SRC, STAGING_ROOT, skip_dirs=SKIP_DIRS)
        log('上传完成：%d 个文件，%.1f KB，跳过 %d' % (uploaded, total_bytes / 1024.0, skipped))

        # ---------- 2. 远端语法预检 ----------
        log('远端 php -l 语法预检 …')
        passed, failed = remote_lint(remote, STAGING_ROOT)
        if failed:
            log('有 %d 个文件语法不通过，已中止部署：' % len(failed), 'ERROR')
            for rel, detail in failed[:20]:
                log('    %s -> %s' % (rel, detail), 'ERROR')
            sys.exit(1)
        log('语法预检通过：%d 个 PHP 文件' % passed)

        # ---------- 3. 备份 ----------
        remote.mkdir_p(BACKUP_ROOT)
        stamp = ts()
        if remote.exists(SITE_ROOT):
            archive = '%s/wid_site_%s.tar.gz' % (BACKUP_ROOT, stamp)
            remote.run('tar -czf %s -C %s . 2>/dev/null || true' % (archive, SITE_ROOT))
            code, out, _ = remote.run('ls -l %s | awk \'{print $5}\'' % archive)
            log('已备份现有站点 -> %s (%s bytes)' % (archive, out.strip()))
            # 只保留最近 10 个备份
            remote.run("ls -1t %s/wid_site_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -f" % BACKUP_ROOT)
        else:
            remote.mkdir_p(SITE_ROOT)
            log('站点目录不存在，已创建')

        # ---------- 4. 同步 ----------
        log('同步文件到站点目录 …')
        remote.run('cp -a %s/. %s/' % (STAGING_ROOT, SITE_ROOT), timeout=300)
        # 清掉宝塔建站时留下的空 index.html（否则会抢占目录索引）
        remote.run('rm -f %s/index.html' % SITE_ROOT)
        remote.run('rm -rf %s' % STAGING_ROOT)

        # ---------- 5. 配置与运行时目录 ----------
        remote.mkdir_p(SITE_ROOT + '/app/log')
        write_config(remote, secrets, force=force_config)

        # ---------- 6. 权限 ----------
        log('修正属主与权限 …')
        remote.run('chown -R www:www %s' % SITE_ROOT)
        remote.run("find %s -type d -exec chmod 755 {} \\;" % SITE_ROOT)
        remote.run("find %s -type f -exec chmod 644 {} \\;" % SITE_ROOT)
        remote.run('chmod 640 %s/app/config.php 2>/dev/null || true' % SITE_ROOT)
        remote.run('chmod 755 %s/app/log' % SITE_ROOT)

        # ---------- 7. nginx ----------
        if skip_nginx:
            log('按参数跳过 nginx 配置')
        else:
            log('写入 nginx 加固配置 …')
            remote.mkdir_p(NGINX_EXT_DIR)
            remote.put_text(NGINX_CONF, NGINX_EXT_FILE, mode=0o644)
            code, out, err = remote.run('nginx -t 2>&1')
            if code != 0:
                log('nginx -t 未通过，已保留旧配置：%s' % (out + err).strip()[:500], 'ERROR')
                remote.remove(NGINX_EXT_FILE)
                sys.exit(1)
            log('nginx -t 通过，重载 nginx')
            remote.run('nginx -s reload')

        # ---------- 7.5 刷新 OPcache ----------
        # 本机 php.ini 的 opcache.revalidate_freq = 60，意味着新上传的代码
        # 最多 60 秒后才生效。部署完立刻验证会拿到旧行为（实测踩过：
        # 改了代码但接口仍按旧逻辑跑，排查了很久）。
        # reload 不足以清空共享内存，必须 restart（PHP-FPM 重启约 1 秒）。
        if '--no-opcache-flush' in args:
            log('按参数跳过 OPcache 刷新（注意：新代码最多 60 秒后才生效）', 'WARN')
        else:
            log('刷新 OPcache（重启 php-fpm-74）…')
            code, out, err = remote.run('systemctl restart php-fpm-74 && sleep 1 && systemctl is-active php-fpm-74')
            state = out.strip().splitlines()[-1] if out.strip() else 'unknown'
            if code != 0 or state != 'active':
                log('php-fpm-74 状态异常：%s %s' % (state, err.strip()[:200]), 'ERROR')
                sys.exit(1)
            log('php-fpm-74 已重启并处于 active 状态')

        # ---------- 8. 汇总 ----------
        log('=' * 58)
        code, out, _ = remote.run("find %s -type f | wc -l" % SITE_ROOT)
        log('站点文件总数：%s' % out.strip())
        code, out, _ = remote.run('ls -l %s/app/config.php' % SITE_ROOT)
        log(out.strip())
        log('部署完成 -> https://%s' % widlib.SITE_DOMAIN)
        log('下一步：python Scripts/test_wid_api.py && python Scripts/check_web.py')
        log('=' * 58)
    finally:
        remote.close()


if __name__ == '__main__':
    main()
