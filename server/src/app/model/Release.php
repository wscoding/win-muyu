<?php
namespace Wid\Model;

use Wid\Core\Db;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 版本发布表 —— App「检查更新」功能的数据源。
 *
 * 一个 (应用, 平台, 渠道) 组合下只有一行 is_latest = 1。
 * 后台「发布」动作会先把同组的 is_latest 全部清零，再置位目标行，
 * 所以客户端永远只会拉到一个确定的最新版本。
 *
 * 强制升级用两层判定：
 * - force_upgrade = 1：无论当前版本，一律提示更新；
 * - min_supported_version：当前版本低于该值时必须升级（用于淘汰旧协议）。
 */
final class Release
{
    const PLATFORMS = ['windows', 'macos', 'android', 'ios'];
    const CHANNELS = ['release', 'beta'];

    public static function latest(int $appId, string $platform, string $channel = 'release'): ?array
    {
        $platform = platform_norm($platform);
        $channel = in_array($channel, self::CHANNELS, true) ? $channel : 'release';
        return Db::one(
            'SELECT * FROM app_releases WHERE app_id = ? AND platform = ? AND channel = ? AND is_latest = 1 LIMIT 1',
            [$appId, $platform, $channel]
        );
    }

    /** 该平台下所有渠道的最新版（下载页一次拿全） */
    public static function latestAll(int $appId = 0): array
    {
        $sql = 'SELECT r.* FROM app_releases r
                INNER JOIN (
                    SELECT platform, channel, MAX(version) AS v
                    FROM app_releases WHERE is_latest = 1'
            . ($appId > 0 ? ' AND app_id = ' . (int) $appId : '')
            . ' GROUP BY platform, channel
                ) t ON t.platform = r.platform AND t.channel = r.channel AND t.v = r.version
                WHERE r.is_latest = 1
                ORDER BY FIELD(r.platform, \'windows\',\'macos\',\'android\',\'ios\'), r.channel';
        return Db::all($sql);
    }

    public static function find(int $id): ?array
    {
        return Db::one('SELECT * FROM app_releases WHERE id = ? LIMIT 1', [$id]);
    }

    public static function all(?string $platform = null, int $limit = 200): array
    {
        $limit = max(1, min(500, $limit));
        if ($platform !== null && $platform !== '') {
            return Db::all(
                'SELECT * FROM app_releases WHERE platform = ? ORDER BY published_at DESC, id DESC LIMIT ' . $limit,
                [platform_norm($platform)]
            );
        }
        return Db::all('SELECT * FROM app_releases ORDER BY published_at DESC, id DESC LIMIT ' . $limit);
    }

    /**
     * 新增或更新一条版本记录。返回记录 id。
     * $data 里未提供的字段保持原值（更新时）。
     */
    public static function save(int $appId, array $data, ?int $id = null): int
    {
        $now = date('Y-m-d H:i:s');
        $platform = platform_norm($data['platform'] ?? 'windows');
        $channel = in_array($data['channel'] ?? 'release', self::CHANNELS, true)
            ? $data['channel'] : 'release';

        $fields = [
            'platform'              => $platform,
            'channel'               => $channel,
            'version'               => mb_substr(trim((string) ($data['version'] ?? '')), 0, 24, 'UTF-8'),
            'build_number'          => mb_substr(trim((string) ($data['build_number'] ?? '')), 0, 24, 'UTF-8'),
            'build_signature'       => mb_substr(trim((string) ($data['build_signature'] ?? '')), 0, 64, 'UTF-8'),
            'appbuild'              => self::normalizeDate($data['appbuild'] ?? null),
            'installer_store'       => mb_substr(trim((string) ($data['installer_store'] ?? '')), 0, 64, 'UTF-8'),
            'newlog'                => (string) ($data['newlog'] ?? ''),
            'download_url'          => mb_substr(trim((string) ($data['download_url'] ?? '')), 0, 255, 'UTF-8'),
            'file_size'             => isset($data['file_size']) && $data['file_size'] !== '' ? (int) $data['file_size'] : null,
            'file_hash'             => mb_substr(trim((string) ($data['file_hash'] ?? '')), 0, 128, 'UTF-8'),
            'min_supported_version' => mb_substr(trim((string) ($data['min_supported_version'] ?? '')), 0, 24, 'UTF-8'),
            'force_upgrade'         => !empty($data['force_upgrade']) ? 1 : 0,
            'published_at'          => self::normalizeDateTime($data['published_at'] ?? null) ?: $now,
        ];

        if ($fields['version'] === '') {
            throw new \InvalidArgumentException('版本号不能为空');
        }

        if ($id === null) {
            Db::exec(
                'INSERT INTO app_releases
                    (app_id, platform, channel, version, build_number, build_signature, appbuild, installer_store,
                     newlog, download_url, file_size, file_hash, min_supported_version, force_upgrade,
                     is_latest, published_at, created_at, updated_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)',
                array_merge(
                    [$appId],
                    array_values($fields),
                    [$fields['published_at'], $now, $now]
                )
            );
            $id = Db::lastId();
        } else {
            $sets = [];
            $params = [];
            foreach ($fields as $key => $value) {
                $sets[] = '`' . $key . '` = ?';
                $params[] = $value;
            }
            $sets[] = 'updated_at = ?';
            $params[] = $now;
            $params[] = $id;
            Db::exec('UPDATE app_releases SET ' . implode(', ', $sets) . ' WHERE id = ?', $params);
        }

        // 如果该版本比当前 is_latest 的版本更高，自动接管"最新"
        $current = self::latest($appId, $platform, $channel);
        if (!$current || version_compare_semver((string) $current['version'], $fields['version']) < 0) {
            self::publish($id);
        }

        return (int) $id;
    }

    /** 设为该 (平台, 渠道) 下的最新版 */
    public static function publish(int $id): bool
    {
        $row = self::find($id);
        if (!$row) {
            return false;
        }
        Db::exec(
            'UPDATE app_releases SET is_latest = 0 WHERE app_id = ? AND platform = ? AND channel = ?',
            [(int) $row['app_id'], $row['platform'], $row['channel']]
        );
        Db::exec('UPDATE app_releases SET is_latest = 1, updated_at = NOW() WHERE id = ?', [$id]);
        return true;
    }

    public static function remove(int $id): bool
    {
        return Db::exec('DELETE FROM app_releases WHERE id = ?', [$id]) > 0;
    }

    /** 客户端上报的 distribution 渠道（installer_store 之类的展示字段） */
    public static function platformsWithRelease(int $appId): array
    {
        return Db::all(
            'SELECT platform, COUNT(*) AS releases, MAX(published_at) AS last_at
             FROM app_releases WHERE app_id = ? GROUP BY platform ORDER BY platform',
            [$appId]
        );
    }

    private static function normalizeDate($value): ?string
    {
        if (!$value) {
            return null;
        }
        $ts = strtotime((string) $value);
        return $ts === false ? null : date('Y-m-d', $ts);
    }

    private static function normalizeDateTime($value): ?string
    {
        if (!$value) {
            return null;
        }
        $ts = strtotime((string) $value);
        return $ts === false ? null : date('Y-m-d H:i:s', $ts);
    }

    /** 供接口输出：把库里的行整理成客户端友好的结构 */
    public static function toApi(?array $row): ?array
    {
        if (!$row) {
            return null;
        }
        return [
            'platform'              => $row['platform'],
            'channel'               => $row['channel'],
            'version'               => $row['version'],
            'build_number'          => $row['build_number'],
            'build_signature'       => $row['build_signature'],
            'appbuild'              => $row['appbuild'],
            'installer_store'       => $row['installer_store'],
            'newlog'                => $row['newlog'],
            'download_url'          => $row['download_url'],
            'file_size'             => $row['file_size'] === null ? null : (int) $row['file_size'],
            'file_hash'             => $row['file_hash'],
            'min_supported_version' => $row['min_supported_version'],
            'force_upgrade'         => (bool) $row['force_upgrade'],
            'published_at'          => $row['published_at'],
        ];
    }
}
