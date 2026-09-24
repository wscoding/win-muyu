<?php
namespace Wid\Core;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 统一响应格式。
 *
 * 设计目标（相对 v2 的改进）：
 * - 永远返回 UTF-8 JSON，业务码与 HTTP 状态码同时给出，客户端既能
 *   靠 HTTP 状态码判断链路，也能靠 code 区分具体业务错误；
 * - 写接口一律 no-store，公开只读接口允许短缓存（Cloudflare 侧也能吃上）。
 */
final class Respond
{
    /** 成功 */
    const OK = 0;
    /** 参数缺失 / 非法 */
    const E_PARAM = 40001;
    /** 签名不匹配 */
    const E_SIGN = 40101;
    /** 时间戳超出允许窗口 */
    const E_TS = 40102;
    /** nonce 重复（重放请求） */
    const E_REPLAY = 40103;
    /** app_key 不存在 */
    const E_APP = 40104;
    /** app_key 已停用 */
    const E_APP_DISABLED = 40301;
    /** 无权限 */
    const E_FORBIDDEN = 40302;
    /** 路由不存在 */
    const E_NOTFOUND = 40401;
    /** 请求过于频繁 */
    const E_RATE = 42901;
    /** 服务端异常 */
    const E_SERVER = 50001;

    private static $sent = false;

    public static function ok($data = null, string $msg = 'ok', int $cacheSeconds = 0): void
    {
        self::json($data, self::OK, $msg, 200, $cacheSeconds);
    }

    public static function fail(int $code, string $msg, int $status = 400, $extra = null): void
    {
        self::json($extra === null ? null : ['detail' => $extra], $code, $msg, $status, 0, false);
    }

    public static function json($data, int $code, string $msg, int $status, int $cacheSeconds = 0, bool $okFlag = true): void
    {
        if (self::$sent) {
            return;
        }
        self::$sent = true;

        if (!headers_sent()) {
            http_response_code($status);
            header('Content-Type: application/json; charset=utf-8');
            header('X-Api-Version: v3');
            if ($cacheSeconds > 0) {
                header('Cache-Control: public, max-age=' . $cacheSeconds);
                header('X-Accel-Expires: ' . $cacheSeconds);
            } else {
                header('Cache-Control: no-store, no-cache, must-revalidate');
                header('Pragma: no-cache');
            }
        }

        $payload = [
            'ok'   => $okFlag,
            'code' => $code,
            'msg'  => $msg,
            'ts'   => time(),
        ];
        if ($data !== null) {
            $payload['data'] = $data;
        }

        // JSON_INVALID_UTF8_SUBSTITUTE：库里若混进非法 UTF-8（例如把
        // VARBINARY 的 IP 直接取出），json_encode 会返回 false，
        // 于是响应体变成空字符串 + HTTP 200 —— 客户端完全无法判断发生了什么。
        // 这里宁可把坏字节替换成 U+FFFD，也绝不返回空响应。
        $json = json_encode(
            $payload,
            JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE
        );
        if ($json === false) {
            error_log('[wid] json_encode failed: ' . json_last_error_msg());
            $json = json_encode([
                'ok'    => false,
                'code'  => self::E_SERVER,
                'msg'   => '响应序列化失败',
                'ts'    => time(),
                'debug' => cfg('api.debug') ? json_last_error_msg() : null,
            ], JSON_INVALID_UTF8_SUBSTITUTE);
        }

        echo $json;
        exit;
    }

    /** 公开接口的宽松 CORS（写接口不调用它，避免被跨站滥用） */
    public static function cors(int $cacheSeconds = 0): void
    {
        if (headers_sent()) {
            return;
        }
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
        header('Access-Control-Allow-Headers: Content-Type, X-App-Key, X-Timestamp, X-Nonce, X-Signature');
        header('Access-Control-Max-Age: 86400');
    }
}
