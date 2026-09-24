<?php
namespace Wid\Model;

use Wid\Core\Db;
use Wid\Core\Http;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 在线会话。
 *
 * 在线人数不靠"启动 +1 / 退出 -1"（客户端崩溃或断网就永远扣不掉），
 * 而是用心跳 + 时间窗：最后一次心跳在 online_window 秒内的设备即视为在线。
 * 这样即使客户端强杀进程，也会在 2 分钟内自动掉线。
 */
final class Online
{
    /**
     * 记录一次心跳。
     *
     * @return bool 是否开启了一个新会话（用于事件日志与峰值统计）
     */
    public static function beat(int $appId, int $devicePk, string $sessionId, string $platform): bool
    {
        $now = time();
        $prev = Db::one(
            'SELECT session_id, started_at, last_beat_at FROM online_sessions WHERE device_pk = ?',
            [$devicePk]
        );
        $isNewSession = true;
        if ($prev) {
            $isNewSession = ($prev['session_id'] !== $sessionId)
                || ($now - (int) $prev['last_beat_at'] > (int) cfg('api.online_window', 120));
        }

        Db::tryExec(
            'INSERT INTO online_sessions (device_pk, app_id, session_id, platform, started_at, last_beat_at, ip)
             VALUES (?, ?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
                started_at   = IF(session_id <> VALUES(session_id), VALUES(started_at), started_at),
                session_id   = VALUES(session_id),
                platform     = VALUES(platform),
                last_beat_at = VALUES(last_beat_at),
                ip           = VALUES(ip)',
            [
                $devicePk,
                $appId,
                mb_substr($sessionId, 0, 64, 'UTF-8'),
                platform_norm($platform),
                $now,
                $now,
                Http::ipBin(Http::ip()),
            ]
        );

        self::refreshPeak($appId);
        return $isNewSession;
    }

    /** 当前在线数（时间窗内的会话数） */
    public static function countNow(): int
    {
        $window = (int) cfg('api.online_window', 120);
        return (int) Db::value(
            'SELECT COUNT(*) FROM online_sessions WHERE last_beat_at > ?',
            [time() - $window],
            0
        );
    }

    public static function countByPlatform(): array
    {
        $window = (int) cfg('api.online_window', 120);
        return Db::all(
            'SELECT platform, COUNT(*) AS online FROM online_sessions WHERE last_beat_at > ? GROUP BY platform ORDER BY online DESC',
            [time() - $window]
        );
    }

    /** 主动下线 */
    public static function forget(int $devicePk): bool
    {
        return Db::exec('DELETE FROM online_sessions WHERE device_pk = ?', [$devicePk]) > 0;
    }

    /** 清理超时会话，返回清理条数 */
    public static function purge(): int
    {
        $window = (int) cfg('api.online_window', 120);
        return Db::exec('DELETE FROM online_sessions WHERE last_beat_at < ?', [time() - $window * 10]);
    }

    /** 刷新在线峰值（每次心跳都可能触发，用一次 UPDATE 完成判断） */
    private static function refreshPeak(int $appId): void
    {
        $online = self::countNow();
        Db::tryExec(
            'UPDATE global_stats
             SET online_peak = GREATEST(online_peak, ?), updated_at = NOW()
             WHERE app_id = ? AND online_peak < ?',
            [$online, $appId, $online]
        );
    }
}
