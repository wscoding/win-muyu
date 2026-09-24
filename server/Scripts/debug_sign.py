# -*- coding: utf-8 -*-
"""
签名链路排查（临时脚本，定位「外网 40101 签名不匹配」的根因）。

思路：同一份 body + 同一份签名，分三条路径发出，比对结果：
  A. Windows 本机 curl（widlib.http_request）
  B. 服务器 curl 打 127.0.0.1（走 Host 头，绕过 Cloudflare）
  C. 服务器 curl 打公网 https://wid.chr.cc（经 Cloudflare）
如果 B 通过、C 失败 → 中间链路（Cloudflare / WAF）改动了请求体；
如果 A 失败、B 成功 → Windows 侧 curl 传参有问题。
"""
import hashlib
import hmac
import json
import os
import sys
import time
import uuid

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from widlib import Remote, http_request  # noqa: E402

BASE = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(BASE, '.wid_secrets.json'), 'r', encoding='utf-8') as fh:
    SECRETS = json.load(fh)

APP_KEY = SECRETS['app_key']
SECRET = SECRETS['app_secret']
EMPTY = hashlib.sha256(b'').hexdigest()

PATH = '/api/v1/launch'
DEVICE = 'dbg' + uuid.uuid4().hex[:13]
BODY = json.dumps({
    'device_id': DEVICE,
    'platform': 'windows',
    'client_version': '3.0.0',
    'session_id': uuid.uuid4().hex,
}, ensure_ascii=False, separators=(',', ':')).encode('utf-8')

TS = str(int(time.time()))
NONCE = uuid.uuid4().hex
CANONICAL = '\n'.join(['POST', PATH, APP_KEY, TS, NONCE, hashlib.sha256(BODY).hexdigest()])
SIGN = hmac.new(SECRET.encode(), CANONICAL.encode(), hashlib.sha256).hexdigest()

print('body      :', BODY.decode())
print('body sha  :', hashlib.sha256(BODY).hexdigest())
print('canonical :')
for line in CANONICAL.split('\n'):
    print('    |' + line + '|')
print('sign      :', SIGN)
print()

print('--- A. Windows curl -> https://wid.chr.cc ---')
st, text = http_request('POST', 'https://wid.chr.cc' + PATH, headers={
    'X-App-Key': APP_KEY, 'X-Timestamp': TS, 'X-Nonce': NONCE, 'X-Signature': SIGN,
}, body=BODY)
print(st, text[:300])
print()

remote = Remote()
try:
    print('--- B. 服务器 curl -> 127.0.0.1 (Host: wid.chr.cc) ---')
    code, out, err = remote.run(
        "curl -sS -m 15 -X POST -H 'Host: wid.chr.cc' -H 'Content-Type: application/json' "
        "-H 'X-App-Key: %s' -H 'X-Timestamp: %s' -H 'X-Nonce: %s' -H 'X-Signature: %s' "
        "--data-binary '%s' http://127.0.0.1%s"
        % (APP_KEY, TS, NONCE, SIGN, BODY.decode(), PATH))
    print(out.strip()[:300])

    print()
    print('--- C. 服务器 curl -> https://wid.chr.cc (经 Cloudflare) ---')
    code, out, err = remote.run(
        "curl -sS -m 20 -X POST -A 'Mozilla/5.0' -H 'Content-Type: application/json' "
        "-H 'X-App-Key: %s' -H 'X-Timestamp: %s' -H 'X-Nonce: %s' -H 'X-Signature: %s' "
        "--data-binary '%s' https://wid.chr.cc%s"
        % (APP_KEY, TS, NONCE, SIGN, BODY.decode(), PATH))
    print(out.strip()[:300])

    print()
    print('--- D. 服务器上看本次请求实际收到的 body 长度与哈希 ---')
    code, out, err = remote.run(
        "tail -5 /www/wwwlogs/wid.chr.cc.log 2>/dev/null; "
        "grep -c 'sign_failed' /www/wwwroot/wid.chr.cc/app/log/php-error.log 2>/dev/null || true")
    print(out.strip()[:600])
finally:
    remote.close()
