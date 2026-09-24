<?php
namespace Wid\Api;

use Wid\Core\Http;
use Wid\Core\Respond;
use Wid\Model\Device;
use Wid\Model\Online;
use Wid\Model\Rank;
use Wid\Model\Stats;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 统计与榜单（看板数据源，全部公开只读）。
 *
 * 公开接口只输出聚合数字，不暴露任何单台设备的可识别信息 ——
 * 排行榜是个例外，但那边有显式的 opt-in 与昵称打码。
 */
final class StatsApi
{
    /** GET /v1/stats/summary */
    public static function summary(array $ctx, int $cacheSeconds = 0): void
    {
        $platform = Http::str('platform', '', 16);
        Respond::ok(Stats::summary($platform !== '' ? $platform : null), 'ok', $cacheSeconds);
    }

    /** GET /v1/stats/trend?days=7 */
    public static function trend(array $ctx, int $cacheSeconds = 0): void
    {
        $days = Http::int('days', 7);
        $platform = Http::str('platform', '', 16);
        $series = Stats::trend($days, $platform !== '' ? $platform : null);

        $totals = ['launches' => 0, 'taps' => 0, 'devices' => 0];
        foreach ($series as $row) {
            $totals['launches'] += $row['launches'];
            $totals['taps'] += $row['taps'];
            $totals['devices'] = max($totals['devices'], $row['devices']);
        }

        Respond::ok([
            'days'   => max(1, min(180, $days)),
            'totals' => $totals,
            'series' => $series,
        ], 'ok', $cacheSeconds);
    }

    /**
     * GET /v1/stats/overview —— 看板一次拿全（聚合接口）
     *
     * 存在的理由：网页看板要整页 30 秒刷新一次。若分别打 summary /
     * trend / breakdown / leaderboard 四个接口，每个页面每 30 秒就是
     * 4 次请求；合并成一个后，看板的请求量降到 1/4，且四个区块的
     * 数据是同一时刻的快照（分开拉会出现"数字对不上"的错位）。
     *
     * 参数：`days`（趋势天数，默认 30）、`range`（榜单口径）、`limit`。
     */
    public static function overview(array $ctx, int $cacheSeconds = 0): void
    {
        $days = Http::int('days', 30);
        $range = Http::str('range', 'week', 8);
        $limit = Http::int('limit', 20);
        if (!in_array($range, ['day', 'week', 'month', 'all'], true)) {
            $range = 'week';
        }

        $breakdown = [];
        foreach (Device::platformBreakdown() as $row) {
            $breakdown[$row['platform']] = [
                'platform' => $row['platform'],
                'label'    => platform_label((string) $row['platform']),
                'devices'  => (int) $row['devices'],
                'online'   => 0,
            ];
        }
        foreach (Online::countByPlatform() as $row) {
            if (isset($breakdown[$row['platform']])) {
                $breakdown[$row['platform']]['online'] = (int) $row['online'];
            }
        }

        Respond::ok([
            'summary'     => Stats::summary(),
            'trend'       => Stats::trend($days),
            'breakdown'   => [
                'platforms' => array_values($breakdown),
                'versions'  => Device::versionBreakdown(8),
                'devices'   => Device::count(),
            ],
            'leaderboard' => [
                'range' => $range,
                'note'  => '仅统计主动开启「功德榜」的设备，昵称已做打码处理',
                'items' => Rank::leaderboard($range, $limit),
            ],
            'generated_at' => date('c'),
        ], 'ok', $cacheSeconds);
    }

    /** GET /v1/stats/breakdown —— 平台 / 版本 / 在线分布 */
    public static function breakdown(array $ctx, int $cacheSeconds = 0): void
    {
        $online = [];
        foreach (Online::countByPlatform() as $row) {
            $online[$row['platform']] = (int) $row['online'];
        }

        $platforms = [];
        foreach (Device::platformBreakdown() as $row) {
            $platforms[] = [
                'platform' => $row['platform'],
                'label'    => platform_label((string) $row['platform']),
                'devices'  => (int) $row['devices'],
                'online'   => $online[$row['platform']] ?? 0,
            ];
        }

        Respond::ok([
            'platforms' => $platforms,
            'versions'  => Device::versionBreakdown(8),
            'totals'    => Stats::totals(),
            'devices'   => Device::count(),
            'today'     => [
                'active_devices' => Device::activeToday(),
            ],
        ], 'ok', $cacheSeconds);
    }

    /** GET /v1/leaderboard?range=week */
    public static function leaderboard(array $ctx, int $cacheSeconds = 0): void
    {
        $range = Http::str('range', 'week', 8);
        $limit = Http::int('limit', 20);
        Respond::ok([
            'range' => in_array($range, ['day', 'week', 'month', 'all'], true) ? $range : 'week',
            'note'  => '仅统计主动开启「功德榜」的设备，昵称已做打码处理',
            'items' => Rank::leaderboard($range, $limit),
        ], 'ok', $cacheSeconds);
    }

    /** GET /v1/profile?device_id=xxx */
    public static function profile(array $ctx, int $cacheSeconds = 0): void
    {
        $deviceId = Http::str('device_id', '', 64);
        if ($deviceId === '' || !Device::isValidId($deviceId)) {
            Respond::fail(Respond::E_PARAM, 'device_id 缺失或格式非法', 400);
        }
        // 带 app_key 时走应用隔离的查询；不带时按 device_id 跨应用查
        // （公开接口拿不到 app 上下文，见 Device::findAny 的说明）
        $device = isset($ctx['app']['id'])
            ? Device::find((int) $ctx['app']['id'], $deviceId)
            : Device::findAny($deviceId);
        if (!$device) {
            Respond::fail(Respond::E_PARAM, '设备不存在', 404, ['need_launch' => true]);
        }
        Respond::ok(Rank::profile((int) $device['id']), 'ok', 0);
    }

    /** POST /v1/profile/opt-in —— 开启/关闭功德榜并设置昵称 */
    public static function optIn(array $ctx, int $cacheSeconds = 0): void
    {
        $device = Base::device($ctx);
        $enabled = Http::bool('enabled', true);
        $nickname = Http::str('nickname', '', 16);

        if ($enabled && $nickname === '' && trim((string) $device['nickname']) === '') {
            Respond::fail(Respond::E_PARAM, '开启功德榜需要先设置昵称', 400);
        }

        Rank::setOptIn((int) $device['id'], $enabled, $nickname);
        Respond::ok([
            'rank_opt_in' => $enabled,
            'profile'     => Rank::profile((int) $device['id']),
        ], $enabled ? '已加入功德榜' : '已退出功德榜');
    }
}
