<?php
namespace Wid\Api;

use Wid\Core\Db;
use Wid\Core\Event;
use Wid\Core\Http;
use Wid\Core\Respond;
use Wid\Model\Feedback;
use Wid\Model\Settings;
use Wid\Model\Stats;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 杂项：健康检查、反馈、崩溃上报、设置云同步。
 */
final class MiscApi
{
    /** GET /v1/health —— 不查业务表的重活，只确认进程与数据库可用 */
    public static function health(array $ctx, int $cacheSeconds = 0): void
    {
        $db = Db::available();
        Respond::ok([
            'status'      => $db ? 'ok' : 'degraded',
            'api'         => 'v3',
            'server_time' => date('c'),
            'timezone'    => date_default_timezone_get(),
            'php'         => PHP_VERSION,
            'db'          => $db,
            'online'      => $db ? \Wid\Model\Online::countNow() : 0,
            'totals'      => $db ? Stats::totals() : null,
        ], 'ok', 0);
    }

    /** POST /v1/feedback */
    public static function feedback(array $ctx, int $cacheSeconds = 0): void
    {
        $appId = (int) $ctx['app']['id'];
        $device = Base::device($ctx, false);
        $deviceId = Http::str('device_id', '', 64);

        $content = Http::str('content', '', 2000);
        if (mb_strlen($content, 'UTF-8') < 2) {
            Respond::fail(Respond::E_PARAM, '反馈内容太短了，请多写几个字', 400);
        }

        $id = Feedback::submit($appId, $device ? (int) $device['id'] : null, [
            'device_id'      => $deviceId,
            'category'       => Http::str('category', 'other', 24),
            'content'        => $content,
            'contact'        => Http::str('contact', '', 120),
            'client_version' => Http::str('client_version', '', 24),
            'platform'       => Http::str('platform', '', 16),
            'os_version'     => Http::str('os_version', '', 32),
        ]);
        Event::log('feedback', '收到反馈 #' . $id, 'info', $appId, $deviceId);

        Respond::ok(['id' => $id, 'received' => true], '感谢反馈，我们会尽快处理');
    }

    /** POST /v1/crash */
    public static function crash(array $ctx, int $cacheSeconds = 0): void
    {
        $appId = (int) $ctx['app']['id'];
        $device = Base::device($ctx, false);
        $result = Feedback::reportCrash($appId, $device ? (int) $device['id'] : null, [
            'device_id'      => Http::str('device_id', '', 64),
            'error_type'     => Http::str('error_type', 'unknown', 64),
            'message'        => Http::str('message', '', 255),
            'detail'         => Http::str('detail', '', 16000),
            'client_version' => Http::str('client_version', '', 24),
            'platform'       => Http::str('platform', '', 16),
            'os_version'     => Http::str('os_version', '', 32),
        ]);
        Respond::ok($result, 'ok');
    }

    /** POST /v1/settings/pull */
    public static function settingsPull(array $ctx, int $cacheSeconds = 0): void
    {
        $device = Base::device($ctx);
        Respond::ok(Settings::pull((int) $device['id']), 'ok');
    }

    /** POST /v1/settings/push */
    public static function settingsPush(array $ctx, int $cacheSeconds = 0): void
    {
        $appId = (int) $ctx['app']['id'];
        $device = Base::device($ctx);
        $payload = Http::input('payload', []);
        if (!is_array($payload)) {
            Respond::fail(Respond::E_PARAM, 'payload 必须是对象', 400);
        }
        $baseRevision = Http::int('base_revision', 0);
        $force = Http::bool('force', false);

        $result = Settings::push((int) $device['id'], $appId, $payload, $baseRevision, $force);
        if ($result['conflict']) {
            Respond::json($result, Respond::E_PARAM, '设置版本冲突，已返回服务端最新版本', 409, 0, false);
        }
        Respond::ok($result, '设置已同步');
    }
}
