# -*- coding: utf-8 -*-
"""
============================================================
联调测试设备清理
创建时间: 2026-09-23
名称: cleanup_live_device.py
作用: 把 integration/live_api_check.dart 产生的测试设备及其统计痕迹
      **精确地**从生产库里抹掉，包括：
        1) 从 daily_stats 里扣掉该设备的敲击增量与活跃设备计数
        2) 删除 daily_active / online_sessions / device_settings 行
        3) 删除该设备提交的 feedback 与 crash_reports
        4) 删除设备行本身
        5) 用 daily_stats 重算 global_stats（与后台「重算全量统计」同口径）
      之所以要扣减而不是简单删除设备：global_stats 是累加值，
      只删设备会留下一笔无主的敲击数。
用法:
  python Scripts/cleanup_live_device.py livetestxxxxxxxxxxxxxx
  python Scripts/cleanup_live_device.py --list    # 列出疑似联调设备
依赖: paramiko
============================================================
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from widlib import Remote, log  # noqa: E402

MYSQL_ROOT_PASS = '258051'
DB = 'wid'


def sh_quote(text):
    return "'" + text.replace('\\', '\\\\').replace("'", "'\"'\"'") + "'"


def mysql(remote, sql):
    # -N：不输出列名（列名里可能含 | ，会污染 CONCAT_WS 的解析）
    code, out, err = remote.run(
        "mysql --default-character-set=utf8mb4 -N -uroot -p'%s' %s -e %s 2>/dev/null"
        % (MYSQL_ROOT_PASS, DB, sh_quote(sql)))
    return code == 0, out.strip()


def fetch_device(remote, device_id):
    sql = ("SELECT CONCAT_WS('|', id, app_id, tap_total, merit_total, launch_count, platform, client_version, status) "
           "FROM devices WHERE device_id = '%s' LIMIT 1;" % device_id)
    ok, out = mysql(remote, sql)
    if not ok or not out:
        return None
    parts = out.split('|')
    if len(parts) < 8:
        return None
    return {
        'id': int(parts[0]),
        'app_id': int(parts[1]),
        'tap_total': int(parts[2]),
        'merit_total': int(parts[3]),
        'launch_count': int(parts[4]),
        'platform': parts[5],
        'client_version': parts[6],
        'status': int(parts[7]),
    }


def list_candidates(remote):
    ok, out = mysql(remote, (
        "SELECT device_id, platform, client_version, tap_total, launch_count, last_seen_at "
        "FROM devices WHERE device_id LIKE 'livetest%' OR device_id LIKE 'selftest%' OR device_id LIKE 'dbg%' "
        "ORDER BY last_seen_at DESC LIMIT 50;"))
    log('疑似联调设备：')
    if not out:
        print('  （无）')
        return
    for line in out.splitlines():
        print('  ' + line)


def cleanup(remote, device_id, dry_run=False):
    device = fetch_device(remote, device_id)
    if not device:
        log('设备不存在：%s（可能已清理过）' % device_id, 'WARN')
        return False

    pk = device['id']
    app_id = device['app_id']
    log('找到设备 #%d：平台 %s，版本 %s，累计敲击 %d，启动 %d'
        % (pk, device['platform'], device['client_version'], device['tap_total'], device['launch_count']))

    # 先算清楚这台设备在 daily_active 里贡献了多少，用于扣减 daily_stats
    ok, out = mysql(remote, (
        "SELECT CONCAT_WS('|', stat_date, platform, SUM(tap_delta), COUNT(*)) "
        "FROM daily_active WHERE device_pk = %d GROUP BY stat_date, platform;" % pk))
    deductions = []
    if out:
        for line in out.splitlines():
            parts = line.split('|')
            if len(parts) == 4:
                deductions.append((parts[0], parts[1], int(parts[2]), int(parts[3])))
    log('需要扣减的每日增量：%d 组' % len(deductions))
    for date, platform, taps, rows in deductions:
        print('    %s / %-8s 敲击 -%d，活跃设备 -%d' % (date, platform, taps, rows))

    if dry_run:
        log('DRY-RUN：不执行任何写操作')
        return True

    statements = []
    # 1) 扣减 daily_stats 的增量与活跃设备数
    for date, platform, taps, rows in deductions:
        statements.append(
            "UPDATE daily_stats SET tap_delta = GREATEST(0, tap_delta - %d), "
            "merit_delta = GREATEST(0, merit_delta - %d), "
            "active_devices = GREATEST(0, active_devices - %d) "
            "WHERE stat_date = '%s' AND app_id = %d AND platform = '%s';"
            % (taps, taps // 100, rows, date, app_id, platform))
    # 2) 删除设备的全部关联行
    statements += [
        "DELETE FROM daily_active WHERE device_pk = %d;" % pk,
        "DELETE FROM online_sessions WHERE device_pk = %d;" % pk,
        "DELETE FROM device_settings WHERE device_pk = %d;" % pk,
        "DELETE FROM feedback WHERE device_pk = %d;" % pk,
        "DELETE FROM crash_reports WHERE device_pk = %d;" % pk,
        "DELETE FROM devices WHERE id = %d;" % pk,
        # 3) 用 daily_stats 重算 global_stats（与后台 maintenance recalc_global 同口径）
        "UPDATE global_stats g SET "
        "  launches = (SELECT COALESCE(SUM(launches),0) FROM daily_stats WHERE app_id = g.app_id), "
        "  taps     = (SELECT COALESCE(SUM(tap_delta),0) FROM daily_stats WHERE app_id = g.app_id), "
        "  merit    = (SELECT COALESCE(SUM(merit_delta),0) FROM daily_stats WHERE app_id = g.app_id), "
        "  updated_at = NOW() WHERE g.app_id = %d;" % app_id,
    ]

    ok, out = mysql(remote, ' '.join(statements))
    if not ok:
        log('清理执行失败：%s' % out[:300], 'ERROR')
        return False

    log('清理完成。核对：')
    for label, sql in (
        ('devices', "SELECT COUNT(*) FROM devices WHERE device_id = '%s';" % device_id),
        ('daily_active', "SELECT COUNT(*) FROM daily_active WHERE device_pk = %d;" % pk),
        ('global_stats', "SELECT CONCAT('launches=', launches, ' taps=', taps, ' merit=', merit) "
                         "FROM global_stats WHERE app_id = %d;" % app_id),
    ):
        ok, out = mysql(remote, sql)
        print('    %-14s %s' % (label, out.replace('\n', ' ')))
    return True


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(2)

    remote = Remote()
    try:
        if args[0] == '--list':
            list_candidates(remote)
            return
        dry_run = '--dry-run' in args
        targets = [a for a in args if not a.startswith('-')]
        for device_id in targets:
            cleanup(remote, device_id, dry_run=dry_run)
    finally:
        remote.close()


if __name__ == '__main__':
    main()
