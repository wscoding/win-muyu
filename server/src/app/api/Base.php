<?php
namespace Wid\Api;

use Wid\Core\Event;
use Wid\Core\Http;
use Wid\Core\Rate;
use Wid\Core\Respond;
use Wid\Core\Sign;
use Wid\Model\AppKey;
use Wid\Model\Device;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 接口公共前置逻辑。
 *
 * 鉴权流水线的顺序是刻意安排的：
 *   路由匹配 → app_key 查找 → 签名校验（含 nonce 防重放）→ 限流 → 设备解析 → 业务
 *
 * 签名放在限流之前：签名校验只做一次 HMAC，而限流要写一行计数桶。
 * 先验签能让"伪造签名的高频请求"在写库之前就被挡掉，避免被刷库。
 */
final class Base
{
    /**
     * 校验并返回上下文。
     *
     * @param bool $requireSign true=必须签名；false=可匿名（公开只读接口，
     *                          但若带了 X-Signature 则仍然逐项校验）
     */
    public static function guard(bool $requireSign = true): array
    {
        $ctx = ['app' => null, 'signed' => false, 'device_id' => '', 'platform' => ''];

        // 公开接口的匿名调用：只按 IP 限流
        $appKeyHeader = Http::header('X-App-Key');
        $hasSignature = Http::header('X-Signature') !== '';

        if ($appKeyHeader === '') {
            if ($requireSign) {
                Respond::fail(Respond::E_PARAM, '缺少 X-App-Key 请求头', 400);
            }
            self::limitByIp();
            return $ctx;
        }

        $app = AppKey::findByKey($appKeyHeader);
        if (!$app) {
            Respond::fail(Respond::E_APP, 'app_key 无效', 401);
        }
        if ((int) $app['status'] !== 1) {
            Respond::fail(Respond::E_APP_DISABLED, '该客户端已被停用，请联系管理员', 403);
        }

        if ($requireSign || $hasSignature) {
            $result = Sign::verify($app, Http::method(), Http::rawBody());
            if (!$result['ok']) {
                Event::log('sign_failed', $result['msg'] . ' path=' . Http::path(), 'warn', (int) $app['id']);
                Respond::fail(
                    $result['code'],
                    $result['msg'],
                    $result['code'] === Respond::E_RATE ? 429 : 401,
                    // 签名失败极难排查（路径前缀、body 编码、时间戳都会影响），
                    // 打开 api.debug 后把候选路径与 body 哈希一起返回，便于比对
                    cfg('api.debug') ? ($result['debug'] ?? null) : null
                );
            }
            $ctx['signed'] = true;
        } else {
            self::limitByIp();
        }

        self::limitByDevice($app);

        AppKey::touch((int) $app['id']);
        $ctx['app'] = $app;
        return $ctx;
    }

    /** 单 IP 每分钟上限 */
    private static function limitByIp(): void
    {
        $limit = (int) cfg('api.ip_rate_per_min', 240);
        $result = Rate::hit('ip', Http::ip(), $limit, 60);
        if (!$result['allowed']) {
            self::tooMany($result);
        }
    }

    /** 单（应用 × 设备）每分钟上限；设备标识从请求体里取，取不到就退回 IP 维度 */
    private static function limitByDevice(array $app): void
    {
        $limit = (int) ($app['rate_limit_per_min'] ?? 600);
        if ($limit <= 0) {
            return;
        }
        $deviceId = Http::str('device_id', '', 64);
        $ident = $deviceId !== ''
            ? $app['app_key'] . '|' . $deviceId
            : $app['app_key'] . '|ip:' . Http::ip();
        $result = Rate::hit('dev', $ident, $limit, 60);
        if (!$result['allowed']) {
            self::tooMany($result);
        }
    }

    private static function tooMany(array $result): void
    {
        if (!headers_sent()) {
            header('Retry-After: ' . max(1, $result['reset'] - time()));
            header('X-RateLimit-Limit: ' . $result['limit']);
            header('X-RateLimit-Remaining: 0');
        }
        Respond::fail(Respond::E_RATE, '请求过于频繁，请稍后再试', 429);
    }

    /**
     * 解析请求体里的 device_id 对应的设备行。
     *
     * @param bool $requireExists 为 true 时设备必须已通过 /launch 注册过
     */
    public static function device(array $ctx, bool $requireExists = true, ?string $deviceId = null): ?array
    {
        $deviceId = $deviceId ?? Http::str('device_id', '', 64);
        if ($deviceId === '') {
            Respond::fail(Respond::E_PARAM, 'device_id 不能为空', 400);
        }
        if (!Device::isValidId($deviceId)) {
            Respond::fail(Respond::E_PARAM, 'device_id 格式非法（8–64 位字母数字、下划线或短横线）', 400);
        }
        $appId = (int) ($ctx['app']['id'] ?? 0);
        $device = Device::find($appId, $deviceId);
        if (!$device && $requireExists) {
            Respond::fail(Respond::E_PARAM, '设备未注册，请先调用 /v1/launch', 409, ['need_launch' => true]);
        }
        return $device;
    }

    /** 校验必填字符串参数 */
    public static function requireStr(string $key, int $maxLen = 200): string
    {
        $value = Http::str($key, '', $maxLen);
        if ($value === '') {
            Respond::fail(Respond::E_PARAM, '参数 ' . $key . ' 不能为空', 400);
        }
        return $value;
    }

    /** 公开接口的响应缓存头（Cloudflare 与浏览器都能吃上） */
    public static function publicContext(): void
    {
        Respond::cors();
    }
}
