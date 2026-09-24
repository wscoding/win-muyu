<?php
namespace Wid\Core;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 接口签名（HMAC-SHA256）。
 *
 * 为什么要有它：v2 只靠明文 app_key 鉴权，任何人拿到这个公开常量
 * 就能伪造上报（docs/backend-api.md 第 4 条改进方向）。新接口把 app_key
 * 只当"身份标识"，真正的凭据是 app_secret，请求必须携带按下面规则算出的签名。
 *
 * 待签名字符串（每行一段，行尾不加空格）：
 *
 *     METHOD
 *     PATH
 *     APP_KEY
 *     TIMESTAMP
 *     NONCE
 *     SHA256_HEX(原始请求体)
 *
 * GET 请求的请求体为空，此时最后一行固定为
 * `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。
 *
 * 签名结果放在请求头 `X-Signature`，配套 `X-App-Key` / `X-Timestamp` /
 * `X-Nonce`。时间戳窗口 + nonce 唯一表共同防御重放。
 */
final class Sign
{
    const EMPTY_BODY_HASH = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

    public static function canonical(
        string $method,
        string $path,
        string $appKey,
        string $ts,
        string $nonce,
        string $rawBody
    ): string {
        $bodyHash = $rawBody === ''
            ? self::EMPTY_BODY_HASH
            : hash('sha256', $rawBody);
        return implode("\n", [
            strtoupper($method),
            $path,
            $appKey,
            $ts,
            $nonce,
            $bodyHash,
        ]);
    }

    public static function compute(string $secret, string $canonical): string
    {
        return hash_hmac('sha256', $canonical, $secret);
    }

    /**
     * 校验一次请求的签名。
     * 返回 ['ok'=>bool, 'code'=>int, 'msg'=>string, 'debug'=>array(仅失败时)]。
     */
    public static function verify(array $app, string $method, string $rawBody): array
    {
        $appKey = Http::header('X-App-Key');
        $ts     = Http::header('X-Timestamp');
        $nonce  = Http::header('X-Nonce');
        $sign   = Http::header('X-Signature');

        if ($appKey === '' || $ts === '' || $nonce === '' || $sign === '') {
            return ['ok' => false, 'code' => Respond::E_SIGN, 'msg' => '缺少签名相关请求头（X-App-Key / X-Timestamp / X-Nonce / X-Signature）'];
        }
        if (!ctype_digit($ts)) {
            return ['ok' => false, 'code' => Respond::E_TS, 'msg' => '时间戳格式非法'];
        }
        if (strlen($nonce) < 8 || strlen($nonce) > 64) {
            return ['ok' => false, 'code' => Respond::E_SIGN, 'msg' => 'nonce 长度非法（8–64）'];
        }
        if (!preg_match('/^[0-9a-f]{64}$/', $sign)) {
            return ['ok' => false, 'code' => Respond::E_SIGN, 'msg' => '签名格式非法'];
        }

        $window = (int) cfg('api.ts_window', 300);
        if (abs(time() - (int) $ts) > $window) {
            return ['ok' => false, 'code' => Respond::E_TS, 'msg' => '客户端时间与服务器偏差过大，请校准系统时间'];
        }

        $expected = [];
        foreach (Http::pathVariants() as $candidate) {
            $expected[] = self::compute(
                (string) $app['app_secret'],
                self::canonical($method, $candidate, $appKey, $ts, $nonce, $rawBody)
            );
        }
        // hash_equals 防时序侧信道；对每种可接受的路径写法都比一遍
        $matched = false;
        foreach ($expected as $candidate) {
            if (hash_equals($candidate, strtolower($sign))) {
                $matched = true;
                break;
            }
        }
        if (!$matched) {
            return [
                'ok' => false,
                'code' => Respond::E_SIGN,
                'msg' => '签名校验失败',
                'debug' => [
                    'signed_paths' => Http::pathVariants(),
                    'method' => strtoupper($method),
                    'body_sha256' => $rawBody === '' ? self::EMPTY_BODY_HASH : hash('sha256', $rawBody),
                    'body_len' => strlen($rawBody),
                    'body_preview' => mb_substr($rawBody, 0, 160, 'UTF-8'),
                    'content_type' => Http::header('Content-Type'),
                    'content_length' => Http::header('Content-Length'),
                ],
            ];
        }

        // 重放检查：同 app 下 nonce 只允许出现一次
        if (!self::rememberNonce((int) $app['id'], $nonce)) {
            return ['ok' => false, 'code' => Respond::E_REPLAY, 'msg' => '该请求已被处理过（nonce 重复）'];
        }

        return ['ok' => true, 'code' => Respond::OK, 'msg' => 'ok'];
    }

    /** 记录 nonce，返回 false 表示已存在（即重放） */
    private static function rememberNonce(int $appId, string $nonce): bool
    {
        $ttl = (int) cfg('api.nonce_ttl', 600);
        $now = time();
        $hash = sha1($appId . '|' . $nonce);
        $affected = Db::exec(
            'INSERT IGNORE INTO api_nonces (nonce_hash, app_id, created_at, expires_at) VALUES (?, ?, ?, ?)',
            [$hash, $appId, $now, $now + $ttl]
        );
        return $affected > 0;
    }
}
