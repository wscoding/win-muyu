<?php
namespace Wid\Api;

use Wid\Core\Event;
use Wid\Core\Http;
use Wid\Core\Respond;
use Wid\Model\AppKey;
use Wid\Model\Content;
use Wid\Model\Device;
use Wid\Model\Online;
use Wid\Model\Rank;
use Wid\Model\Stats;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 生命周期：启动 / 心跳 / 下线。
 *
 * 三个接口的职责刻意分得很清：
 * - launch 每次启动一次，负责注册设备、累计启动数、建立会话，并**顺带下发**
 *   运行配置与公告 —— 这样客户端冷启动只需要一个请求就能拿到所有"服务端说了算"的东西；
 * - heartbeat 每分钟一次，只负责刷新在线时间窗，顺带记录心跳数；
 * - offline 只在用户主动退出时调用；崩溃/强杀不需要它，靠心跳超时兜底。
 */
final class Lifecycle
{
    public static function launch(array $ctx, int $cacheSeconds = 0): void
    {
        $appId = (int) $ctx['app']['id'];
        $deviceId = Base::requireStr('device_id', 64);
        if (!Device::isValidId($deviceId)) {
            Respond::fail(Respond::E_PARAM, 'device_id 格式非法（8–64 位字母数字、下划线或短横线）', 400);
        }

        $meta = [
            'platform'       => Http::str('platform', '', 16),
            'os_version'     => Http::str('os_version', '', 32),
            'client_version' => Http::str('client_version', '', 24),
            'channel'        => Http::str('channel', '', 16),
            'color'          => Http::str('color', '', 8),
        ];

        $device = Device::touch($appId, $deviceId, $meta);
        if (!$device) {
            Respond::fail(Respond::E_SERVER, '设备注册失败', 500);
        }

        $platform = $device['platform'] !== '' ? $device['platform'] : platform_norm($meta['platform']);
        $devicePk = (int) $device['id'];

        Stats::addLaunch($appId, $platform);
        Stats::markActive($appId, $devicePk, $platform);

        $sessionId = Http::str('session_id', '', 64);
        $newSession = false;
        if ($sessionId !== '') {
            $newSession = Online::beat($appId, $devicePk, $sessionId, $platform);
        }

        if ($newSession) {
            Event::log('session_open', '设备上线 ' . $deviceId . ' (' . $platform . ')', 'info', $appId, $deviceId);
        }

        $summary = Stats::summary();
        $taps = (int) $device['tap_total'];

        Respond::json([
            'server_time' => date('c'),
            'device'      => [
                'device_id'     => $device['device_id'],
                'platform'      => $platform,
                'first_seen_at' => $device['first_seen_at'],
                'launch_count'  => (int) $device['launch_count'] + 1,
                'status'        => (int) $device['status'],
            ],
            // 服务端累计值与客户端自己的计数是两套数字：客户端可以据此校准
            'server_taps'   => $taps,
            'server_merit'  => (int) $device['merit_total'],
            'new_session'   => $newSession,
            'global'        => [
                'launches' => $summary['launches'],
                'taps'     => $summary['taps'],
                'merit'    => $summary['merit'],
                'online'   => $summary['online'],
                'devices'  => $summary['devices'],
            ],
            'title'         => Rank::titleFor($taps),
            'config'        => Content::clientConfig($platform),
            'announcements' => Content::announcements($platform, $meta['client_version'], 3),
        ], Respond::OK, 'ok', 200, 0);
    }

    public static function heartbeat(array $ctx, int $cacheSeconds = 0): void
    {
        $appId = (int) $ctx['app']['id'];
        $device = Base::device($ctx);
        $devicePk = (int) $device['id'];
        $platform = $device['platform'] !== '' ? $device['platform'] : 'other';

        $sessionId = Http::str('session_id', '', 64);
        if ($sessionId === '') {
            // 没有 session_id 时用设备标识兜底，保证心跳始终能建立会话
            $sessionId = 'hb-' . substr(sha1($device['device_id']), 0, 24);
        }
        Online::beat($appId, $devicePk, $sessionId, $platform);
        Stats::addHeartbeat($appId, $platform);
        Stats::markActive($appId, $devicePk, $platform);
        Device::seen($devicePk, Http::str('client_version', '', 24));

        Respond::ok([
            'server_time' => date('c'),
            'online'      => Online::countNow(),
            'global_taps' => Stats::totals()['taps'],
        ], 'ok');
    }

    public static function offline(array $ctx, int $cacheSeconds = 0): void
    {
        $device = Base::device($ctx, false);
        if ($device) {
            Online::forget((int) $device['id']);
        }
        Respond::ok(['offline' => true], '已下线');
    }

    /** 公开接口在未带 app_key 时需要一个默认应用 */
    public static function appIdOf(array $ctx): int
    {
        $appId = (int) ($ctx['app']['id'] ?? 0);
        return $appId > 0 ? $appId : AppKey::defaultId();
    }
}
