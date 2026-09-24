<?php
namespace Wid\Admin;

use Wid\Core\Db;
use Wid\Core\Event;
use Wid\Core\Http;
use Wid\Core\Rate;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 后台鉴权。
 *
 * 三种进入方式，按优先级：
 * 1. `Authorization: Bearer <token>` —— 给脚本 / CI 用，令牌只存 sha256，可设过期时间；
 * 2. 登录 Cookie —— 人工在浏览器里用，内容是 `过期时间|HMAC 签名`，
 *    签名密钥在 app/config.php 里（不写库、不进版本库）；
 * 3. 都没有则拒绝。
 *
 * CSRF：所有写操作都要求 `X-CSRF` 头，其值由令牌派生，登录后由页面注入到 meta 标签。
 */
final class AdminAuth
{
    /** 校验当前请求，返回 ['actor'=>string, 'scope'=>array] 或 null */
    public static function check(): ?array
    {
        $bearer = self::bearer();
        if ($bearer !== '') {
            return self::checkToken($bearer);
        }
        $session = self::checkCookie();
        if ($session !== null) {
            return $session;
        }
        return null;
    }

    /** API 场景：未登录直接 401 */
    public static function requireLoginJson(): array
    {
        $actor = self::check();
        if ($actor === null) {
            \Wid\Core\Respond::json(null, 40302, '未登录或登录已过期', 401, 0, false);
        }
        return $actor;
    }

    /** 写操作场景：额外校验 CSRF */
    public static function requireWrite(): array
    {
        $actor = self::requireLoginJson();
        $token = Http::header('X-CSRF');
        if ($token === '') {
            $token = (string) Http::input('csrf', '');
        }
        if (!hash_equals(self::csrfToken(), $token)) {
            \Wid\Core\Respond::json(null, 40302, 'CSRF 校验失败，请刷新页面重试', 403, 0, false);
        }
        return $actor;
    }

    // ---------------- 登录 ----------------

    public static function login(string $password): array
    {
        // 登录接口是唯一的无鉴权入口，必须先按 IP 限流，防爆破
        $limit = (int) cfg('admin.login_fail_limit', 8);
        $rate = Rate::hit('login', Http::ip(), $limit, 300);
        if (!$rate['allowed']) {
            self::logLogin(false);
            return ['ok' => false, 'msg' => '尝试次数过多，请 5 分钟后再试'];
        }

        $hash = (string) cfg('admin.password_hash', '');
        if ($hash === '' || !password_verify($password, $hash)) {
            self::logLogin(false);
            Event::log('admin_login_failed', '后台登录失败', 'warn', null, 'admin');
            usleep(300000); // 轻微延时，抬高暴力破解成本
            return ['ok' => false, 'msg' => '口令不正确'];
        }

        self::setCookie();
        self::logLogin(true);
        Event::log('admin_login', '后台登录成功', 'info', null, 'admin');
        return ['ok' => true, 'msg' => '登录成功', 'csrf' => self::csrfToken()];
    }

    public static function logout(): void
    {
        $name = (string) cfg('admin.cookie_name', 'wid_admin');
        setcookie($name, '', [
            'expires'  => time() - 3600,
            'path'     => '/admin',
            'httponly' => true,
            'samesite' => 'Lax',
            'secure'   => Http::isSecure(),
        ]);
        Event::log('admin_logout', '后台退出登录', 'info', null, 'admin');
    }

    /** 生成用于写入 app/config.php 的口令哈希（部署脚本会调用同一逻辑） */
    public static function hashPassword(string $password): string
    {
        return password_hash($password, PASSWORD_DEFAULT);
    }

    // ---------------- 内部 ----------------

    private static function setCookie(): void
    {
        $ttl = (int) cfg('admin.session_ttl', 43200);
        $exp = time() + $ttl;
        $value = $exp . '|' . self::sign((string) $exp);
        setcookie((string) cfg('admin.cookie_name', 'wid_admin'), $value, [
            'expires'  => $exp,
            'path'     => '/admin',
            'httponly' => true,
            'samesite' => 'Lax',
            'secure'   => Http::isSecure(),
        ]);
    }

    private static function checkCookie(): ?array
    {
        $name = (string) cfg('admin.cookie_name', 'wid_admin');
        $raw = (string) ($_COOKIE[$name] ?? '');
        if ($raw === '' || strpos($raw, '|') === false) {
            return null;
        }
        list($exp, $sig) = explode('|', $raw, 2);
        if (!ctype_digit($exp) || (int) $exp < time()) {
            return null;
        }
        if (!hash_equals(self::sign($exp), $sig)) {
            return null;
        }
        return ['actor' => 'cookie', 'scope' => ['read', 'write']];
    }

    private static function sign(string $payload): string
    {
        return hash_hmac('sha256', 'wid-admin|' . $payload, (string) cfg('admin.session_secret', 'wid'));
    }

    /** CSRF 令牌由会话密钥派生，登录后可由页面读给前端 */
    public static function csrfToken(): string
    {
        return substr(hash_hmac('sha256', 'csrf', (string) cfg('admin.session_secret', 'wid')), 0, 32);
    }

    private static function bearer(): string
    {
        $header = Http::header('Authorization');
        if (stripos($header, 'Bearer ') === 0) {
            return trim(substr($header, 7));
        }
        return (string) Http::input('token', '');
    }

    private static function checkToken(string $token): ?array
    {
        if (strlen($token) < 24) {
            return null;
        }
        try {
            $row = Db::one(
                'SELECT * FROM admin_tokens WHERE token_hash = ? LIMIT 1',
                [hash('sha256', $token)]
            );
        } catch (\Throwable $e) {
            return null;
        }
        if (!$row) {
            return null;
        }
        if ($row['expires_at'] !== null && strtotime((string) $row['expires_at']) < time()) {
            return null;
        }
        Db::tryExec('UPDATE admin_tokens SET last_used_at = NOW() WHERE id = ?', [(int) $row['id']]);
        return [
            'actor' => 'token:' . $row['label'],
            'scope' => array_filter(explode(',', (string) $row['scope'])),
        ];
    }

    public static function createToken(string $label, string $scope = 'read,write', ?int $ttlDays = null): array
    {
        $token = random_hex(24);
        $expires = $ttlDays !== null ? date('Y-m-d H:i:s', time() + $ttlDays * 86400) : null;
        Db::exec(
            'INSERT INTO admin_tokens (token_hash, label, scope, expires_at, created_at) VALUES (?, ?, ?, ?, NOW())',
            [hash('sha256', $token), mb_substr($label, 0, 64, 'UTF-8'), $scope, $expires]
        );
        return ['id' => Db::lastId(), 'token' => $token, 'expires_at' => $expires];
    }

    public static function tokenList(): array
    {
        return Db::all('SELECT id, label, scope, expires_at, last_used_at, created_at FROM admin_tokens ORDER BY id DESC');
    }

    public static function removeToken(int $id): bool
    {
        return Db::exec('DELETE FROM admin_tokens WHERE id = ?', [$id]) > 0;
    }

    private static function logLogin(bool $success): void
    {
        Db::tryExec(
            'INSERT INTO admin_logins (ip, ua, success, created_at) VALUES (?, ?, ?, NOW())',
            [Http::ipBin(Http::ip()), Http::ua(), $success ? 1 : 0]
        );
    }

    public static function recentLogins(int $limit = 20): array
    {
        $rows = Db::all('SELECT * FROM admin_logins ORDER BY id DESC LIMIT ' . max(1, min(100, $limit)));
        foreach ($rows as &$row) {
            $row['ip_text'] = Http::ipText($row['ip']);
            unset($row['ip']);
        }
        return $rows;
    }
}
