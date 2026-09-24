# -*- coding: utf-8 -*-
"""
============================================================
wid.chr.cc 管理后台接口测试
创建时间: 2026-09-23
名称: test_admin_api.py
作用: 验证 /admin/api.php 的鉴权（口令登录、Cookie 会话、CSRF、令牌）
      与全部只读动作，并跑一次「写 → 读回来 → 删除」的完整链路。
      写用例只操作自己创建的临时日志，跑完即删，不留数据。
用法:
  python Scripts/test_admin_api.py
  python Scripts/test_admin_api.py --local-only
依赖: paramiko + .wid_secrets.json（含 admin_password / session_secret）
============================================================
"""
import hashlib
import hmac
import json
import os
import sys
import time
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import widlib  # noqa: E402
from widlib import Remote, http_request, log  # noqa: E402

BASE = os.path.dirname(os.path.abspath(__file__))
SECRETS_FILE = os.path.join(BASE, '.wid_secrets.json')
DOMAIN = widlib.SITE_DOMAIN
API = '/admin/api.php'

RESULTS = []
CURRENT_CHANNEL = 'remote'
COOKIE = ''
CSRF = ''


def check(name, condition, detail=''):
    RESULTS.append((name, bool(condition), detail))
    print('  [%s] %s' % ('PASS' if condition else 'FAIL', name), flush=True)
    if detail and not condition:
        print('         → ' + str(detail)[:400], flush=True)


def sh_quote(text):
    return "'" + text.replace('\\', '\\\\').replace("'", "'\"'\"'") + "'"


def request(action, data=None, cookie=None, csrf=None, method='POST', extra_headers=None):
    payload = {'action': action}
    payload.update(data or {})
    body = json.dumps(payload, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    headers = {}
    # cookie=None 表示"用默认会话"；cookie='' 表示"不带 Cookie"（测未登录）
    cookie_value = COOKIE if cookie is None else cookie
    if cookie_value:
        headers['Cookie'] = '%s=%s' % (COOKIE_NAME, cookie_value)
    csrf_value = CSRF if csrf is None else csrf
    if csrf_value:
        headers['X-CSRF'] = csrf_value
    headers.update(extra_headers or {})

    if CURRENT_CHANNEL == 'local':
        # 本机通道：在服务器上用 curl 打 127.0.0.1
        parts = ['curl', '-sS', '-m', '20', '-o', '/tmp/_wid_admin', '-w', '%{http_code}',
                 '-X', method, '-A', sh_quote(widlib.BROWSER_UA),
                 '-H', sh_quote('Host: ' + DOMAIN),
                 '-H', sh_quote('Content-Type: application/json'),
                 '--data-binary', sh_quote(body.decode('utf-8'))]
        for key, value in headers.items():
            parts += ['-H', sh_quote('%s: %s' % (key, value))]
        parts.append(sh_quote('http://127.0.0.1' + API))
        code, out, err = REMOTE.run(' '.join(parts) + '; echo; cat /tmp/_wid_admin', timeout=60)
        lines = out.split('\n', 1)
        try:
            status = int(lines[0].strip())
        except ValueError:
            status = 0
        text = lines[1] if len(lines) > 1 else ''
        if status == 0 and err:
            text = err
    else:
        status, text = http_request(method, 'https://%s%s' % (DOMAIN, API),
                                    headers=headers, body=body)
    try:
        parsed = json.loads(text)
    except Exception:  # noqa: BLE001
        parsed = None
    return status, parsed, text


def expect(name, resp, want_status=200, want_code=0, want_ok=True):
    status, body, text = resp
    ok = status == want_status
    detail = 'HTTP %s（期望 %s）%s' % (status, want_status, text[:240])
    if body is None:
        ok = False
        detail += ' | 响应不是 JSON'
    else:
        if want_code is not None and body.get('code') != want_code:
            ok = False
        if 'ok' in body and body.get('ok') is not want_ok:
            ok = False
    check(name, ok, detail)
    return body


def sign_cookie(secret, ttl=3600):
    """按 AdminAuth 的格式自造会话 Cookie：exp|HMAC('wid-admin|exp', secret)"""
    exp = str(int(time.time()) + ttl)
    sig = hmac.new(secret.encode(), ('wid-admin|' + exp).encode(), hashlib.sha256).hexdigest()
    return exp + '|' + sig


def compute_csrf(secret):
    """与 AdminAuth::csrfToken 一致：HMAC('csrf', secret) 前 32 位"""
    return hmac.new(secret.encode(), b'csrf', hashlib.sha256).hexdigest()[:32]


def main():
    global CURRENT_CHANNEL, COOKIE, CSRF, COOKIE_NAME, REMOTE
    args = sys.argv[1:]
    if '--local-only' in args:
        CURRENT_CHANNEL = 'local'

    if not os.path.isfile(SECRETS_FILE):
        log('缺少 %s' % SECRETS_FILE, 'ERROR')
        sys.exit(1)
    with open(SECRETS_FILE, 'r', encoding='utf-8') as fh:
        secrets = json.load(fh)

    secret = secrets.get('session_secret', '')
    password = secrets.get('admin_password', '')
    COOKIE_NAME = 'wid_admin'

    REMOTE = Remote()
    log('=' * 58)
    log('wid.chr.cc 管理后台测试 @ %s' % ('服务器本机' if CURRENT_CHANNEL == 'local' else '外网'))
    log('=' * 58)

    try:
        # ---------- 未鉴权 ----------
        expect('未登录访问 overview 应 401', request('overview'),
               want_status=401, want_code=40302, want_ok=False)
        expect('未登录写操作应 401', request('config.save', {'config_key': 'x'}),
               want_status=401, want_code=40302, want_ok=False)
        expect('错误口令登录应 401', request('login', {'password': 'definitely-wrong-pw'}),
               want_status=401, want_code=40302, want_ok=False)

        # ---------- 登录 ----------
        if password:
            body = expect('正确口令登录', request('login', {'password': password}, cookie=''))
            if body and body.get('ok'):
                csrf = body.get('data', {}).get('csrf', '')
                check('登录返回 csrf 且与本地推导一致', csrf == compute_csrf(secret),
                      '收到 %s / 期望 %s' % (csrf[:16], compute_csrf(secret)[:16]))
            COOKIE = sign_cookie(secret)
            CSRF = compute_csrf(secret)
        else:
            log('本地无 admin_password，跳过登录用例（仅用自造 Cookie 测其余接口）', 'WARN')
            COOKIE = sign_cookie(secret)
            CSRF = compute_csrf(secret)

        # ---------- 会话校验 ----------
        expect('伪造/过期 Cookie 应 401',
               request('session', cookie='9999999999|' + 'a' * 64),
               want_status=401, want_code=40302, want_ok=False)
        body = expect('自造合法 Cookie 可访问 session', request('session'))
        if body and body.get('ok'):
            check('session 返回 app 且不含密钥',
                  body.get('data', {}).get('app') is not None
                  and 'app_secret' not in (body.get('data', {}).get('app') or {}),
                  json.dumps(body.get('data', {}), ensure_ascii=False)[:200])

        # ---------- CSRF ----------
        expect('写操作缺少 CSRF 应 403',
               request('config.save', {'config_key': 'test_tmp', 'config_value': '1'}, csrf=''),
               want_status=403, want_code=40302, want_ok=False)
        expect('写操作 CSRF 错误应 403',
               request('config.save', {'config_key': 'test_tmp', 'config_value': '1'}, csrf='0' * 32),
               want_status=403, want_code=40302, want_ok=False)

        # ---------- 只读动作 ----------
        body = expect('overview', request('overview'))
        if body and body.get('ok'):
            d = body.get('data', {})
            check('overview 含 summary/trend/releases/latest_events',
                  all(k in d for k in ('summary', 'trend', 'releases', 'latest_events')),
                  json.dumps(list(d.keys())))

        body = expect('options', request('options'))
        if body and body.get('ok'):
            d = body.get('data', {})
            check('options 返回 platform/channel/kind 枚举',
                  bool(d.get('platforms')) and bool(d.get('channels')) and bool(d.get('kinds')),
                  json.dumps(d, ensure_ascii=False)[:200])

        body = expect('devices.list', request('devices.list', {'page': 1, 'size': 5}))
        if body and body.get('ok'):
            d = body.get('data', {})
            check('devices.list 返回分页结构',
                  isinstance(d.get('items'), list) and 'total' in d,
                  json.dumps({k: type(v).__name__ for k, v in d.items()}))
            check('devices.list 不泄漏 IP 二进制', all(
                'last_ip' not in item for item in d.get('items', [])), '仍含 last_ip 字段')

        self_check_device = None
        for item in (body or {}).get('data', {}).get('items', []) or []:
            self_check_device = item.get('id')
        if self_check_device:
            expect('devices.detail', request('devices.detail', {'id': self_check_device}))

        expect('releases.list', request('releases.list'))
        expect('changelog.list', request('changelog.list'))
        expect('config.list', request('config.list'))
        expect('announcements.list', request('announcements.list'))
        expect('blessings.list', request('blessings.list'))
        expect('assets.list', request('assets.list'))
        expect('feedback.list', request('feedback.list'))
        expect('crashes.list', request('crashes.list'))
        expect('events.list', request('events.list'))
        expect('tokens.list', request('tokens.list'))
        expect('logins.list', request('logins.list'))
        expect('未知 action 应 400/40001', request('not-an-action'),
               want_status=400, want_code=40001, want_ok=False)

        # ---------- 写链路：创建临时日志 -> 读回 -> 删除 ----------
        title = '自检临时日志 ' + str(int(time.time()))
        body = expect('changelog.save 新建', request('changelog.save', {
            'version': '0.0.0-selftest', 'platform': 'all', 'channel': 'release',
            'kind': 'notice', 'title': title, 'body': '由 test_admin_api.py 创建，稍后自动删除',
            'released_at': time.strftime('%Y-%m-%d'), 'published': False,
        }))
        created_id = (body or {}).get('data', {}).get('id')
        check('changelog.save 返回新 id', bool(created_id), str(body)[:200])

        body = expect('changelog.list 能读到刚创建的日志', request('changelog.list'))
        found = False
        if body and body.get('ok'):
            found = any(item.get('id') == created_id for item in body.get('data', {}).get('items', []))
        check('新日志出现在列表中', found, 'id=%s' % created_id)

        if created_id:
            expect('changelog.remove 清理', request('changelog.remove', {'id': created_id}))
            body = expect('changelog.list 确认已删除', request('changelog.list'))
            still = False
            if body and body.get('ok'):
                still = any(item.get('id') == created_id for item in body.get('data', {}).get('items', []))
            check('临时日志已删除', not still)

        # ---------- 维护（只跑安全任务）----------
        expect('maintenance vacuum_nonces', request('maintenance', {'task': 'vacuum_nonces'}))
        expect('maintenance 未知任务应 400',
               request('maintenance', {'task': 'nope'}), want_status=400, want_code=40001, want_ok=False)

        # ---------- 令牌 ----------
        body = expect('tokens.create', request('tokens.create', {
            'label': 'selftest', 'scope': 'read', 'ttl_days': 1}))
        token = (body or {}).get('data', {}).get('token')
        token_id = (body or {}).get('data', {}).get('id')
        check('tokens.create 返回明文令牌', bool(token) and len(token or '') == 48, str(token)[:20])

        if token:
            status, text = http_request('POST', 'https://%s%s' % (DOMAIN, API),
                                        headers={'Authorization': 'Bearer ' + token,
                                                 'Content-Type': 'application/json'},
                                        body=json.dumps({'action': 'session'}).encode())
            parsed = json.loads(text) if text.strip().startswith('{') else None
            check('Bearer 令牌可用于只读接口',
                  status == 200 and parsed is not None and parsed.get('ok') is True,
                  'HTTP %s %s' % (status, text[:160]))

        if token_id:
            expect('tokens.remove 清理', request('tokens.remove', {'id': token_id}))
    finally:
        REMOTE.close()

    total = len(RESULTS)
    passed = sum(1 for _, ok, _ in RESULTS if ok)
    failed = [(n, d) for n, ok, d in RESULTS if not ok]
    log('=' * 58)
    log('结果：%d / %d 通过' % (passed, total))
    if failed:
        for name, detail in failed:
            log('  ✗ %s\n      %s' % (name, str(detail)[:300]), 'ERROR')
        sys.exit(1)
    log('全部通过 ✅')
    log('=' * 58)


REMOTE = None
COOKIE_NAME = 'wid_admin'

if __name__ == '__main__':
    main()
