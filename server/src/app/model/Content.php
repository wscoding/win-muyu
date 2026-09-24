<?php
namespace Wid\Model;

use Wid\Core\Db;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 内容类资源：功德语 / 公告 / 运行时配置 / 资源包。
 *
 * 放在一起是因为它们的形态完全一致 —— 都是"运营可改、客户端只读"的数据，
 * 后台共用一套增删改查，接口共用一套序列化。
 */
final class Content
{
    // ============ 功德语（每日一签） ============

    /**
     * 取当天给某设备的"一签"。
     *
     * 用 crc32(设备标识 + 日期) 取模实现"同一天同一设备结果稳定、
     * 不同设备不同、次日自动轮换"，不需要为每台设备存一行。
     */
    public static function blessingFor(string $deviceId, ?string $category = null): ?array
    {
        $where = ["status = 1"];
        $params = [];
        if ($category !== null && $category !== '') {
            $where[] = 'category = ?';
            $params[] = $category;
        }
        $total = (int) Db::value('SELECT COUNT(*) FROM blessings WHERE ' . implode(' AND ', $where), $params, 0);
        if ($total <= 0) {
            return null;
        }
        $seed = crc32($deviceId . '|' . date('Y-m-d'));
        $offset = $seed % $total;
        $row = Db::one(
            'SELECT id, category, content, source FROM blessings WHERE ' . implode(' AND ', $where)
            . ' ORDER BY id ASC LIMIT 1 OFFSET ' . $offset,
            $params
        );
        return $row ?: null;
    }

    /** 随机一条（客户端"再摇一签"用） */
    public static function randomBlessing(?string $category = null): ?array
    {
        $where = ['status = 1'];
        $params = [];
        if ($category !== null && $category !== '') {
            $where[] = 'category = ?';
            $params[] = $category;
        }
        return Db::one(
            'SELECT id, category, content, source FROM blessings WHERE ' . implode(' AND ', $where)
            . ' ORDER BY RAND() LIMIT 1',
            $params
        );
    }

    public static function blessings(int $limit = 200, int $offset = 0): array
    {
        $limit = max(1, min(500, $limit));
        return Db::all('SELECT * FROM blessings ORDER BY id DESC LIMIT ' . $limit . ' OFFSET ' . max(0, $offset));
    }

    public static function saveBlessing(array $data, ?int $id = null): int
    {
        $fields = [
            'category' => mb_substr(trim((string) ($data['category'] ?? 'zen')), 0, 24, 'UTF-8'),
            'content'  => mb_substr(trim((string) ($data['content'] ?? '')), 0, 255, 'UTF-8'),
            'source'   => mb_substr(trim((string) ($data['source'] ?? '')), 0, 64, 'UTF-8'),
            'weight'   => (int) ($data['weight'] ?? 1),
            'status'   => isset($data['status']) ? (!empty($data['status']) ? 1 : 0) : 1,
        ];
        if ($fields['content'] === '') {
            throw new \InvalidArgumentException('内容不能为空');
        }
        if ($id === null) {
            Db::exec(
                'INSERT INTO blessings (category, content, source, weight, status, created_at) VALUES (?, ?, ?, ?, ?, NOW())',
                array_values($fields)
            );
            return Db::lastId();
        }
        Db::exec(
            'UPDATE blessings SET category = ?, content = ?, source = ?, weight = ?, status = ? WHERE id = ?',
            array_merge(array_values($fields), [$id])
        );
        return $id;
    }

    public static function removeBlessing(int $id): bool
    {
        return Db::exec('DELETE FROM blessings WHERE id = ?', [$id]) > 0;
    }

    // ============ 公告 ============

    /** 当前对某平台 / 渠道 / 版本生效的公告 */
    public static function announcements(?string $platform = null, string $clientVersion = '', int $limit = 5): array
    {
        $now = date('Y-m-d H:i:s');
        $where = [
            'status = 1',
            '(start_at IS NULL OR start_at <= ?)',
            '(end_at IS NULL OR end_at >= ?)',
        ];
        $params = [$now, $now];
        if ($platform !== null && $platform !== '') {
            $where[] = "(platform = 'all' OR platform = ?)";
            $params[] = platform_norm($platform);
        }
        if ($clientVersion !== '') {
            // min_version <= 当前版本，或未设下限
            $where[] = "(min_version = '' OR min_version <= ?)";
            $params[] = $clientVersion;
            $where[] = "(max_version = '' OR ? <= max_version)";
            $params[] = $clientVersion;
        }
        return Db::all(
            'SELECT id, title, content, level, platform, created_at, start_at, end_at
             FROM announcements WHERE ' . implode(' AND ', $where)
            . ' ORDER BY level DESC, id DESC LIMIT ' . (int) $limit,
            $params
        );
    }

    public static function announcementList(int $limit = 100): array
    {
        return Db::all('SELECT * FROM announcements ORDER BY id DESC LIMIT ' . (int) $limit);
    }

    public static function saveAnnouncement(array $data, ?int $id = null): int
    {
        $fields = [
            'title'       => mb_substr(trim((string) ($data['title'] ?? '')), 0, 128, 'UTF-8'),
            'content'     => (string) ($data['content'] ?? ''),
            'level'       => in_array($data['level'] ?? 'info', ['info', 'notice', 'warn'], true) ? $data['level'] : 'info',
            'platform'    => (($data['platform'] ?? 'all') === 'all') ? 'all' : platform_norm($data['platform']),
            'min_version' => mb_substr(trim((string) ($data['min_version'] ?? '')), 0, 24, 'UTF-8'),
            'max_version' => mb_substr(trim((string) ($data['max_version'] ?? '')), 0, 24, 'UTF-8'),
            'start_at'    => self::normDateTime($data['start_at'] ?? null),
            'end_at'      => self::normDateTime($data['end_at'] ?? null),
            'status'      => isset($data['status']) ? (!empty($data['status']) ? 1 : 0) : 1,
        ];
        if ($fields['title'] === '') {
            throw new \InvalidArgumentException('公告标题不能为空');
        }
        if ($id === null) {
            Db::exec(
                'INSERT INTO announcements (title, content, level, platform, min_version, max_version, start_at, end_at, status, created_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())',
                array_values($fields)
            );
            return Db::lastId();
        }
        $sets = [];
        foreach (array_keys($fields) as $key) {
            $sets[] = '`' . $key . '` = ?';
        }
        Db::exec(
            'UPDATE announcements SET ' . implode(', ', $sets) . ' WHERE id = ?',
            array_merge(array_values($fields), [$id])
        );
        return $id;
    }

    public static function removeAnnouncement(int $id): bool
    {
        return Db::exec('DELETE FROM announcements WHERE id = ?', [$id]) > 0;
    }

    // ============ 运行时配置（下发给客户端） ============

    /**
     * 返回形如 ['key' => 值] 的扁平结构，值按 value_type 转型。
     * 端上只做"读配置"，不做本地默认值合并之外的事 —— 加一个开关
     * 不需要发版，这是这一层存在的全部意义。
     */
    public static function clientConfig(?string $platform = null): array
    {
        $rows = Db::all(
            'SELECT config_key, config_value, value_type FROM app_config WHERE status = 1 AND '
            . "(platform = 'all'" . ($platform !== '' && $platform !== null ? ' OR platform = ?' : '') . ')'
            . ' ORDER BY config_key ASC',
            ($platform !== '' && $platform !== null) ? [platform_norm($platform)] : []
        );
        $out = [];
        foreach ($rows as $row) {
            $out[$row['config_key']] = self::castValue($row['config_value'], $row['value_type']);
        }
        return $out;
    }

    public static function configList(): array
    {
        return Db::all('SELECT * FROM app_config ORDER BY config_key ASC');
    }

    public static function saveConfig(string $key, $value, string $type = 'string', string $platform = 'all', int $status = 1, string $desc = ''): bool
    {
        if ($type === 'bool') {
            $value = !empty($value) ? '1' : '0';
        } elseif ($type === 'json' && !is_string($value)) {
            $value = json_encode($value, JSON_UNESCAPED_UNICODE);
        }
        return Db::exec(
            'INSERT INTO app_config (config_key, config_value, value_type, platform, status, description, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, NOW())
             ON DUPLICATE KEY UPDATE config_value = VALUES(config_value), value_type = VALUES(value_type),
                platform = VALUES(platform), status = VALUES(status), description = VALUES(description), updated_at = NOW()',
            [
                mb_substr(trim($key), 0, 48, 'UTF-8'),
                is_string($value) ? $value : (string) $value,
                in_array($type, ['string', 'int', 'float', 'bool', 'json'], true) ? $type : 'string',
                $platform === 'all' ? 'all' : platform_norm($platform),
                $status ? 1 : 0,
                mb_substr($desc, 0, 255, 'UTF-8'),
            ]
        ) >= 0;
    }

    public static function removeConfig(string $key): bool
    {
        return Db::exec('DELETE FROM app_config WHERE config_key = ?', [$key]) > 0;
    }

    private static function castValue(string $value, string $type)
    {
        switch ($type) {
            case 'int':
                return (int) $value;
            case 'float':
                return (float) $value;
            case 'bool':
                return $value === '1' || strtolower($value) === 'true';
            case 'json':
                $decoded = json_decode($value, true);
                return $decoded === null ? [] : $decoded;
            default:
                return $value;
        }
    }

    // ============ 资源包（皮肤 / 音效包 / 字体） ============

    public static function assets(?string $platform = null, ?string $type = null): array
    {
        $where = ['status = 1'];
        $params = [];
        if ($platform !== null && $platform !== '') {
            $where[] = "(platform = 'all' OR platform = ?)";
            $params[] = platform_norm($platform);
        }
        if ($type !== null && $type !== '') {
            $where[] = 'type = ?';
            $params[] = $type;
        }
        return Db::all(
            'SELECT package_key, name, type, platform, version, download_url, file_size, file_hash, preview_url, description, published_at
             FROM asset_packages WHERE ' . implode(' AND ', $where) . '
             ORDER BY type ASC, name ASC',
            $params
        );
    }

    public static function assetList(int $limit = 200): array
    {
        return Db::all('SELECT * FROM asset_packages ORDER BY id DESC LIMIT ' . (int) $limit);
    }

    public static function saveAsset(array $data, ?int $id = null): int
    {
        $fields = [
            'package_key'  => mb_substr(trim((string) ($data['package_key'] ?? '')), 0, 48, 'UTF-8'),
            'name'         => mb_substr(trim((string) ($data['name'] ?? '')), 0, 64, 'UTF-8'),
            'type'         => in_array($data['type'] ?? 'skin', ['skin', 'sound', 'font'], true) ? $data['type'] : 'skin',
            'platform'     => (($data['platform'] ?? 'all') === 'all') ? 'all' : platform_norm($data['platform']),
            'version'      => mb_substr(trim((string) ($data['version'] ?? '1.0.0')), 0, 24, 'UTF-8'),
            'download_url' => mb_substr(trim((string) ($data['download_url'] ?? '')), 0, 255, 'UTF-8'),
            'file_size'    => isset($data['file_size']) && $data['file_size'] !== '' ? (int) $data['file_size'] : null,
            'file_hash'    => mb_substr(trim((string) ($data['file_hash'] ?? '')), 0, 128, 'UTF-8'),
            'preview_url'  => mb_substr(trim((string) ($data['preview_url'] ?? '')), 0, 255, 'UTF-8'),
            'description'  => mb_substr(trim((string) ($data['description'] ?? '')), 0, 255, 'UTF-8'),
            'status'       => isset($data['status']) ? (!empty($data['status']) ? 1 : 0) : 1,
        ];
        if ($fields['package_key'] === '') {
            throw new \InvalidArgumentException('资源包标识不能为空');
        }
        if ($id === null) {
            Db::exec(
                'INSERT INTO asset_packages
                    (package_key, name, type, platform, version, download_url, file_size, file_hash, preview_url, description, status, published_at, created_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
                 ON DUPLICATE KEY UPDATE name = VALUES(name), type = VALUES(type), platform = VALUES(platform),
                    version = VALUES(version), download_url = VALUES(download_url), file_size = VALUES(file_size),
                    file_hash = VALUES(file_hash), preview_url = VALUES(preview_url), description = VALUES(description),
                    status = VALUES(status)',
                array_values($fields)
            );
            return (int) Db::value('SELECT id FROM asset_packages WHERE package_key = ?', [$fields['package_key']], 0);
        }
        $sets = [];
        foreach (array_keys($fields) as $key) {
            $sets[] = '`' . $key . '` = ?';
        }
        Db::exec(
            'UPDATE asset_packages SET ' . implode(', ', $sets) . ' WHERE id = ?',
            array_merge(array_values($fields), [$id])
        );
        return $id;
    }

    public static function removeAsset(int $id): bool
    {
        return Db::exec('DELETE FROM asset_packages WHERE id = ?', [$id]) > 0;
    }

    private static function normDateTime($value): ?string
    {
        if (!$value) {
            return null;
        }
        $ts = strtotime((string) $value);
        return $ts === false ? null : date('Y-m-d H:i:s', $ts);
    }
}
