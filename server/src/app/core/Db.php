<?php
namespace Wid\Core;

use PDO;
use PDOException;
use RuntimeException;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * PDO 封装：懒连接 + 常用查询捷径。
 *
 * 连接参数刻意保守 —— 这台机器可用内存约 0.9G，且 MySQL 的
 * max_connections 只有 80，站点侧必须控制并发连接数。
 */
final class Db
{
    /** @var PDO|null */
    private static $pdo = null;

    private static $error = '';

    public static function pdo(): PDO
    {
        if (self::$pdo instanceof PDO) {
            return self::$pdo;
        }
        $c = cfg('db');
        $dsn = sprintf(
            'mysql:host=%s;port=%d;dbname=%s;charset=%s',
            $c['host'],
            (int) $c['port'],
            $c['name'],
            $c['charset'] ?? 'utf8mb4'
        );
        try {
            self::$pdo = new PDO($dsn, $c['user'], $c['pass'], [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
                PDO::ATTR_STRINGIFY_FETCHES  => false,
                PDO::ATTR_TIMEOUT            => 3,
            ]);
            self::$pdo->exec("SET SESSION sql_mode='STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION'");
        } catch (PDOException $e) {
            self::$error = $e->getMessage();
            error_log('[wid] db connect failed: ' . $e->getMessage());
            throw new RuntimeException('数据库连接失败', 0, $e);
        }
        return self::$pdo;
    }

    /** 数据库是否可用（供 /health 与页面降级判断，不抛异常） */
    public static function available(): bool
    {
        try {
            self::pdo();
            return true;
        } catch (\Throwable $e) {
            return false;
        }
    }

    public static function q(string $sql, array $params = []): \PDOStatement
    {
        $st = self::pdo()->prepare($sql);
        $st->execute($params);
        return $st;
    }

    public static function one(string $sql, array $params = []): ?array
    {
        $row = self::q($sql, $params)->fetch();
        return $row === false ? null : $row;
    }

    public static function all(string $sql, array $params = []): array
    {
        return self::q($sql, $params)->fetchAll();
    }

    /** 取第一列 */
    public static function value(string $sql, array $params = [], $default = null)
    {
        $v = self::q($sql, $params)->fetchColumn();
        return $v === false ? $default : $v;
    }

    public static function exec(string $sql, array $params = []): int
    {
        return self::q($sql, $params)->rowCount();
    }

    public static function lastId(): int
    {
        return (int) self::pdo()->lastInsertId();
    }

    /** 单条语句，永不抛（用于埋点、计数这类"失败也无所谓"的写操作） */
    public static function tryExec(string $sql, array $params = []): bool
    {
        try {
            self::exec($sql, $params);
            return true;
        } catch (\Throwable $e) {
            error_log('[wid] try_exec failed: ' . $e->getMessage() . ' | ' . $sql);
            return false;
        }
    }

    /** 事务包裹，异常时回滚 */
    public static function tx(callable $fn)
    {
        $pdo = self::pdo();
        $pdo->beginTransaction();
        try {
            $result = $fn($pdo);
            $pdo->commit();
            return $result;
        } catch (\Throwable $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $e;
        }
    }
}
