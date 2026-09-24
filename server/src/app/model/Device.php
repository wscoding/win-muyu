<?php
namespace Wid\Model;

use Wid\Core\Db;
use Wid\Core\Http;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 设备（客户端实例）。
 *
 * 隐私立场：device_id 由客户端本地随机生成并持久化，**不是**硬件指纹 ——
 * 服务端不采集任何可回溯到真人的信息，只按匿名标识做去重与累计。
 * 这与 docs/backend-api.md 第 5 条改进方向（区分匿名统计与用户数据）一致。
 */
final class Device
{
    /** 设备标识格式：8–64 位十六进制/字母数字，避免被塞入畸形内容 */
    const ID_PATTERN = '/^[A-Za-z0-9_-]{8,64}$/';

    public static function isValidId(string $id): bool
    {
        return (bool) preg_match(self::ID_PATTERN, $id);
    }

    /**
     * 启动上报时写入 / 更新设备行。返回设备行数组。
     */
    public static function touch(int $appId, string $deviceId, array $meta): array
    {
        $now = date('Y-m-d H:i:s');
        Db::exec(
            'INSERT INTO devices
                (app_id, device_id, platform, os_version, client_version, channel, color,
                 launch_count, tap_total, merit_total, session_count,
                 first_seen_at, last_seen_at, last_ip, status, note)
             VALUES (?, ?, ?, ?, ?, ?, ?, 1, 0, 0, 1, ?, ?, ?, 1, \'\')
             ON DUPLICATE KEY UPDATE
                launch_count  = launch_count + 1,
                session_count = session_count + 1,
                last_seen_at  = VALUES(last_seen_at),
                last_ip       = VALUES(last_ip),
                platform      = IF(VALUES(platform) <> \'\', VALUES(platform), platform),
                os_version    = IF(VALUES(os_version) <> \'\', VALUES(os_version), os_version),
                client_version= IF(VALUES(client_version) <> \'\', VALUES(client_version), client_version),
                channel       = IF(VALUES(channel) <> \'\', VALUES(channel), channel),
                color         = IF(VALUES(color) <> \'\', VALUES(color), color)',
            [
                $appId,
                $deviceId,
                platform_norm($meta['platform'] ?? ''),
                mb_substr((string) ($meta['os_version'] ?? ''), 0, 32, 'UTF-8'),
                mb_substr((string) ($meta['client_version'] ?? ''), 0, 24, 'UTF-8'),
                mb_substr((string) ($meta['channel'] ?? ''), 0, 16, 'UTF-8'),
                mb_substr((string) ($meta['color'] ?? ''), 0, 8, 'UTF-8'),
                $now,
                $now,
                Http::ipBin(Http::ip()),
            ]
        );
        return self::find($appId, $deviceId) ?? [];
    }

    public static function find(int $appId, string $deviceId): ?array
    {
        return Db::one(
            'SELECT * FROM devices WHERE app_id = ? AND device_id = ? LIMIT 1',
            [$appId, $deviceId]
        );
    }

    public static function findByPk(int $pk): ?array
    {
        return Db::one('SELECT * FROM devices WHERE id = ? LIMIT 1', [$pk]);
    }

    /**
     * 按设备标识跨应用查找。
     *
     * 公开只读接口（如 /profile）没有 app_key，无从知道设备属于哪个应用；
     * device_id 本身是客户端随机生成的 16 字节十六进制串，作为查询凭据
     * 足够。写接口仍然走 find(appId, deviceId) 的强隔离路径。
     */
    public static function findAny(string $deviceId): ?array
    {
        return Db::one('SELECT * FROM devices WHERE device_id = ? LIMIT 1', [$deviceId]);
    }

    /** 心跳 / 敲击上报时刷新活跃时间（轻量，只更新必要列） */
    public static function seen(int $pk, string $clientVersion = ''): void
    {
        Db::tryExec(
            'UPDATE devices SET last_seen_at = NOW(), last_ip = ?, '
            . 'client_version = IF(? <> \'\', ?, client_version) WHERE id = ?',
            [Http::ipBin(Http::ip()), $clientVersion, $clientVersion, $pk]
        );
    }

    /** 累加敲击与功德总数（末次快照以客户端上报的累计值为准，这里存服务端累计增量） */
    public static function addTaps(int $pk, int $delta, int $meritDelta): void
    {
        Db::tryExec(
            'UPDATE devices SET tap_total = tap_total + ?, merit_total = merit_total + ?, last_seen_at = NOW() WHERE id = ?',
            [$delta, $meritDelta, $pk]
        );
    }

    /** 把客户端上报的累计值刷成设备快照（用于「我的功德」这类展示） */
    public static function setSnapshot(int $pk, int $tapTotal, int $meritTotal): void
    {
        Db::tryExec(
            'UPDATE devices SET snapshot_tap_total = ?, snapshot_merit_total = ? WHERE id = ?',
            [$tapTotal, $meritTotal, $pk]
        );
    }

    public static function setStatus(int $pk, int $status, string $note = ''): bool
    {
        return Db::exec(
            'UPDATE devices SET status = ?, note = ? WHERE id = ?',
            [$status ? 1 : 0, mb_substr($note, 0, 120, 'UTF-8'), $pk]
        ) >= 0;
    }

    public static function count(?int $appId = null): int
    {
        if ($appId === null) {
            return (int) Db::value('SELECT COUNT(*) FROM devices WHERE status = 1', [], 0);
        }
        return (int) Db::value('SELECT COUNT(*) FROM devices WHERE status = 1 AND app_id = ?', [$appId], 0);
    }

    /** 今日活跃设备数（来自 daily_active 的去重计数） */
    public static function activeToday(): int
    {
        return (int) Db::value(
            'SELECT COUNT(*) FROM daily_active WHERE stat_date = CURDATE()',
            [],
            0
        );
    }

    /**
     * 设备分页列表。$filter 支持 platform / client_version / status / keyword(device_id)。
     */
    public static function paginate(array $filter, int $page = 1, int $pageSize = 30): array
    {
        list($where, $params) = self::buildWhere($filter);
        $offset = max(0, ($page - 1) * $pageSize);
        $rows = Db::all(
            'SELECT d.*, a.app_key, a.name AS app_name
             FROM devices d LEFT JOIN apps a ON a.id = d.app_id
             WHERE ' . $where . '
             ORDER BY d.last_seen_at DESC
             LIMIT ' . (int) $pageSize . ' OFFSET ' . $offset,
            $params
        );
        foreach ($rows as &$row) {
            $row['last_ip_text'] = Http::ipText($row['last_ip']);
            unset($row['last_ip']);
        }
        return $rows;
    }

    public static function countFiltered(array $filter): int
    {
        list($where, $params) = self::buildWhere($filter);
        return (int) Db::value('SELECT COUNT(*) FROM devices WHERE ' . $where, $params, 0);
    }

    private static function buildWhere(array $filter): array
    {
        $where = ['1 = 1'];
        $params = [];
        if (!empty($filter['platform'])) {
            $where[] = 'platform = ?';
            $params[] = platform_norm($filter['platform']);
        }
        if (!empty($filter['client_version'])) {
            $where[] = 'client_version = ?';
            $params[] = $filter['client_version'];
        }
        if (isset($filter['status']) && $filter['status'] !== '' && $filter['status'] !== null) {
            $where[] = 'status = ?';
            $params[] = (int) $filter['status'];
        }
        if (!empty($filter['keyword'])) {
            $where[] = 'device_id LIKE ?';
            $params[] = '%' . str_replace(['%', '_'], ['\%', '\_'], $filter['keyword']) . '%';
        }
        return [implode(' AND ', $where), $params];
    }

    /** 平台分布（看板用，仅聚合数字） */
    public static function platformBreakdown(): array
    {
        return Db::all(
            'SELECT platform, COUNT(*) AS devices FROM devices WHERE status = 1 GROUP BY platform ORDER BY devices DESC'
        );
    }

    /** 客户端版本分布 */
    public static function versionBreakdown(int $limit = 8): array
    {
        return Db::all(
            'SELECT client_version AS version, COUNT(*) AS devices
             FROM devices WHERE status = 1 AND client_version <> \'\'
             GROUP BY client_version ORDER BY devices DESC LIMIT ' . (int) $limit
        );
    }

    /** 已知版本号（后台筛选下拉用） */
    public static function knownVersions(): array
    {
        return array_column(
            Db::all('SELECT DISTINCT client_version FROM devices WHERE client_version <> \'\' ORDER BY client_version DESC LIMIT 50'),
            'client_version'
        );
    }
}
