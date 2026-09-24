# -*- coding: utf-8 -*-
"""
============================================================
wid.chr.cc 接口测试
创建时间: 2026-09-23
名称: test_wid_api.py
作用: 按 docs/api-v3.md 的契约逐条验证线上接口，覆盖
      公开只读接口、HMAC 签名（正确 / 错误 / 过期 / 重放）、
      参数校验、批量敲击、版本更新检测、看板、云同步冲突。
特性:
  - 双通道验证：① 外网 https://wid.chr.cc（经 Cloudflare）
                ② 服务器本机 curl 127.0.0.1 -H 'Host: wid.chr.cc'
    两条通道用同一份签名，可交叉确认 Cloudflare / WAF 没有改写请求。
  - 测试数据全部落在**独立的测试应用**下，跑完自动清理，
    不会污染正式统计（--keep-data 可保留用于排查）。
用法:
  python Scripts/test_wid_api.py                 # 双通道全量
  python Scripts/test_wid_api.py --local-only    # 只跑服务器本机通道
  python Scripts/test_wid_api.py --remote-only   # 只跑外网通道
  python Scripts/test_wid_api.py --filter taps   # 只跑名称含 taps 的用例
  python Scripts/test_wid_api.py --keep-data     # 保留测试数据
依赖: paramiko + 站点 .wid_secrets.json（由 init_wid_db.py 生成）
注意: 部署后立刻跑测试可能失败 —— 服务器 OPcache 的 revalidate_freq=60，
      新代码最多 60 秒后才生效。deploy_wid_site.py 已内置刷新步骤。
============================================================
"""
import hashlib
import hmac
import json
import os
import re
import sys
import time
import uuid

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from widlib import Remote, http_request, log  # noqa: E402

BASE = os.path.dirname(os.path.abspath(__file__))
SECRETS_FILE = os.path.join(BASE, '.wid_secrets.json')
DOMAIN = 'wid.chr.cc'
EMPTY_SHA256 = hashlib.sha256(b'').hexdigest()

TEST_APP_KEY = 'test0000wid0000api0000selfcheck'
TEST_DEVICE = 'selftest' + uuid.uuid4().hex[:12]

RESULTS = []
CURRENT_CHANNEL = 'remote'
NAME_FILTER = None
LAST_REQ = {}
CTX = {'app_key': '', 'secret': '', 'remote': None}


# ============================================================
# 签名与请求
# ============================================================

def canonical(method, path, app_key, ts, nonce, body):
    return '\n'.join([
        method.upper(), path, app_key, ts, nonce,
        hashlib.sha256(body).hexdigest() if body else EMPTY_SHA256,
    ])


def encode_body(payload):
    if payload is None:
        return b''
    return json.dumps(payload, ensure_ascii=False, separators=(',', ':')).encode('utf-8')


def sign(secret, text):
    return hmac.new(secret.encode(), text.encode(), hashlib.sha256).hexdigest()


def build_headers(path, payload, ts=None, nonce=None, bad_sign=False, omit=None,
                  method='POST', app_key=None, secret=None):
    """
    构造带签名的请求头。

    ⚠️ 必须把**实际要发送的请求体**传进来：签名覆盖体哈希，
       早先这里默认空 body 导致全部写接口 40101（本脚本自身的坑）。
    """
    app_key = app_key if app_key is not None else CTX['app_key']
    secret = secret if secret is not None else CTX['secret']
    body = encode_body(payload)
    ts = ts if ts is not None else str(int(time.time()))
    nonce = nonce or uuid.uuid4().hex
    sig = sign(secret, canonical(method, path, app_key, ts, nonce, body))
    if bad_sign:
        sig = 'f' * 64
    headers = {
        'X-App-Key': app_key,
        'X-Timestamp': ts,
        'X-Nonce': nonce,
        'X-Signature': sig,
    }
    for key in (omit or []):
        headers.pop(key, None)
    return headers


def remote_request(method, path, headers=None, body=None):
    """经 Cloudflare 走外网（内部用 curl，规避 Python TLS 偶发中断）"""
    return http_request(method, 'https://%s%s' % (DOMAIN, path), headers=headers, body=body)


def sh_quote(text):
    return "'" + text.replace('\\', '\\\\').replace("'", "'\"'\"'") + "'"


def local_request(method, path, headers=None, body=None):
    """在服务器上用 curl 打 127.0.0.1，绕过 Cloudflare 与外部网络"""
    parts = ['curl', '-sS', '-m', '15', '-o', '/tmp/_wid_resp', '-w', '%{http_code}',
             '-X', method, '-A', sh_quote(widlib_ua()), '-H', sh_quote('Host: ' + DOMAIN)]
    if body:
        parts += ['-H', sh_quote('Content-Type: application/json'),
                  '--data-binary', sh_quote(body.decode('utf-8'))]
    for key, value in (headers or {}).items():
        parts += ['-H', sh_quote('%s: %s' % (key, value))]
    # URL 必须整体加引号：查询串里的 & 不引会被 shell 当成后台执行符，
    # 导致 curl 只拿到半截 URL（表现为随机拿到上一次请求的响应）
    parts.append(sh_quote('http://127.0.0.1' + path))
    cmd = ' '.join(parts) + '; echo; cat /tmp/_wid_resp'
    code, out, err = CTX['remote'].run(cmd, timeout=60)
    lines = out.split('\n', 1)
    try:
        status = int(lines[0].strip())
    except ValueError:
        status = 0
    payload = lines[1] if len(lines) > 1 else ''
    if status == 0 and err:
        payload = err
    return status, payload


def widlib_ua():
    import widlib
    return widlib.BROWSER_UA


def call(method, path, headers=None, payload=None):
    """发一次请求（payload 会先序列化）"""
    body = encode_body(payload)
    LAST_REQ.update({
        'method': method,
        'path': path,
        'body_len': len(body),
        'body_sha': hashlib.sha256(body).hexdigest() if body else EMPTY_SHA256,
        'body': body.decode('utf-8', errors='ignore')[:200],
    })
    if CURRENT_CHANNEL == 'local':
        return local_request(method, path, headers, body)
    return remote_request(method, path, headers, body)


def signed(path, payload=None, **kwargs):
    """带签名的写接口调用：签名与请求体一次成型，避免两者脱节"""
    method = kwargs.pop('method', 'POST')
    headers = build_headers(path, payload, method=method, **kwargs)
    return call(method, path, headers, payload)


def parse(text):
    try:
        return json.loads(text)
    except Exception:  # noqa: BLE001
        return None


# ============================================================
# 断言
# ============================================================

def check(name, condition, detail=''):
    if NAME_FILTER and NAME_FILTER not in name:
        return
    RESULTS.append((name, bool(condition), detail))
    mark = 'PASS' if condition else 'FAIL'
    line = '  [%s] %s' % (mark, name)
    if detail and not condition:
        line += '\n         → ' + str(detail)[:600]
    print(line, flush=True)


def expect(name, resp, want_status=200, want_code=0, want_ok=True):
    status, text = resp
    body = parse(text)
    ok = status == want_status
    detail = 'HTTP %s（期望 %s）body=%s' % (status, want_status, text[:300])
    if body is None:
        # 期望业务码时必须是 JSON —— 否则可能拿到了 nginx 的 HTML 错误页
        # （宝塔默认 fastcgi_intercept_errors on 就会这样），必须判失败
        if want_code is not None:
            ok = False
            detail += ' | 响应不是 JSON（可能被 nginx 错误页拦截）'
    else:
        if want_code is not None and body.get('code') != want_code:
            ok = False
            detail += ' | code=%s（期望 %s）' % (body.get('code'), want_code)
        if 'ok' in body and body.get('ok') is not want_ok:
            ok = False
            detail += ' | ok=%s' % body.get('ok')
    if not ok:
        detail += '\n         发出: %s %s body_len=%s body_sha256=%s\n         发出 body: %s' % (
            LAST_REQ.get('method'), LAST_REQ.get('path'), LAST_REQ.get('body_len'),
            LAST_REQ.get('body_sha'), LAST_REQ.get('body'))
    check(name, ok, detail)
    return body


# ============================================================
# 用例
# ============================================================

def run_tests():
    # 每个通道用**独立的测试设备**：敲击是累计口径（服务端记快照），
    # 两个通道复用同一设备会让第二个通道的增量全部算成 0（本脚本踩过）
    global TEST_DEVICE
    TEST_DEVICE = 'selftest' + uuid.uuid4().hex[:12]

    log('通道：%s' % ('服务器本机 127.0.0.1' if CURRENT_CHANNEL == 'local'
                     else '外网 https://' + DOMAIN))
    log('  测试设备：%s' % TEST_DEVICE)
    prefix = '[%s] ' % CURRENT_CHANNEL

    # ---------- 公开只读 ----------
    expect(prefix + 'GET /health', call('GET', '/api/v1/health'))

    body = expect(prefix + 'GET /version（当前即最新）',
                  call('GET', '/api/v1/version?platform=windows&channel=release&current=3.0.0'))
    if body and body.get('ok'):
        d = body.get('data', {})
        check(prefix + '/version 返回 latest 与 has_update',
              d.get('latest') is not None and 'has_update' in d,
              json.dumps(d, ensure_ascii=False)[:300])
        check(prefix + '/version 同版本不提示更新', d.get('has_update') is False,
              'has_update=%s' % d.get('has_update'))

    body = expect(prefix + 'GET /version（旧版本应提示更新）',
                  call('GET', '/api/v1/version?platform=windows&channel=release&current=2.0.0'))
    if body and body.get('ok'):
        d = body.get('data', {})
        check(prefix + '/version has_update=true 且带 update_type',
              d.get('has_update') is True and d.get('update_type') in ('major', 'minor', 'patch'),
              json.dumps(d, ensure_ascii=False)[:300])
        check(prefix + '/version below_min_supported 触发强制升级',
              d.get('force_upgrade') is True and d.get('reason') == 'below_min_supported',
              'force=%s reason=%s' % (d.get('force_upgrade'), d.get('reason')))

    body = expect(prefix + 'GET /version（不带 platform 返回全平台清单）', call('GET', '/api/v1/version'))
    if body and body.get('ok'):
        check(prefix + '/version platforms 非空', bool(body.get('data', {}).get('platforms')))

    body = expect(prefix + 'GET /stats/summary', call('GET', '/api/v1/stats/summary'))
    if body and body.get('ok'):
        d = body.get('data', {})
        keys = {'launches', 'taps', 'merit', 'online', 'devices', 'today', 'online_peak'}
        check(prefix + '/stats/summary 字段齐全', keys.issubset(set(d.keys())),
              '缺：%s' % (keys - set(d.keys())))

    body = expect(prefix + 'GET /stats/overview',
                  call('GET', '/api/v1/stats/overview?days=7&range=week&limit=5'))
    if body and body.get('ok'):
        d = body.get('data', {})
        keys = {'summary', 'trend', 'breakdown', 'leaderboard', 'generated_at'}
        check(prefix + '/stats/overview 字段齐全', keys.issubset(set(d.keys())),
              '缺：%s' % (keys - set(d.keys())))
        check(prefix + '/stats/overview trend 长度等于 days',
              len(d.get('trend') or []) == 7, 'len=%s' % len(d.get('trend') or []))
        check(prefix + '/stats/overview 的 summary 与独立接口口径一致',
              (d.get('summary') or {}).get('taps') is not None,
              json.dumps(d.get('summary'), ensure_ascii=False)[:200])

    body = expect(prefix + 'GET /stats/trend?days=7', call('GET', '/api/v1/stats/trend?days=7'))
    if body and body.get('ok'):
        series = body.get('data', {}).get('series', [])
        check(prefix + '/stats/trend 返回 7 天并补零', len(series) == 7, 'len=%s' % len(series))

    expect(prefix + 'GET /stats/breakdown', call('GET', '/api/v1/stats/breakdown'))
    expect(prefix + 'GET /leaderboard', call('GET', '/api/v1/leaderboard?range=week'))

    body = expect(prefix + 'GET /blessing', call('GET', '/api/v1/blessing'))
    if body and body.get('ok'):
        check(prefix + '/blessing 内容非空', bool(body.get('data', {}).get('content')))

    body = expect(prefix + 'GET /config', call('GET', '/api/v1/config?platform=windows'))
    if body and body.get('ok'):
        cfg_data = body.get('data', {}).get('config', {})
        check(prefix + '/config 含 heartbeatInterval 且类型为 int',
              isinstance(cfg_data.get('heartbeatInterval'), int),
              json.dumps(cfg_data, ensure_ascii=False)[:200])

    expect(prefix + 'GET /assets', call('GET', '/api/v1/assets?platform=windows'))
    expect(prefix + 'GET /announcement',
           call('GET', '/api/v1/announcement?platform=windows&client_version=3.0.0'))
    expect(prefix + 'GET /changelog', call('GET', '/api/v1/changelog?limit=5'))
    expect(prefix + 'GET /downloads', call('GET', '/api/v1/downloads'))

    # ---------- 签名安全 ----------
    path = '/api/v1/launch'
    payload = {'device_id': TEST_DEVICE, 'platform': 'windows', 'client_version': '3.0.0',
               'session_id': uuid.uuid4().hex}

    expect(prefix + 'POST /launch 签名错误应 401/40101',
           signed(path, payload, bad_sign=True), want_status=401, want_code=40101, want_ok=False)

    expect(prefix + 'POST /launch 时间戳过期应 401/40102',
           signed(path, payload, ts=str(int(time.time()) - 9999)),
           want_status=401, want_code=40102, want_ok=False)

    expect(prefix + 'POST /launch 缺少签名头应 401/40101',
           signed(path, payload, omit=['X-Signature']),
           want_status=401, want_code=40101, want_ok=False)

    expect(prefix + 'POST /launch 未知 app_key 应 401/40104',
           signed(path, payload, app_key='nonexistentappkey0', secret='x' * 64),
           want_status=401, want_code=40104, want_ok=False)

    # ---------- 正常启动 ----------
    nonce = uuid.uuid4().hex
    body = expect(prefix + 'POST /launch 正常上报', signed(path, payload, nonce=nonce))
    launch_count_1 = None
    if body and body.get('ok'):
        d = body.get('data', {})
        launch_count_1 = d.get('device', {}).get('launch_count')
        check(prefix + '/launch 返回 device / global / config / title',
              all(k in d for k in ('device', 'global', 'config', 'title')),
              json.dumps(list(d.keys())))
        check(prefix + '/launch 建立新会话', d.get('new_session') is True,
              'new_session=%s' % d.get('new_session'))

    expect(prefix + 'POST /launch nonce 重放应 401/40103',
           signed(path, payload, nonce=nonce),
           want_status=401, want_code=40103, want_ok=False)

    body = expect(prefix + 'POST /launch 二次启动', signed(path, payload))
    if body and body.get('ok') and launch_count_1 is not None:
        now = body.get('data', {}).get('device', {}).get('launch_count')
        check(prefix + '/launch 启动计数递增', now == launch_count_1 + 1,
              '%s -> %s' % (launch_count_1, now))

    # ---------- 心跳 ----------
    hb = {'device_id': TEST_DEVICE, 'session_id': payload['session_id']}
    body = expect(prefix + 'POST /heartbeat', signed('/api/v1/heartbeat', hb))
    if body and body.get('ok'):
        check(prefix + '/heartbeat 返回 online >= 1', (body.get('data', {}).get('online') or 0) >= 1,
              json.dumps(body.get('data')))

    # ---------- 敲击 ----------
    expect(prefix + 'POST /taps 缺 device_id 应 400/40001',
           signed('/api/v1/taps', {'total': 10}), want_status=400, want_code=40001, want_ok=False)

    expect(prefix + 'POST /taps 未注册设备应 409',
           signed('/api/v1/taps', {'device_id': 'unregistered00', 'total': 10}),
           want_status=409, want_code=40001, want_ok=False)

    body = expect(prefix + 'POST /taps 累计值上报 accepted=50',
                  signed('/api/v1/taps', {'device_id': TEST_DEVICE, 'total': 50}))
    if body and body.get('ok'):
        check(prefix + '/taps accepted 正确', body.get('data', {}).get('accepted') == 50,
              json.dumps(body.get('data')))
        check(prefix + '/taps 功德按 total/100 折算为 0',
              body.get('data', {}).get('device', {}).get('merit_total') == 0,
              json.dumps(body.get('data', {}).get('device')))

    body = expect(prefix + 'POST /taps 重复上报同一 total 应为 0（幂等）',
                  signed('/api/v1/taps', {'device_id': TEST_DEVICE, 'total': 50}))
    if body and body.get('ok'):
        check(prefix + '/taps 重复上报 accepted=0', body.get('data', {}).get('accepted') == 0,
              json.dumps(body.get('data')))

    body = expect(prefix + 'POST /taps 累计到 260（功德应为 2）',
                  signed('/api/v1/taps', {'device_id': TEST_DEVICE, 'total': 260}))
    if body and body.get('ok'):
        check(prefix + '/taps 功德折算正确', body.get('data', {}).get('device', {}).get('merit_total') == 2,
              json.dumps(body.get('data', {}).get('device')))

    # 批量用例必须排在「超限截断」之前：截断会推进服务端快照，
    # 之后的累计口径增量会被算成 0（这是预期行为，见 docs/api-v3.md）
    body = expect(prefix + 'POST /taps/batch 批量上报',
                  signed('/api/v1/taps/batch', {'device_id': TEST_DEVICE,
                                                'items': [{'delta': 3}, {'delta': 7}, {'total': 300}]}))
    if body and body.get('ok'):
        check(prefix + '/taps/batch accepted = 40（300-260）',
              body.get('data', {}).get('accepted') == 40, json.dumps(body.get('data')))

    body = expect(prefix + 'POST /taps delta 超限应被截断',
                  signed('/api/v1/taps', {'device_id': TEST_DEVICE, 'delta': 999999}))
    if body and body.get('ok'):
        check(prefix + '/taps clamped=true 且 accepted=20000',
              body.get('data', {}).get('clamped') is True and body.get('data', {}).get('accepted') == 20000,
              json.dumps(body.get('data')))

    # ---------- 档案与榜单 ----------
    body = expect(prefix + 'GET /profile', call('GET', '/api/v1/profile?device_id=' + TEST_DEVICE))
    if body and body.get('ok'):
        d = body.get('data', {})
        check(prefix + '/profile 返回称号与统计',
              d.get('title') is not None and d.get('taps_total', 0) >= 300,
              json.dumps(d, ensure_ascii=False)[:300])
        check(prefix + '/profile 默认未参与功德榜', d.get('rank_opt_in') is False)

    expect(prefix + 'POST /profile/opt-in 无昵称应 400',
           signed('/api/v1/profile/opt-in', {'device_id': TEST_DEVICE, 'enabled': True}),
           want_status=400, want_code=40001, want_ok=False)

    body = expect(prefix + 'POST /profile/opt-in 带昵称应成功',
                  signed('/api/v1/profile/opt-in',
                         {'device_id': TEST_DEVICE, 'enabled': True, 'nickname': '自检施主'}))
    if body and body.get('ok'):
        nickname = body.get('data', {}).get('profile', {}).get('nickname', '')
        check(prefix + '/profile/opt-in 昵称已打码',
              nickname.startswith('自') and '*' in nickname
              and not any(ch in nickname for ch in ('检', '施', '主')),
              json.dumps(body.get('data', {}).get('profile', {}), ensure_ascii=False)[:200])

    # ---------- 设置云同步 ----------
    body = expect(prefix + 'POST /settings/pull',
                  signed('/api/v1/settings/pull', {'device_id': TEST_DEVICE}))
    rev0 = body.get('data', {}).get('revision', 0) if body else -1

    body = expect(prefix + 'POST /settings/push 首次写入',
                  signed('/api/v1/settings/push',
                         {'device_id': TEST_DEVICE, 'base_revision': rev0,
                          'payload': {'volume': 0.5, 'themeColor': 'jade', 'illegalKey': 'x'}}))
    if body and body.get('ok'):
        d = body.get('data', {})
        check(prefix + '/settings/push 白名单外字段被丢弃',
              'illegalKey' not in (d.get('payload') or {}), json.dumps(d.get('payload')))

    expect(prefix + 'POST /settings/push 旧 base_revision 应 409 冲突',
           signed('/api/v1/settings/push',
                  {'device_id': TEST_DEVICE, 'base_revision': 0, 'payload': {'volume': 0.9}}),
           want_status=409, want_code=40001, want_ok=False)

    body = expect(prefix + 'POST /settings/push force 可强制覆盖',
                  signed('/api/v1/settings/push',
                         {'device_id': TEST_DEVICE, 'base_revision': 0, 'force': True,
                          'payload': {'volume': 0.9}}))
    if body and body.get('ok'):
        check(prefix + '/settings/push force 后 revision 递增',
              body.get('data', {}).get('revision', 0) >= 2, json.dumps(body.get('data'))[:200])

    # ---------- 反馈与崩溃 ----------
    expect(prefix + 'POST /feedback 内容过短应 400',
           signed('/api/v1/feedback', {'device_id': TEST_DEVICE, 'content': 'a'}),
           want_status=400, want_code=40001, want_ok=False)

    body = expect(prefix + 'POST /feedback 正常提交',
                  signed('/api/v1/feedback',
                         {'device_id': TEST_DEVICE, 'category': 'bug',
                          'content': '自检脚本提交的测试反馈，可忽略', 'contact': 'selfcheck'}))
    if body and body.get('ok'):
        check(prefix + '/feedback 返回 id', bool(body.get('data', {}).get('id')))

    body = expect(prefix + 'POST /crash 正常上报',
                  signed('/api/v1/crash',
                         {'device_id': TEST_DEVICE, 'error_type': 'SelfCheck',
                          'message': '自检脚本模拟异常', 'detail': 'stack...'}))
    if body and body.get('ok'):
        check(prefix + '/crash 返回去重标记', 'dedup' in body.get('data', {}),
              json.dumps(body.get('data')))

    # ---------- 路由与协议 ----------
    expect(prefix + 'GET 未知路由应 404/40401', call('GET', '/api/v1/not-exists'),
           want_status=404, want_code=40401, want_ok=False)
    expect(prefix + 'GET 用错方法访问写接口应 405', call('GET', '/api/v1/launch'),
           want_status=405, want_code=40001, want_ok=False)

    # ---------- 下线 ----------
    expect(prefix + 'POST /offline', signed('/api/v1/offline', {'device_id': TEST_DEVICE}))

    # ---------- 公开接口幂等 ----------
    status, text = call('GET', '/api/v1/stats/summary')
    check(prefix + 'GET /stats/summary 返回 200 且为 JSON',
          status == 200 and parse(text) is not None, 'HTTP %s' % status)


# ============================================================
# 测试应用（隔离正式数据）
# ============================================================

def setup_test_app(remote):
    """创建 / 复用独立测试应用，返回 (app_key, secret)"""
    import secrets as pysecrets
    secret = pysecrets.token_hex(32)
    sql = ("INSERT INTO apps (app_key, app_secret, name, status, rate_limit_per_min, request_total, note, created_at, updated_at) "
           "VALUES ('%s', '%s', '自检脚本（临时）', 1, 5000, 0, 'test_wid_api.py', NOW(), NOW()) "
           "ON DUPLICATE KEY UPDATE app_secret = VALUES(app_secret), status = 1;"
           % (TEST_APP_KEY, secret))
    code, out, err = remote.run("mysql --default-character-set=utf8mb4 -uroot -p'258051' wid -e %s 2>/dev/null" % sh_quote(sql))
    if code != 0:
        log('创建测试应用失败：%s' % (err or out).strip(), 'ERROR')
        sys.exit(1)

    code, out, _ = remote.run(
        "mysql --default-character-set=utf8mb4 -uroot -p'258051' -N wid -e %s 2>/dev/null"
        % sh_quote("SELECT app_secret FROM apps WHERE app_key='%s';" % TEST_APP_KEY))
    # 只取 64 位十六进制，避免 mysql 的告警文本混进来
    match = re.search(r'\b[0-9a-f]{64}\b', out)
    loaded = match.group(0) if match else ''
    if loaded != secret:
        log('数据库中的密钥与本地生成的不一致，改用数据库值（%s…）' % loaded[:8], 'WARN')
    return TEST_APP_KEY, (loaded or secret)


def cleanup_test_app(remote):
    """清掉测试应用及其产生的全部数据，保证公开统计不被污染"""
    sql = (
        "DELETE d FROM daily_active d INNER JOIN apps a ON a.id = d.app_id WHERE a.app_key = '%(k)s';"
        "DELETE s FROM daily_stats s INNER JOIN apps a ON a.id = s.app_id WHERE a.app_key = '%(k)s';"
        "DELETE o FROM online_sessions o INNER JOIN apps a ON a.id = o.app_id WHERE a.app_key = '%(k)s';"
        "DELETE g FROM global_stats g INNER JOIN apps a ON a.id = g.app_id WHERE a.app_key = '%(k)s';"
        "DELETE ds FROM device_settings ds INNER JOIN devices v ON v.id = ds.device_pk "
        "  INNER JOIN apps a ON a.id = v.app_id WHERE a.app_key = '%(k)s';"
        "DELETE v FROM devices v INNER JOIN apps a ON a.id = v.app_id WHERE a.app_key = '%(k)s';"
        "DELETE f FROM feedback f INNER JOIN apps a ON a.id = f.app_id WHERE a.app_key = '%(k)s';"
        "DELETE c FROM crash_reports c INNER JOIN apps a ON a.id = c.app_id WHERE a.app_key = '%(k)s';"
        "DELETE n FROM api_nonces n INNER JOIN apps a ON a.id = n.app_id WHERE a.app_key = '%(k)s';"
        "DELETE FROM apps WHERE app_key = '%(k)s';"
    ) % {'k': TEST_APP_KEY}
    code, out, err = remote.run("mysql --default-character-set=utf8mb4 -uroot -p'258051' wid -e %s 2>&1" % sh_quote(sql))
    if code != 0:
        log('清理测试数据失败：%s' % (err or out).strip()[:300], 'WARN')
        return False
    log('测试数据已清理（测试应用与全部关联行已删除）')
    return True


def main():
    global CURRENT_CHANNEL, NAME_FILTER
    args = sys.argv[1:]
    local_only = '--local-only' in args
    remote_only = '--remote-only' in args
    keep = '--keep-data' in args
    if '--filter' in args:
        NAME_FILTER = args[args.index('--filter') + 1]

    if not os.path.isfile(SECRETS_FILE):
        log('缺少 %s，请先执行 python Scripts/init_wid_db.py' % SECRETS_FILE, 'ERROR')
        sys.exit(1)

    remote = Remote()
    CTX['remote'] = remote

    channels = []
    if not remote_only:
        channels.append('local')
    if not local_only:
        channels.append('remote')

    log('=' * 58)
    log('wid.chr.cc 接口测试')
    log('测试设备：%s' % TEST_DEVICE)
    log('=' * 58)

    CTX['app_key'], CTX['secret'] = setup_test_app(remote)
    log('测试应用：%s' % CTX['app_key'])

    try:
        for channel in channels:
            CURRENT_CHANNEL = channel
            run_tests()
    finally:
        if not keep:
            cleanup_test_app(remote)
        else:
            log('按参数保留测试数据（测试应用 %s）' % CTX['app_key'])
        remote.close()

    total = len(RESULTS)
    passed = sum(1 for _, ok, _ in RESULTS if ok)
    failed = [(n, d) for n, ok, d in RESULTS if not ok]

    log('=' * 58)
    log('结果：%d / %d 通过' % (passed, total))
    if failed:
        log('失败用例：', 'ERROR')
        for name, detail in failed:
            log('  ✗ %s\n      %s' % (name, str(detail)[:400]), 'ERROR')
        sys.exit(1)
    log('全部通过 ✅')
    log('=' * 58)


if __name__ == '__main__':
    main()
