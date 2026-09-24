<?php
namespace Wid\Model;

use Wid\Core\Db;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 统计聚合。
 *
 * 两层结构：
 * - daily_stats：按 (日期, 应用, 平台) 累加启动数 / 敲击增量 / 功德增量，趋势图直接查它；
 * - daily_active：按 (日期, 应用, 设备) 记录当天是否活跃，用于**去重**统计活跃设备
 *   （直接对 daily_stats 求和会把同一设备在多平台重复计入，故单独一张表）。
 * - global_stats：全量累计值，读接口时一次 SELECT 拿全，避免每次 SUM 大表。
 *
 * 设计取舍：敲击上报是高频写（自动敲击最低 150ms 一次），所以**不写原始明细表**，
 * 只写增量到 daily_stats —— 明细留在客户端，服务端只保留聚合口径。
 * v2 那种"每次敲击一行"的写法在这台 4G 内存的机器上是不可持续的。
 */
final class Stats
{
    /** 确保 global_stats 存在该应用的汇总行 */
    public static function ensureGlobal(int $appId): void
    {
        Db::tryExec(
            'INSERT IGNORE INTO global_stats (app_id, launches, taps, merit, online_now, online_peak, updated_at)
             VALUES (?, 0, 0, 0, 0, 0, NOW())',
            [$appId]
        );
    }

    /** 启动次数 +1 */
    public static function addLaunch(int $appId, string $platform, ?string $date = null): void
    {
        $date = $date ?: date('Y-m-d');
        $platform = platform_norm($platform);
        self::ensureGlobal($appId);
        Db::tryExec('UPDATE global_stats SET launches = launches + 1, updated_at = NOW() WHERE app_id = ?', [$appId]);
        Db::tryExec(
            'INSERT INTO daily_stats (stat_date, app_id, platform, launches, tap_delta, merit_delta, active_devices, heartbeats)
             VALUES (?, ?, ?, 1, 0, 0, 0, 0)
             ON DUPLICATE KEY UPDATE launches = launches + 1',
            [$date, $appId, $platform]
        );
    }

    /** 敲击增量累加 */
    public static function addTaps(int $appId, string $platform, int $delta, int $meritDelta, ?string $date = null): void
    {
        if ($delta <= 0 && $meritDelta <= 0) {
            return;
        }
        $date = $date ?: date('Y-m-d');
        $platform = platform_norm($platform);
        self::ensureGlobal($appId);
        Db::tryExec(
            'UPDATE global_stats SET taps = taps + ?, merit = merit + ?, updated_at = NOW() WHERE app_id = ?',
            [$delta, $meritDelta, $appId]
        );
        Db::tryExec(
            'INSERT INTO daily_stats (stat_date, app_id, platform, launches, tap_delta, merit_delta, active_devices, heartbeats)
             VALUES (?, ?, ?, 0, ?, ?, 0, 0)
             ON DUPLICATE KEY UPDATE tap_delta = tap_delta + VALUES(tap_delta), merit_delta = merit_delta + VALUES(merit_delta)',
            [$date, $appId, $platform, $delta, $meritDelta]
        );
    }

    /** 心跳计数（趋势图上区分"打开了"和"还在用"） */
    public static function addHeartbeat(int $appId, string $platform, ?string $date = null): void
    {
        $date = $date ?: date('Y-m-d');
        Db::tryExec(
            'INSERT INTO daily_stats (stat_date, app_id, platform, launches, tap_delta, merit_delta, active_devices, heartbeats)
             VALUES (?, ?, ?, 0, 0, 0, 0, 1)
             ON DUPLICATE KEY UPDATE heartbeats = heartbeats + 1',
            [$date, $appId, platform_norm($platform)]
        );
    }

    /**
     * 标记设备当天活跃。返回 true 表示是新设备（今天第一次），
     * 此时才去递增 daily_stats.active_devices，保证"活跃设备"是真去重值。
     */
    public static function markActive(int $appId, int $devicePk, string $platform, int $tapDelta = 0): bool
    {
        $date = date('Y-m-d');
        $platform = platform_norm($platform);

        // MySQL 对 INSERT ... ON DUPLICATE KEY UPDATE 的 affected rows 语义：
        //   1 = 新插入，2 = 命中已有行且值有变化，0 = 命中已有行但值没变。
        // 因此 affected === 1 就是「今天第一次见到该设备」，可以据此做去重计数。
        try {
            $affected = Db::exec(
                'INSERT INTO daily_active (stat_date, app_id, device_pk, platform, launches, tap_delta)
                 VALUES (?, ?, ?, ?, 0, ?)
                 ON DUPLICATE KEY UPDATE tap_delta = tap_delta + VALUES(tap_delta)',
                [$date, $appId, $devicePk, $platform, $tapDelta]
            );
        } catch (\Throwable $e) {
            return false;
        }

        if ($affected === 1) {
            Db::tryExec(
                'INSERT INTO daily_stats (stat_date, app_id, platform, launches, tap_delta, merit_delta, active_devices, heartbeats)
                 VALUES (?, ?, ?, 0, 0, 0, 1, 0)
                 ON DUPLICATE KEY UPDATE active_devices = active_devices + 1',
                [$date, $appId, $platform]
            );
            return true;
        }
        return false;
    }

    /** 全站汇总（跨应用口径） */
    public static function summary(?string $platform = null): array
    {
        $platform = $platform ? platform_norm($platform) : null;

        $global = Db::one(
            'SELECT COALESCE(SUM(launches), 0) AS launches,
                    COALESCE(SUM(taps), 0)     AS taps,
                    COALESCE(SUM(merit), 0)    AS merit,
                    COALESCE(MAX(online_peak), 0) AS online_peak,
                    MAX(updated_at)            AS updated_at
             FROM global_stats'
        ) ?: [];

        $today = Db::one(
            'SELECT COALESCE(SUM(launches), 0)  AS launches,
                    COALESCE(SUM(tap_delta), 0) AS taps,
                    COALESCE(SUM(merit_delta), 0) AS merit,
                    COALESCE(SUM(heartbeats), 0) AS heartbeats
             FROM daily_stats WHERE stat_date = CURDATE()'
            . ($platform ? ' AND platform = ?' : ''),
            $platform ? [$platform] : []
        ) ?: [];

        $devices = (int) Db::value(
            'SELECT COUNT(*) FROM devices WHERE status = 1' . ($platform ? ' AND platform = ?' : ''),
            $platform ? [$platform] : [],
            0
        );

        $activeToday = (int) Db::value(
            'SELECT COUNT(*) FROM daily_active WHERE stat_date = CURDATE()'
            . ($platform ? ' AND platform = ?' : ''),
            $platform ? [$platform] : [],
            0
        );

        return [
            'launches'       => (int) ($global['launches'] ?? 0),
            'taps'           => (int) ($global['taps'] ?? 0),
            'merit'          => (int) ($global['merit'] ?? 0),
            'devices'        => $devices,
            'online'         => Online::countNow(),
            'online_peak'    => (int) ($global['online_peak'] ?? 0),
            'today'          => [
                'date'       => date('Y-m-d'),
                'launches'   => (int) ($today['launches'] ?? 0),
                'taps'       => (int) ($today['taps'] ?? 0),
                'merit'      => (int) ($today['merit'] ?? 0),
                'heartbeats' => (int) ($today['heartbeats'] ?? 0),
                'devices'    => $activeToday,
            ],
            'online_window'  => (int) cfg('api.online_window', 120),
            'updated_at'     => $global['updated_at'] ?? null,
        ];
    }

    /** 近 N 日趋势（缺数据的日期补 0，保证前端画图不断线） */
    public static function trend(int $days = 7, ?string $platform = null): array
    {
        $days = max(1, min(180, $days));
        $platform = $platform ? platform_norm($platform) : null;
        $from = date('Y-m-d', strtotime('-' . ($days - 1) . ' day'));

        $launchRows = Db::all(
            'SELECT stat_date, SUM(launches) AS launches, SUM(tap_delta) AS taps
             FROM daily_stats WHERE stat_date >= ?'
            . ($platform ? ' AND platform = ?' : '')
            . ' GROUP BY stat_date',
            $platform ? [$from, $platform] : [$from]
        );
        $deviceRows = Db::all(
            'SELECT stat_date, COUNT(*) AS devices
             FROM daily_active WHERE stat_date >= ?'
            . ($platform ? ' AND platform = ?' : '')
            . ' GROUP BY stat_date',
            $platform ? [$from, $platform] : [$from]
        );

        $byDate = [];
        foreach ($launchRows as $row) {
            $byDate[$row['stat_date']] = [
                'date'     => $row['stat_date'],
                'launches' => (int) $row['launches'],
                'taps'     => (int) $row['taps'],
                'devices'  => 0,
            ];
        }
        foreach ($deviceRows as $row) {
            if (!isset($byDate[$row['stat_date']])) {
                $byDate[$row['stat_date']] = [
                    'date' => $row['stat_date'], 'launches' => 0, 'taps' => 0, 'devices' => 0,
                ];
            }
            $byDate[$row['stat_date']]['devices'] = (int) $row['devices'];
        }

        $series = [];
        for ($i = $days - 1; $i >= 0; $i--) {
            $date = date('Y-m-d', strtotime('-' . $i . ' day'));
            $series[] = $byDate[$date] ?? ['date' => $date, 'launches' => 0, 'taps' => 0, 'devices' => 0];
        }
        return $series;
    }

    /**
     * 今日全网汇总（跨应用、跨平台）。
     *
     * 单独抽出来是因为 `/taps` 与看板都要它 —— 客户端拿到后可以显示
     * 「全网今日 N 次」，与网页看板同一个口径，便于用户确认上报生效。
     */
    public static function todayTotals(?string $platform = null): array
    {
        $platform = $platform ? platform_norm($platform) : null;
        $row = Db::one(
            'SELECT COALESCE(SUM(launches), 0)    AS launches,
                    COALESCE(SUM(tap_delta), 0)   AS taps,
                    COALESCE(SUM(merit_delta), 0) AS merit,
                    COALESCE(SUM(heartbeats), 0)  AS heartbeats
             FROM daily_stats WHERE stat_date = CURDATE()'
            . ($platform ? ' AND platform = ?' : ''),
            $platform ? [$platform] : []
        ) ?: [];
        return [
            'date'       => date('Y-m-d'),
            'launches'   => (int) ($row['launches'] ?? 0),
            'taps'       => (int) ($row['taps'] ?? 0),
            'merit'      => (int) ($row['merit'] ?? 0),
            'heartbeats' => (int) ($row['heartbeats'] ?? 0),
        ];
    }

    /** 累计总量（供接口快速返回，不含日期维度） */
    public static function totals(): array
    {
        $row = Db::one(
            'SELECT COALESCE(SUM(launches), 0) AS launches,
                    COALESCE(SUM(taps), 0) AS taps,
                    COALESCE(SUM(merit), 0) AS merit
             FROM global_stats'
        ) ?: [];
        return [
            'launches' => (int) ($row['launches'] ?? 0),
            'taps'     => (int) ($row['taps'] ?? 0),
            'merit'    => (int) ($row['merit'] ?? 0),
        ];
    }
}
