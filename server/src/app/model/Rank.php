<?php
namespace Wid\Model;

use Wid\Core\Db;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 排行榜与个人档案。
 *
 * 隐私前置：设备默认**不参与**排行榜（rank_opt_in = 0），只有用户在设置里
 * 主动开启后才会出现在榜单上，并且昵称在对外输出时统一打码
 * （「无书」→「无*」）。这比"默认公开再提供关闭"更符合最小化原则。
 */
final class Rank
{
    /** 称号阶梯：累计敲击次数 → 称号 */
    const TITLES = [
        [0, '初入门径'],
        [100, '略有小成'],
        [1000, '心诚则灵'],
        [10000, '木鱼达人'],
        [100000, '敲鱼圣手'],
        [1000000, '功德无量'],
        [10000000, '菩提本无树'],
    ];

    public static function titleFor(int $taps): array
    {
        $name = self::TITLES[0][1];
        $level = 1;
        $next = null;
        foreach (self::TITLES as $i => $item) {
            if ($taps >= $item[0]) {
                $name = $item[1];
                $level = $i + 1;
                $next = self::TITLES[$i + 1] ?? null;
            }
        }
        return [
            'level'      => $level,
            'title'      => $name,
            'next_title' => $next ? $next[1] : null,
            'next_at'    => $next ? $next[0] : null,
            'progress'   => $next ? (int) round(min(1, max(0, ($taps - self::TITLES[$level - 1][0]) / max(1, $next[0] - self::TITLES[$level - 1][0]))) * 100) : 100,
        ];
    }

    /** 昵称打码：保留首字符，其余以 * 替代 */
    public static function maskNickname(string $nickname): string
    {
        $nickname = trim($nickname);
        if ($nickname === '') {
            return '匿名施主';
        }
        $chars = preg_split('//u', $nickname, -1, PREG_SPLIT_NO_EMPTY);
        $len = count($chars);
        if ($len <= 1) {
            return $chars[0];
        }
        return $chars[0] . str_repeat('*', min(3, $len - 1));
    }

    /**
     * 功德榜。
     *
     * @param string $range day|week|month|all
     */
    public static function leaderboard(string $range = 'week', int $limit = 20): array
    {
        $limit = max(1, min(100, $limit));
        $range = in_array($range, ['day', 'week', 'month', 'all'], true) ? $range : 'week';

        if ($range === 'all') {
            $rows = Db::all(
                'SELECT d.id AS device_pk, d.nickname, d.platform, d.tap_total AS taps
                 FROM devices d
                 WHERE d.status = 1 AND d.rank_opt_in = 1 AND d.tap_total > 0
                 ORDER BY d.tap_total DESC LIMIT ' . $limit
            );
        } else {
            $days = ['day' => 1, 'week' => 7, 'month' => 30][$range];
            $from = date('Y-m-d', strtotime('-' . ($days - 1) . ' day'));
            $rows = Db::all(
                'SELECT a.device_pk, d.nickname, d.platform, SUM(a.tap_delta) AS taps
                 FROM daily_active a INNER JOIN devices d ON d.id = a.device_pk
                 WHERE a.stat_date >= ? AND d.status = 1 AND d.rank_opt_in = 1
                 GROUP BY a.device_pk, d.nickname, d.platform
                 HAVING taps > 0
                 ORDER BY taps DESC LIMIT ' . $limit,
                [$from]
            );
        }

        $out = [];
        $position = 0;
        foreach ($rows as $row) {
            $position++;
            $out[] = [
                'rank'     => $position,
                'nickname' => self::maskNickname((string) $row['nickname']),
                'platform' => $row['platform'],
                'taps'     => (int) $row['taps'],
            ];
        }
        return $out;
    }

    /** 参与排行榜的开启 / 关闭 */
    public static function setOptIn(int $devicePk, bool $enabled, string $nickname = ''): bool
    {
        $nickname = mb_substr(trim($nickname), 0, 16, 'UTF-8');
        return Db::exec(
            'UPDATE devices SET rank_opt_in = ?, nickname = IF(? <> \'\', ?, nickname) WHERE id = ?',
            [$enabled ? 1 : 0, $nickname, $nickname, $devicePk]
        ) >= 0;
    }

    /** 设备档案：累计、今日、本周、连续天数、称号、排名 */
    public static function profile(int $devicePk): ?array
    {
        $device = Device::findByPk($devicePk);
        if (!$device) {
            return null;
        }
        $today = (int) Db::value(
            'SELECT COALESCE(tap_delta, 0) FROM daily_active WHERE stat_date = CURDATE() AND device_pk = ?',
            [$devicePk],
            0
        );
        $week = (int) Db::value(
            'SELECT COALESCE(SUM(tap_delta), 0) FROM daily_active WHERE stat_date >= ? AND device_pk = ?',
            [date('Y-m-d', strtotime('-6 day')), $devicePk],
            0
        );
        $total = (int) $device['tap_total'];
        $rank = 0;
        if ($device['rank_opt_in']) {
            $rank = (int) Db::value(
                'SELECT COUNT(*) + 1 FROM devices WHERE status = 1 AND rank_opt_in = 1 AND tap_total > ?',
                [$total],
                0
            );
        }

        return [
            'device_id'      => $device['device_id'],
            'nickname'       => self::maskNickname((string) $device['nickname']),
            'rank_opt_in'    => (bool) $device['rank_opt_in'],
            'rank'           => $rank ?: null,
            'platform'       => $device['platform'],
            'client_version' => $device['client_version'],
            'taps_total'     => $total,
            'merit_total'    => (int) $device['merit_total'],
            'taps_today'     => $today,
            'taps_week'      => $week,
            'launch_count'   => (int) $device['launch_count'],
            'first_seen_at'  => $device['first_seen_at'],
            'last_seen_at'   => $device['last_seen_at'],
            'streak_days'    => self::streak($devicePk),
        ] + self::titleFor($total);
    }

    /** 连续打卡天数（今天或昨天有记录开始往前数） */
    public static function streak(int $devicePk, int $maxLookback = 400): int
    {
        $rows = Db::all(
            'SELECT stat_date FROM daily_active WHERE device_pk = ? AND stat_date >= ? ORDER BY stat_date DESC LIMIT ' . (int) $maxLookback,
            [$devicePk, date('Y-m-d', strtotime('-' . $maxLookback . ' day'))]
        );
        $dates = array_column($rows, 'stat_date');
        if (!$dates) {
            return 0;
        }
        $today = date('Y-m-d');
        $yesterday = date('Y-m-d', strtotime('-1 day'));
        if ($dates[0] !== $today && $dates[0] !== $yesterday) {
            return 0;
        }
        $streak = 1;
        $cursor = strtotime($dates[0]);
        for ($i = 1; $i < count($dates); $i++) {
            $cursor -= 86400;
            if ($dates[$i] === date('Y-m-d', $cursor)) {
                $streak++;
            } else {
                break;
            }
        }
        return $streak;
    }
}
