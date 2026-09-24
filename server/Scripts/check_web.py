# -*- coding: utf-8 -*-
"""
============================================================
wid.chr.cc 网页检查
创建时间: 2026-09-23
名称: check_web.py
作用: 验证线上各页面与静态资源可正常访问，并检查内部目录确实被 nginx 封禁。
      同时验证外网（经 Cloudflare）与服务器本机两条通道的响应一致。
用法:
  python Scripts/check_web.py                # 双通道检查
  python Scripts/check_web.py --local-only
  python Scripts/check_web.py --remote-only
  python Scripts/check_web.py -v             # 输出每条检查的响应片段
依赖: paramiko
============================================================
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import widlib  # noqa: E402
from widlib import Remote, http_request, log  # noqa: E402

DOMAIN = widlib.SITE_DOMAIN
UA = widlib.BROWSER_UA

# (路径, 期望状态, 期望内容正则, 说明, 最小字节数)
PAGES = [
    ('/', 200, r'功德', '首页落地页', 3000),
    ('/dashboard', 200, r'数据看板', '数据看板', 3000),
    ('/download', 200, r'下载', '下载页', 3000),
    ('/download', 200, r'检查更新', '下载页更新检测表单', 3000),
    ('/changelog', 200, r'更新日志', '更新日志页', 2000),
    ('/docs', 200, r'接口', '接口文档页', 5000),
    ('/sitemap.xml', 200, r'<urlset', '站点地图', 200),
    ('/robots.txt', 200, r'Sitemap', 'robots.txt', 20),
    ('/assets/css/site.css', 200, r'--jade', '站点样式表', 3000),
    ('/assets/js/site.js', 200, r'data-live', '站点脚本', 1000),
    ('/admin/', 200, r'(管理口令|管理后台)', '后台登录页', 800),
    ('/api/v1/health', 200, r'"status"', '健康检查接口', 40),
    ('/api/v1/stats/summary', 200, r'"taps"', '统计接口', 40),
    ('/api/v1/config', 200, r'"config"', '运行时配置接口', 40),
    ('/this-page-does-not-exist', 404, r'(404|不存在)', '404 页面', 50),
]

# 这些路径必须被拒绝（内部源码 / 配置 / 数据库脚本）
DENIED = [
    ('/app/config.php', '应用配置（含数据库口令）'),
    ('/app/config.dist.php', '配置模板'),
    ('/app/schema.sql', '表结构 SQL'),
    ('/app/content/api-v3.md', '接口契约文档源文件'),
    ('/app/bootstrap.php', '引导文件'),
]


def fetch_remote(path):
    """外网请求走 curl 子进程（见 widlib.http_request 的说明）"""
    status, text = http_request('GET', 'https://%s%s' % (DOMAIN, path))
    return status, text.encode('utf-8'), ''


def fetch_local(remote, path):
    cmd = ("curl -sS -m 15 -A '%s' -k -o /tmp/_wid_web -w '%%{http_code}|%%{content_type}' "
           "-H 'Host: %s' 'http://127.0.0.1%s' && echo && wc -c < /tmp/_wid_web && echo '---' && cat /tmp/_wid_web"
           % (UA, DOMAIN, path))
    code, out, err = remote.run(cmd, timeout=60)
    head, _, body = out.partition('---')
    lines = [l.strip() for l in head.strip().split('\n') if l.strip()]
    meta = lines[0] if lines else ''
    size = lines[1] if len(lines) > 1 else '0'
    try:
        status_text, ctype = meta.split('|', 1)
        status = int(status_text)
    except ValueError:
        status, ctype = 0, ''
    return status, body.encode('utf-8'), ctype, int(size or 0)


def check_page(remote, channel, path, want_status, pattern, label, min_bytes, verbose):
    if channel == 'remote':
        status, body, ctype = fetch_remote(path)
        text = body.decode('utf-8', errors='ignore')
        size = len(body)
    else:
        status, body, ctype, size = fetch_local(remote, path)
        text = body.decode('utf-8', errors='ignore')

    problems = []
    if status != want_status:
        problems.append('状态码 %s（期望 %s）' % (status, want_status))
    # 最高优先级断言：任何页面都不允许把 PHP 源码吐出来。
    # 历史上 try_files / location 优先级写错会导致整份源码泄露（含配置阅读途径），
    # 所以这里对所有路径都做硬检查，而不只是 .php 路径。
    if '<?php' in text or '<?=' in text:
        problems.append('⚠️ PHP 源码泄露')
        ok = False
    if want_status == 200:
        if size < min_bytes:
            problems.append('体积仅 %d 字节（期望 ≥ %d）' % (size, min_bytes))
        if pattern and not re.search(pattern, text):
            problems.append('未匹配到关键内容 /%s/' % pattern)
    ok = not problems
    mark = 'PASS' if ok else 'FAIL'
    print('  [%s] %-9s %-28s %6d B  %s' % (mark, channel, path, size, label), flush=True)
    if verbose or not ok:
        snippet = text.strip().replace('\n', ' ')[:200]
        if not ok:
            print('         → ' + '；'.join(problems), flush=True)
        print('         body: ' + snippet, flush=True)
    return ok


def main():
    args = sys.argv[1:]
    local_only = '--local-only' in args
    remote_only = '--remote-only' in args
    verbose = '-v' in args

    channels = []
    if not remote_only:
        channels.append('local')
    if not local_only:
        channels.append('remote')

    remote = Remote()
    results = []
    try:
        log('=' * 62)
        log('wid.chr.cc 网页检查')
        log('=' * 62)

        for channel in channels:
            print('\n--- 通道：%s ---' % ('服务器本机 127.0.0.1' if channel == 'local' else '外网 https://' + DOMAIN))
            for path, want, pattern, label, min_bytes in PAGES:
                results.append(check_page(remote, channel, path, want, pattern, label, min_bytes, verbose))

            print('\n--- 内部目录封禁检查（期望 404）---')
            for path, label in DENIED:
                if channel == 'remote':
                    status, body, _ = fetch_remote(path)
                    size = len(body)
                else:
                    status, body, _, size = fetch_local(remote, path)
                ok = status == 404
                results.append(ok)
                print('  [%s] %-9s %-28s %6d B  %s' % ('PASS' if ok else 'FAIL', channel, path, size,
                                                      label + '（期望 404，实际 %s）' % status), flush=True)

        # 附带打印一次请求头，确认安全头生效
        print('\n--- 响应头抽查（本机通道 / ）---')
        code, out, err = remote.run(
            "curl -sS -o /dev/null -D - -A '%s' -H 'Host: %s' http://127.0.0.1/ | head -14" % (UA, DOMAIN))
        for line in out.splitlines():
            if line.strip():
                print('  ' + line.strip())
    finally:
        remote.close()

    ok_count = sum(1 for r in results if r)
    log('=' * 62)
    log('网页检查：%d / %d 通过' % (ok_count, len(results)))
    if ok_count != len(results):
        sys.exit(1)
    log('全部通过 ✅')
    log('=' * 62)


if __name__ == '__main__':
    main()
