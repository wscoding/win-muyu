# -*- coding: utf-8 -*-
"""
============================================================
看板闭环测试（敲击 -> 看板数字真的变了）
创建时间: 2026-09-24
名称: test_dashboard_live.py
作用: 端到端验证「客户端敲击上报 → 网页看板数据更新」这条链路。
      test_wid_api.py 只验证单个接口的契约，这里验证的是**闭环** ——
      正是用户反馈「敲了木鱼但看板不动」时该跑的那个脚本。

覆盖:
  1. 用客户端同款 app_key/app_secret 走一遍 launch -> heartbeat -> taps；
  2. 断言 /stats/overview 与 /stats/summary 的累计敲击**确实增加了**；
  3. 断言今日维度、趋势图、平台分布、设备数同步变化；
  4. 断言 409 自愈：直接打 /taps（不先 launch）会被拒，补 launch 后成功；
  5. 断言看板 HTML 里带 data-live / data-live-block 标记（整页刷新的前提）；
  6. 断言 /taps 响应带 global.taps_today（客户端回显用）。

用法:
  python Scripts/test_dashboard_live.py                # 全量
  python Scripts/test_dashboard_live.py --filter taps  # 只跑名称含 taps 的
  python Scripts/test_dashboard_live.py --keep-data    # 保留测试设备（排查用）

注意: 会用**正式应用**的密钥写入一台测试设备（前缀 dashboardcheck）。
      跑完默认自动清理（扣减增量并重算全量），不会污染正式统计。
依赖: paramiko（venv: C:/Users/无书/.workbuddy/binaries/python/envs/default）
============================================================
"""
import hashlib
import hmac
import json
import os
import random
import re
import string
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from widlib import Remote, http_request, log  # noqa: E402

# 与 Flutter 端 lib/constants/app_config.dart 保持一致
APP_KEY = '8f23f05b4a50b6481ff020320692f9e9'
APP_SECRET = '9ad6de90df1e5f8ee8aaed3653569c97cb66b5aec99b5c2b878263112a57d278'
DOMAIN = 'wid.chr.cc'
BASE = 'https://' + DOMAIN
EMPTY_SHA256 = hashlib.sha256(b'').hexdigest()

RESULTS = []
NAME_FILTER = None
KEEP_DATA = False
REMOTE = None


# ============================================================
# 请求封装
# ============================================================

def _body(payload):
    if payload is None:
        return b''
    return json.dumps(payload, ensure_ascii=False, separators=(',', ':')).encode('utf-8')


def signed_post(path, payload=None, app_key=APP_KEY, secret=APP_SECRET):
    """带 HMAC 签名的 POST，与客户端 TelemetryService 的算法一一对应"""
    body = _body(payload)
    ts = str(int(time.time()))
    nonce = ''.join(random.choice('0123456789abcdef') for _ in range(32))
    canonical = '\n'.join([
        'POST', path, app_key, ts, nonce,
        hashlib.sha256(body).hexdigest() if body else EMPTY_SHA256,
    ])
    sig = hmac.new(secret.encode(), canonical.encode(), hashlib.sha256).hexdigest()
    headers = {
        'X-App-Key': app_key,
        'X-Timestamp': ts,
        'X-Nonce': nonce,
        'X-Signature': sig,
    }
    return http_request('POST', BASE + path, headers=headers, body=body)


def get(path):
    return http_request('GET', BASE + path)


def data_of(resp):
    status, text = resp
    try:
        parsed = json.loads(text)
    except Exception:  # noqa: BLE001
        return status, None
    if not isinstance(parsed, dict) or parsed.get('ok') is not True:
        return status, None
    value = parsed.get('data')
    return status, value if isinstance(value, dict) else None


def check(name, condition, detail=''):
    if NAME_FILTER and NAME_FILTER not in name:
        return
    RESULTS.append((name, bool(condition)))
    mark = 'PASS' if condition else 'FAIL'
    line = '  [%s] %s' % (mark, name)
    if detail and not condition:
        line += '\n         → ' + str(detail)[:500]
    print(line, flush=True)


def new_device():
    suffix = ''.join(random.choice(string.ascii_lowercase + string.digits) for _ in range(10))
    return 'dashboardcheck' + suffix


# ============================================================
# 用例
# ============================================================

def run(remote):
    device = new_device()
    session = ''.join(random.choice('0123456789abcdef') for _ in range(32))
    log('测试设备：%s' % device)

    # ---------- 0. 记录基线 ----------
    status, base = data_of(get('/api/v1/stats/overview?days=30&range=week&limit=10'))
    check('基线 GET /stats/overview 可用', base is not None, 'HTTP %s' % status)
    if base is None:
        log('拿不到基线数据，后续断言无意义，提前结束', 'ERROR')
        return
    base_taps = (base.get('summary') or {}).get('taps', 0)
    base_devices = (base.get('summary') or {}).get('devices', 0)
    today0 = ((base.get('summary') or {}).get('today') or {}).get('taps', 0)
    log('基线：累计敲击 %s，设备 %s，今日 %s' % (base_taps, base_devices, today0))

    # ---------- 1. 未注册设备直接敲击应被拒（409） ----------
    status, _ = signed_post('/api/v1/taps', {'device_id': device, 'total': 10})
    check('未注册设备 POST /taps 应返回 409', status == 409, 'HTTP %s（期望 409）' % status)

    # ---------- 2. 启动上报 ----------
    status, launch = data_of(signed_post('/api/v1/launch', {
        'device_id': device,
        'platform': 'windows',
        'os_version': '10.0.26200',
        'client_version': '3.0.0',
        'channel': 'release',
        'color': 'black',
        'session_id': session,
    }))
    check('POST /launch 注册成功', launch is not None, 'HTTP %s' % status)
    if launch is not None:
        check('/launch 返回 device / global / config / title',
              all(k in launch for k in ('device', 'global', 'config', 'title')),
              json.dumps(list(launch.keys())))

    # ---------- 3. 敲击上报（模拟客户端首敲即报） ----------
    status, tap1 = data_of(signed_post('/api/v1/taps', {
        'device_id': device, 'total': 10, 'merit': 0,
        'client_version': '3.0.0', 'color': 'black',
    }))
    check('POST /taps 首敲上报成功', tap1 is not None, 'HTTP %s' % status)
    if tap1 is not None:
        check('/taps accepted = 10', tap1.get('accepted') == 10, json.dumps(tap1))
        check('/taps 返回 global.taps_today（客户端回显用）',
              'taps_today' in (tap1.get('global') or {}),
              json.dumps(tap1.get('global')))

    # 再敲一批，验证增量口径
    status, tap2 = data_of(signed_post('/api/v1/taps', {
        'device_id': device, 'total': 260, 'merit': 2,
        'client_version': '3.0.0', 'color': 'black',
    }))
    if tap2 is not None:
        check('/taps 增量口径正确（260-10=250）', tap2.get('accepted') == 250, json.dumps(tap2))
        check('/taps 功德折算为 2',
              (tap2.get('device') or {}).get('merit_total') == 2, json.dumps(tap2.get('device')))
    else:
        check('/taps 增量口径正确（260-10=250）', False, 'HTTP %s' % status)

    signed_post('/api/v1/heartbeat', {'device_id': device, 'session_id': session})

    # ---------- 4. 闭环核心：看板数字变了 ----------
    _, after = data_of(get('/api/v1/stats/overview?days=30&range=week&limit=10'))
    check('刷新后 GET /stats/overview 仍可用', after is not None)
    if after is None:
        return

    summary = after.get('summary') or {}
    after_taps = summary.get('taps', 0)
    after_today = (summary.get('today') or {}).get('taps', 0)
    after_devices = summary.get('devices', 0)

    check('★ 看板累计敲击增加（260）', after_taps >= base_taps + 260,
          '%s -> %s（基线 %s）' % (base_taps, after_taps, base_taps))
    check('★ 看板今日敲击增加（260）', after_today >= today0 + 260,
          '%s -> %s' % (today0, after_today))
    check('★ 看板设备数 +1', after_devices >= base_devices + 1,
          '%s -> %s' % (base_devices, after_devices))

    # 趋势图最后一天必须是今天，且 taps 已包含本次敲击
    trend = after.get('trend') or []
    today_row = trend[-1] if trend else {}
    check('★ 趋势图最后一天是今天',
          today_row.get('date') == time.strftime('%Y-%m-%d'), json.dumps(today_row))
    check('★ 趋势图今日 taps 已含本次敲击', (today_row.get('taps') or 0) >= 260,
          json.dumps(today_row))

    # 平台分布里应出现 windows
    platforms = (after.get('breakdown') or {}).get('platforms') or []
    windows = [p for p in platforms if p.get('platform') == 'windows']
    check('★ 平台分布出现 windows 且设备数 >= 1',
          bool(windows) and windows[0].get('devices', 0) >= 1, json.dumps(platforms))

    # ---------- 5. overview 与独立接口口径一致 ----------
    _, summary2 = data_of(get('/api/v1/stats/summary'))
    if summary2:
        check('overview.summary 与 /stats/summary 口径一致',
              abs(summary2.get('taps', -1) - after_taps) <= 260,
              'overview=%s summary=%s' % (after_taps, summary2.get('taps')))
    check('overview 带 generated_at', bool(after.get('generated_at')))
    check('overview.leaderboard 结构完整',
          isinstance(after.get('leaderboard'), dict)
          and 'items' in (after.get('leaderboard') or {}),
          json.dumps(after.get('leaderboard'))[:200])

    # ---------- 6. 看板页面带整页刷新的标记 ----------
    code, out, _ = remote.run(
        "curl -sS -m 15 -o /tmp/_dash -w '%%{http_code}' -H 'Host: %s' "
        "-A 'Mozilla/5.0' http://127.0.0.1/dashboard; echo; cat /tmp/_dash" % DOMAIN,
        timeout=60)
    html = out.split('\n', 1)[1] if '\n' in out else ''
    check('看板页面可访问', code == 0 and '<html' in html.lower(), 'code=%s' % code)
    check('看板带 data-live（数字卡刷新）', 'data-live=' in html)
    check('看板带 data-live-block（图表与表格刷新）', 'data-live-block=' in html)
    check('看板带 data-live-updated（最后更新时间）', 'data-live-updated' in html)
    check('看板带暂停/刷新按钮', 'dash-toggle' in html and 'dash-refresh' in html)
    check('看板未泄露 PHP 源码', '<?php' not in html)

    # ---------- 7. 清理 ----------
    if not KEEP_DATA:
        cleanup(remote, device)
    else:
        log('按要求保留测试设备 %s' % device)


def cleanup(remote, device_id):
    """删除测试设备，并扣减它对全局统计的贡献（与 cleanup_live_device.py 同口径）"""
    # SQL 里一律用双引号包字符串：整条语句外面是单引号，
    # 再嵌套单引号会把 shell 的引号提前闭合（表现为"找不到设备"）
    sql = 'SELECT id, tap_total, merit_total FROM devices WHERE device_id = "%s";' % device_id
    _, out, _ = remote.run(
        "mysql --default-character-set=utf8mb4 -uroot -p'258051' -N wid -e '%s' 2>/dev/null"
        % sql)
    m = re.search(r'(\d+)\s+(\d+)\s+(\d+)', out or '')
    if not m:
        log('未找到测试设备，跳过清理', 'WARN')
        return
    pk, taps, merit = int(m.group(1)), int(m.group(2)), int(m.group(3))
    dml = (
        "DELETE FROM daily_active WHERE device_pk = %d;"
        "UPDATE daily_stats SET active_devices = GREATEST(active_devices - 1, 0), "
        "  tap_delta = GREATEST(tap_delta - %d, 0), merit_delta = GREATEST(merit_delta - %d, 0) "
        "  WHERE stat_date = CURDATE();"
        "UPDATE global_stats SET taps = GREATEST(taps - %d, 0), merit = GREATEST(merit - %d, 0), "
        "  launches = GREATEST(launches - 1, 0) WHERE app_id = 1;"
        "DELETE FROM online_sessions WHERE device_pk = %d;"
        "DELETE FROM devices WHERE id = %d;"
    ) % (pk, taps, merit, taps, merit, pk, pk)
    code, out, err = remote.run(
        "mysql --default-character-set=utf8mb4 -uroot -p'258051' wid -e \"%s\" 2>&1" % dml)
    if code != 0:
        log('清理失败：%s' % (err or out).strip()[:200], 'WARN')
    else:
        log('已清理测试设备 %s（扣减敲击 %d / 功德 %d）' % (device_id, taps, merit))


def main():
    global NAME_FILTER, KEEP_DATA
    args = sys.argv[1:]
    KEEP_DATA = '--keep-data' in args
    if '--filter' in args:
        NAME_FILTER = args[args.index('--filter') + 1]

    log('=' * 58)
    log('看板闭环测试（敲击 → 看板数字真的变了）')
    log('=' * 58)

    with Remote() as remote:
        run(remote)

    total = len(RESULTS)
    passed = sum(1 for _, ok in RESULTS if ok)
    log('=' * 58)
    log('结果：%d / %d 通过' % (passed, total))
    failed = [name for name, ok in RESULTS if not ok]
    if failed:
        log('失败用例：', 'ERROR')
        for name in failed:
            log('  ✗ %s' % name, 'ERROR')
        sys.exit(1)
    log('全部通过 ✅')
    log('=' * 58)


if __name__ == '__main__':
    main()
