<?php
namespace Wid\Core;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 请求解析。统一处理「客户端可能用 JSON、也可能用表单」的差异，
 * 并把 nginx try_files 重写后的真实路由还原出来。
 */
final class Http
{
    public static function method(): string
    {
        $m = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
        // 兼容部分代理只允许 GET/POST 的场景
        if ($m === 'POST' && isset($_POST['_method'])) {
            $m = strtoupper((string) $_POST['_method']);
        }
        return $m;
    }

    /**
     * 还原出客户端实际请求的路径（**保留 `/api` 前缀**）。
     *
     * 三条来源依次兜底：
     * 1. nginx `try_files` 重写到 /api/index.php 时 REQUEST_URI 保持不变；
     * 2. 直接访问 /api/index.php/v1/launch（PATH_INFO 方式）；
     * 3. 显式传 ?__path=/v1/launch（面板改写成未知状态时的保底方案）。
     */
    private static function requestPath(): string
    {
        $uri = $_SERVER['REQUEST_URI'] ?? '/';
        $pos = strpos($uri, '?');
        if ($pos !== false) {
            $uri = substr($uri, 0, $pos);
        }
        $script = $_SERVER['SCRIPT_NAME'] ?? '';
        if ($script !== '' && strpos($uri, $script) === 0) {
            $uri = substr($uri, strlen($script));
        }
        if (isset($_GET['__path'])) {
            $uri = '/' . ltrim((string) $_GET['__path'], '/');
        }
        return '/' . trim($uri, '/');
    }

    /** 路由匹配用的路径：去掉 `/api` 前缀，统一成 /v1/... */
    public static function path(): string
    {
        $uri = self::requestPath();
        if ($uri === '/api') {
            return '/';
        }
        if (strpos($uri, '/api/') === 0) {
            return substr($uri, 4);
        }
        return $uri;
    }

    /**
     * 签名校验可接受的路径写法。
     *
     * 契约里 PATH 指的是「客户端请求的完整路径」（`/api/v1/launch`），
     * 但客户端也有可能按去掉前缀的 `/{version}/{action}` 去签，两种写法
     * 在服务端都是同一个资源，因此都接受 —— 免得仅仅因为一个前缀
     * 就让整个上报链路静默失效（这种问题极难排查）。
     */
    public static function pathVariants(): array
    {
        $full = self::requestPath();
        $short = self::path();
        $variants = [$full];
        if ($short !== $full) {
            $variants[] = $short;
        }
        return array_values(array_unique($variants));
    }

    public static function header(string $name): string
    {
        $key = 'HTTP_' . strtoupper(str_replace('-', '_', $name));
        return (string) ($_SERVER[$key] ?? '');
    }

    /** 原始请求体（读取一次后缓存，避免 php://input 被重复消费） */
    public static function rawBody(): string
    {
        static $cached = null;
        if ($cached === null) {
            $cached = (string) file_get_contents('php://input');
        }
        return $cached;
    }

    /** 请求体解析：JSON 优先，其次表单 */
    public static function body(): array
    {
        static $parsed = null;
        if ($parsed !== null) {
            return $parsed;
        }
        $raw = self::rawBody();
        $parsed = [];
        $trim = ltrim($raw);
        if ($trim !== '' && ($trim[0] === '{' || $trim[0] === '[')) {
            $json = json_decode($raw, true);
            if (is_array($json)) {
                $parsed = $json;
                return $parsed;
            }
        }
        if (!empty($_POST)) {
            $parsed = $_POST;
        } elseif ($raw !== '' && strpos($raw, '=') !== false) {
            parse_str($raw, $form);
            $parsed = is_array($form) ? $form : [];
        }
        return $parsed;
    }

    /** 统一取值：请求体 > 查询串 */
    public static function input(string $key, $default = null)
    {
        $body = self::body();
        if (array_key_exists($key, $body)) {
            return $body[$key];
        }
        if (array_key_exists($key, $_GET)) {
            return $_GET[$key];
        }
        return $default;
    }

    public static function str(string $key, string $default = '', int $maxLen = 200): string
    {
        $v = self::input($key, $default);
        if (is_array($v)) {
            return $default;
        }
        $v = trim((string) $v);
        if ($maxLen > 0 && mb_strlen($v, 'UTF-8') > $maxLen) {
            $v = mb_substr($v, 0, $maxLen, 'UTF-8');
        }
        return $v;
    }

    public static function int(string $key, int $default = 0): int
    {
        $v = self::input($key, $default);
        if (is_array($v) || $v === null || $v === '') {
            return $default;
        }
        return (int) $v;
    }

    public static function bool(string $key, bool $default = false): bool
    {
        $v = self::input($key, $default ? '1' : '0');
        if (is_bool($v)) {
            return $v;
        }
        return in_array(strtolower((string) $v), ['1', 'true', 'yes', 'on'], true);
    }

    public static function query(string $key, $default = null)
    {
        return $_GET[$key] ?? $default;
    }

    /** 真实客户端 IP（Cloudflare 回源时取 CF-Connecting-IP） */
    public static function ip(): string
    {
        foreach (['HTTP_CF_CONNECTING_IP', 'HTTP_X_REAL_IP', 'HTTP_X_FORWARDED_FOR', 'REMOTE_ADDR'] as $key) {
            $val = (string) ($_SERVER[$key] ?? '');
            if ($val === '') {
                continue;
            }
            if (strpos($val, ',') !== false) {
                $val = trim(explode(',', $val)[0]);
            }
            if (filter_var($val, FILTER_VALIDATE_IP)) {
                return $val;
            }
        }
        return '0.0.0.0';
    }

    /** IP 转二进制存库（IPv4 4 字节 / IPv6 16 字节） */
    public static function ipBin(string $ip): ?string
    {
        if (!filter_var($ip, FILTER_VALIDATE_IP)) {
            return null;
        }
        $bin = @inet_pton($ip);
        return $bin === false ? null : $bin;
    }

    /** 二进制 IP 转回可读文本 */
    public static function ipText(?string $bin): string
    {
        if (!$bin) {
            return '';
        }
        $text = @inet_ntop($bin);
        return $text === false ? '' : $text;
    }

    public static function ua(): string
    {
        return mb_substr((string) ($_SERVER['HTTP_USER_AGENT'] ?? ''), 0, 255, 'UTF-8');
    }

    /** 请求是否来自 HTTPS（Cloudflare 回源时以 X-Forwarded-Proto 为准） */
    public static function isSecure(): bool
    {
        $proto = strtolower((string) ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? ''));
        if ($proto !== '') {
            return strpos($proto, 'https') !== false;
        }
        return !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';
    }

    /** 404 页面 */
    public static function notFoundPage(): void
    {
        http_response_code(404);
        header('Content-Type: text/html; charset=utf-8');
        $file = WID_ROOT . '/404.php';
        if (is_file($file)) {
            require $file;
            return;
        }
        echo '<!doctype html><meta charset="utf-8"><title>404</title><h1>404</h1>';
    }
}
