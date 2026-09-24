<?php
namespace Wid\Model;

use Wid\Core\Db;
use Wid\Core\Http;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 用户反馈与崩溃上报。
 *
 * 这两类数据都是"外部输入"，必须当作不可信内容处理：
 * 长度硬截断 + 只存纯文本（后台渲染时统一转义），避免存储型 XSS。
 */
final class Feedback
{
    const CATEGORIES = ['bug', 'suggestion', 'question', 'other'];

    public static function submit(int $appId, ?int $devicePk, array $data): int
    {
        $category = in_array($data['category'] ?? '', self::CATEGORIES, true) ? $data['category'] : 'other';
        $content = mb_substr(trim((string) ($data['content'] ?? '')), 0, 2000, 'UTF-8');
        if ($content === '') {
            throw new \InvalidArgumentException('反馈内容不能为空');
        }
        Db::exec(
            'INSERT INTO feedback (app_id, device_pk, device_id, category, contact, content,
                client_version, platform, os_version, ip, status, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, NOW(), NOW())',
            [
                $appId,
                $devicePk,
                mb_substr((string) ($data['device_id'] ?? ''), 0, 64, 'UTF-8'),
                $category,
                mb_substr(trim((string) ($data['contact'] ?? '')), 0, 120, 'UTF-8'),
                $content,
                mb_substr((string) ($data['client_version'] ?? ''), 0, 24, 'UTF-8'),
                platform_norm($data['platform'] ?? ''),
                mb_substr((string) ($data['os_version'] ?? ''), 0, 32, 'UTF-8'),
                Http::ipBin(Http::ip()),
            ]
        );
        return Db::lastId();
    }

    public static function list(int $limit = 50, int $offset = 0, ?int $status = null): array
    {
        $limit = max(1, min(200, $limit));
        $where = '1 = 1';
        $params = [];
        if ($status !== null) {
            $where .= ' AND status = ?';
            $params[] = $status;
        }
        $rows = Db::all(
            'SELECT f.*, d.nickname FROM feedback f LEFT JOIN devices d ON d.id = f.device_pk
             WHERE ' . $where . ' ORDER BY f.id DESC LIMIT ' . $limit . ' OFFSET ' . max(0, $offset),
            $params
        );
        foreach ($rows as &$row) {
            $row['ip_text'] = Http::ipText($row['ip']);
            unset($row['ip']);
        }
        return $rows;
    }

    public static function pendingCount(): int
    {
        return (int) Db::value('SELECT COUNT(*) FROM feedback WHERE status = 0', [], 0);
    }

    public static function mark(int $id, int $status, string $reply = ''): bool
    {
        return Db::exec(
            'UPDATE feedback SET status = ?, reply = ?, updated_at = NOW() WHERE id = ?',
            [max(0, min(2, $status)), mb_substr($reply, 0, 2000, 'UTF-8'), $id]
        ) >= 0;
    }

    public static function remove(int $id): bool
    {
        return Db::exec('DELETE FROM feedback WHERE id = ?', [$id]) > 0;
    }

    // ============ 崩溃上报 ============

    /** 同一设备同一错误在 10 分钟内只记一条，避免崩溃循环把表刷爆 */
    public static function reportCrash(int $appId, ?int $devicePk, array $data): array
    {
        $deviceId = mb_substr((string) ($data['device_id'] ?? ''), 0, 64, 'UTF-8');
        $errorType = mb_substr(trim((string) ($data['error_type'] ?? 'unknown')), 0, 64, 'UTF-8');
        $fingerprint = sha1($deviceId . '|' . $errorType . '|' . mb_substr((string) ($data['message'] ?? ''), 0, 120, 'UTF-8'));

        $recent = Db::one(
            'SELECT id, occur_count FROM crash_reports WHERE fingerprint = ? AND created_at > DATE_SUB(NOW(), INTERVAL 10 MINUTE) LIMIT 1',
            [$fingerprint]
        );
        if ($recent) {
            Db::tryExec('UPDATE crash_reports SET occur_count = occur_count + 1, last_at = NOW() WHERE id = ?', [(int) $recent['id']]);
            return ['dedup' => true, 'id' => (int) $recent['id'], 'occur_count' => (int) $recent['occur_count'] + 1];
        }

        Db::exec(
            'INSERT INTO crash_reports (app_id, device_pk, device_id, fingerprint, error_type, message, detail,
                client_version, platform, os_version, ip, occur_count, created_at, last_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW(), NOW())',
            [
                $appId,
                $devicePk,
                $deviceId,
                $fingerprint,
                $errorType,
                mb_substr((string) ($data['message'] ?? ''), 0, 255, 'UTF-8'),
                mb_substr((string) ($data['detail'] ?? ''), 0, 16000, 'UTF-8'),
                mb_substr((string) ($data['client_version'] ?? ''), 0, 24, 'UTF-8'),
                platform_norm($data['platform'] ?? ''),
                mb_substr((string) ($data['os_version'] ?? ''), 0, 32, 'UTF-8'),
                Http::ipBin(Http::ip()),
            ]
        );
        return ['dedup' => false, 'id' => Db::lastId(), 'occur_count' => 1];
    }

    public static function crashList(int $limit = 50, int $offset = 0): array
    {
        $limit = max(1, min(200, $limit));
        $rows = Db::all(
            'SELECT id, device_id, error_type, message, client_version, platform, os_version,
                    occur_count, created_at, last_at
             FROM crash_reports ORDER BY last_at DESC LIMIT ' . $limit . ' OFFSET ' . max(0, $offset)
        );
        return $rows;
    }

    public static function crashCount(): int
    {
        return (int) Db::value('SELECT COUNT(*) FROM crash_reports', [], 0);
    }

    public static function purgeCrash(int $days = 60): int
    {
        // INTERVAL 的占位符在部分 MySQL 版本上会被拒绝，这里强制转成整数内联
        $days = max(1, min(3650, $days));
        return Db::exec('DELETE FROM crash_reports WHERE last_at < DATE_SUB(NOW(), INTERVAL ' . $days . ' DAY)');
    }
}
