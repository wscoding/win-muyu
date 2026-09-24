<?php
namespace Wid\Model;

use Wid\Core\Db;
use Wid\Core\Event;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 客户端（应用）注册表。
 *
 * app_key 是公开标识（硬编码在客户端里），app_secret 才是签名凭据。
 * 一个 app_key 对应一个平台族，未来接入新的客户端（比如移动端木鱼）
 * 只需在此新增一行，不用改代码。
 */
final class AppKey
{
    const DEFAULT_KEY = '8f23f05b4a50b6481ff020320692f9e9';

    public static function findByKey(string $key): ?array
    {
        if ($key === '') {
            return null;
        }
        return Db::one('SELECT * FROM apps WHERE app_key = ? LIMIT 1', [$key]);
    }

    public static function find(int $id): ?array
    {
        return Db::one('SELECT * FROM apps WHERE id = ? LIMIT 1', [$id]);
    }

    public static function all(): array
    {
        return Db::all('SELECT * FROM apps ORDER BY id ASC');
    }

    /** 站点默认（也是当前唯一）的应用 id；公开统计接口以它为主 */
    public static function defaultId(): int
    {
        return (int) Db::value('SELECT id FROM apps ORDER BY id ASC LIMIT 1', [], 0);
    }

    public static function create(string $appKey, string $secret, string $name, int $rateLimit = 600): int
    {
        Db::exec(
            'INSERT INTO apps (app_key, app_secret, name, status, rate_limit_per_min, request_total, created_at, updated_at)
             VALUES (?, ?, ?, 1, ?, 0, NOW(), NOW())',
            [$appKey, $secret, $name, $rateLimit]
        );
        return Db::lastId();
    }

    /** 仅允许更新白名单字段，避免后台表单越权写入 */
    public static function update(int $id, array $fields): bool
    {
        $allow = ['name', 'app_secret', 'status', 'rate_limit_per_min', 'note'];
        $sets = [];
        $params = [];
        foreach ($allow as $key) {
            if (array_key_exists($key, $fields)) {
                $sets[] = '`' . $key . '` = ?';
                $params[] = $fields[$key];
            }
        }
        if (!$sets) {
            return false;
        }
        $sets[] = 'updated_at = NOW()';
        $params[] = $id;
        Db::exec('UPDATE apps SET ' . implode(', ', $sets) . ' WHERE id = ?', $params);
        return true;
    }

    /** 记录一次有效请求（失败静默） */
    public static function touch(int $id): void
    {
        Db::tryExec(
            'UPDATE apps SET request_total = request_total + 1, last_used_at = NOW() WHERE id = ?',
            [$id]
        );
    }

    /** 首次部署时确保默认应用存在，返回其 id */
    public static function ensureDefault(?string $secret = null): int
    {
        $found = self::findByKey(self::DEFAULT_KEY);
        if ($found) {
            return (int) $found['id'];
        }
        $secret = $secret ?: random_hex(32);
        $id = self::create(self::DEFAULT_KEY, $secret, 'Prue Widgets 桌面端', 900);
        Event::log('app_created', '初始化默认应用 ' . self::DEFAULT_KEY, 'info', $id, 'system');
        return $id;
    }
}
