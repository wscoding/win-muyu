<?php
namespace Wid\Core;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 事件 / 审计日志。
 *
 * 与业务表分开的原因：这类记录量小、写入频繁、且必须"写不进去也不能
 * 影响主流程"。所以所有方法都吞异常，只兜底写 error_log。
 */
final class Event
{
    public static function log(
        string $event,
        string $message = '',
        string $level = 'info',
        ?int $appId = null,
        string $actor = ''
    ): void {
        try {
            if (!Db::available()) {
                error_log('[wid] event(' . $level . ') ' . $event . ': ' . $message);
                return;
            }
            // 日志表最多保留 5 万行，靠后台维护任务或这里的机会式清理收口
            if (random_int(1, 300) === 1) {
                Db::tryExec('DELETE FROM event_log WHERE created_at < DATE_SUB(NOW(), INTERVAL 60 DAY)');
            }
            Db::tryExec(
                'INSERT INTO event_log (app_id, level, event, message, ip, actor, created_at)
                 VALUES (?, ?, ?, ?, ?, ?, NOW())',
                [
                    $appId,
                    mb_substr($level, 0, 8, 'UTF-8'),
                    mb_substr($event, 0, 48, 'UTF-8'),
                    mb_substr($message, 0, 255, 'UTF-8'),
                    Http::ipBin(Http::ip()),
                    mb_substr($actor, 0, 48, 'UTF-8'),
                ]
            );
        } catch (\Throwable $e) {
            error_log('[wid] event write failed: ' . $e->getMessage());
        }
    }

    /** 未捕获异常落库（bootstrap 的异常处理器调用） */
    public static function exception(\Throwable $e): void
    {
        $msg = get_class($e) . ': ' . $e->getMessage() . ' @ '
            . basename($e->getFile()) . ':' . $e->getLine();
        error_log('[wid] uncaught ' . $msg);
        self::log('exception', $msg, 'error');
    }

    public static function recent(int $limit = 50, int $offset = 0): array
    {
        $limit = max(1, min(200, $limit));
        $rows = Db::all(
            'SELECT id, app_id, level, event, message, ip, actor, created_at
             FROM event_log ORDER BY id DESC LIMIT ' . $limit . ' OFFSET ' . max(0, $offset)
        );
        // ip 是 VARBINARY(16)，直接塞进 JSON 会因「非法 UTF-8」让整个
        // json_encode 返回 false，接口响应体变成空字符串（实测踩过）。
        // 凡是从库里取出二进制列的接口，都必须在这里转成可读文本。
        foreach ($rows as &$row) {
            $row['ip_text'] = Http::ipText($row['ip']);
            unset($row['ip']);
        }
        return $rows;
    }

    public static function count(): int
    {
        return (int) Db::value('SELECT COUNT(*) FROM event_log', [], 0);
    }
}
