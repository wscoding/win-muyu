<?php
namespace Wid\Core;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 滑动窗口限流（MySQL 计数桶）。
 *
 * 这台机器已经装了 Redis，但按交接文档的结论「Redis 空转被停用」，
 * 且 php-redis 扩展虽在，这里仍选择 MySQL —— 理由是：
 * 1) 站点整体 QPS 很低（批量上报后每秒请求数是个位数）；
 * 2) 少一个进程依赖，运维面更小；
 * 3) 计数桶表随窗口自然过期，清理逻辑简单。
 *
 * 如果将来 QPS 上来了，把 hit() 换成 Redis 的 INCR + EXPIRE 即可，
 * 调用方不需要改。
 */
final class Rate
{
    /**
     * 记一次请求。
     *
     * @param string $scope   命名空间，如 'ip' / 'app' / 'login'
     * @param string $ident   维度标识，如 IP 或 app_id
     * @param int    $limit   窗口内允许的请求数
     * @param int    $window  窗口长度（秒）
     * @return array{allowed:bool,remaining:int,limit:int,reset:int}
     */
    public static function hit(string $scope, string $ident, int $limit, int $window = 60): array
    {
        $now = time();
        $windowStart = intdiv($now, $window) * $window;
        $key = sha1($scope . '|' . $ident . '|' . $windowStart);

        $ok = Db::tryExec(
            'INSERT INTO rate_buckets (bucket_key, scope, hits, window_start, expires_at)
             VALUES (?, ?, 1, ?, ?)
             ON DUPLICATE KEY UPDATE hits = hits + 1',
            [$key, $scope, $windowStart, $windowStart + $window * 3]
        );

        if (!$ok) {
            // 限流表不可用时选择放行，避免因为统计设施故障导致接口整体不可用
            return ['allowed' => true, 'remaining' => $limit, 'limit' => $limit, 'reset' => $windowStart + $window];
        }

        $hits = (int) Db::value('SELECT hits FROM rate_buckets WHERE bucket_key = ?', [$key], 0);
        self::maybeCleanup();

        return [
            'allowed'   => $hits <= $limit,
            'remaining' => max(0, $limit - $hits),
            'limit'     => $limit,
            'reset'     => $windowStart + $window,
        ];
    }

    /** 低概率触发清理，避免每次都跑 DELETE */
    private static function maybeCleanup(): void
    {
        if (random_int(1, 200) !== 1) {
            return;
        }
        $now = time();
        Db::tryExec('DELETE FROM rate_buckets WHERE expires_at < ?', [$now]);
        Db::tryExec('DELETE FROM api_nonces WHERE expires_at < ?', [$now]);
    }

    /** 手动清理（后台「维护」用） */
    public static function purge(): array
    {
        $now = time();
        return [
            'rate_buckets' => Db::exec('DELETE FROM rate_buckets WHERE expires_at < ?', [$now]),
            'api_nonces'   => Db::exec('DELETE FROM api_nonces WHERE expires_at < ?', [$now]),
        ];
    }
}
