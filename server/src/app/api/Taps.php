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
 * 敲击上报（核心高频接口）。
 *
 * 相比 v2 的三点改动：
 * 1. **增量语义**。v2 每次都上报累计值 content，服务端只能整行覆盖；
 *    这里同时接受 `total`（客户端累计）与 `delta`（本次增量），
 *    服务端优先用 `total - 上次快照` 算增量 —— 丢包、乱序、重发都不会算错。
 * 2. **批量**。客户端可以攒 N 次敲击再发一次，把 QPS 压到个位数，
 *    这是这台 4G 机器能承受的前提。
 * 3. **不写明细**。只累加聚合口径（global / daily / per-device），
 *    原始敲击序列留在客户端，服务端不做行为轨迹留存。
 */
final class Taps
{
    public static function handle(array $ctx, int $cacheSeconds = 0): void
    {
        $appId = (int) $ctx['app']['id'];
        $device = Base::device($ctx);
        $result = self::apply($ctx, $device, [
            'delta' => Http::int('delta', 0),
            'total' => Http::int('total', -1),
            'merit' => Http::int('merit', -1),
            'client_version' => Http::str('client_version', '', 24),
            'color' => Http::str('color', '', 8),
        ]);
        Respond::ok($result, 'ok');
    }

    /**
     * 批量上报：`items` 为 [{delta|total|merit}, ...]。
     * 有 total 的按累计值算增量，没有的把 delta 相加；整批只写一次库。
     */
    public static function batch(array $ctx, int $cacheSeconds = 0): void
    {
        $device = Base::device($ctx);
        $items = Http::input('items', []);
        if (!is_array($items) || !$items) {
            Respond::fail(Respond::E_PARAM, 'items 必须是非空数组', 400);
        }
        if (count($items) > 500) {
            Respond::fail(Respond::E_PARAM, '单批最多 500 条', 400);
        }

        $deltaSum = 0;
        $maxTotal = -1;
        $maxMerit = -1;
        foreach ($items as $item) {
            if (!is_array($item)) {
                continue;
            }
            if (isset($item['total']) && (int) $item['total'] >= 0) {
                $maxTotal = max($maxTotal, (int) $item['total']);
            }
            if (isset($item['merit']) && (int) $item['merit'] >= 0) {
                $maxMerit = max($maxMerit, (int) $item['merit']);
            }
            if (isset($item['delta'])) {
                $deltaSum += max(0, (int) $item['delta']);
            }
        }

        $result = self::apply($ctx, $device, [
            'delta'          => $deltaSum,
            'total'          => $maxTotal,
            'merit'          => $maxMerit,
            'client_version' => Http::str('client_version', '', 24),
            'color'          => Http::str('color', '', 8),
        ]);
        $result['batched'] = count($items);
        Respond::ok($result, 'ok');
    }

    /** 真正落库的地方，单条与批量共用 */
    private static function apply(array $ctx, array $device, array $input): array
    {
        $appId = (int) $ctx['app']['id'];
        $devicePk = (int) $device['id'];
        $platform = $device['platform'] !== '' ? $device['platform'] : 'other';
        $tapMax = (int) cfg('api.tap_delta_max', 20000);

        $prevTap = (int) $device['snapshot_tap_total'];
        $prevMerit = (int) $device['snapshot_merit_total'];

        $total = (int) $input['total'];
        $delta = max(0, (int) $input['delta']);

        if ($total >= 0) {
            // 以客户端累计值为准：重装/回滚导致的负数按 0 处理，不算负功德
            $delta = max(0, $total - $prevTap);
            $newSnapshot = $total;
        } else {
            $newSnapshot = $prevTap + $delta;
        }

        $clamped = false;
        if ($delta > $tapMax) {
            // 单次上报超过上限：按上限截断并记事件，避免脏数据污染总量
            $delta = $tapMax;
            $clamped = true;
        }

        $meritInput = (int) $input['merit'];
        if ($meritInput >= 0) {
            $meritDelta = max(0, $meritInput - $prevMerit);
            $newMerit = $meritInput;
        } else {
            // 与 v2 一致的功德口径：每 100 次敲击记 1 功德（向下取整）
            $newMerit = intdiv($newSnapshot, 100);
            $meritDelta = max(0, $newMerit - $prevMerit);
        }

        if ($delta > 0 || $meritDelta > 0) {
            Device::addTaps($devicePk, $delta, $meritDelta);
            Stats::addTaps($appId, $platform, $delta, $meritDelta);
        }
        Device::setSnapshot($devicePk, $newSnapshot, $newMerit);
        Stats::markActive($appId, $devicePk, $platform, $delta);
        Device::seen($devicePk, (string) $input['client_version']);

        if ($clamped) {
            \Wid\Core\Event::log(
                'tap_clamped',
                '单次敲击增量超限：上报 ' . $input['total'] . ' 快照 ' . $prevTap,
                'warn',
                $appId,
                (string) $device['device_id']
            );
        }

        $totals = Stats::totals();
        $todayTotals = Stats::todayTotals();
        $today = (int) \Wid\Core\Db::value(
            'SELECT COALESCE(tap_delta, 0) FROM daily_active WHERE stat_date = CURDATE() AND device_pk = ?',
            [$devicePk],
            0
        );

        return [
            'accepted'    => $delta,
            'clamped'     => $clamped,
            'server_time' => date('c'),
            'device'      => [
                'taps_total'  => $prevTap + $delta,
                'merit_total' => $prevMerit + $meritDelta,
                'taps_today'  => $today,
            ],
            'global'      => [
                'taps'       => $totals['taps'],
                'merit'      => $totals['merit'],
                'online'     => Online::countNow(),
                // 全网今日，与看板同一个口径：客户端可以直接回显，
                // 用户一眼就能确认「我的敲击上去了」
                'taps_today' => $todayTotals['taps'],
            ],
            'title'       => Rank::titleFor($prevTap + $delta),
        ];
    }
}
