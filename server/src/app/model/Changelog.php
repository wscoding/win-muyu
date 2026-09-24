<?php
namespace Wid\Model;

use Wid\Core\Db;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 更新日志。与版本发布表分开的原因：一个版本可能要发多条日志
 * （新增/修复/优化分组），而版本发布记录是"能下载什么"的技术事实。
 */
final class Changelog
{
    const KINDS = ['feature', 'fix', 'improve', 'notice', 'breaking'];

    public static function forPublic(int $appId, ?string $platform = null, int $limit = 20): array
    {
        $limit = max(1, min(100, $limit));
        $where = ['published = 1'];
        $params = [];
        if ($appId > 0) {
            $where[] = '(app_id = ? OR app_id = 0)';
            $params[] = $appId;
        }
        if ($platform !== null && $platform !== '') {
            $p = platform_norm($platform);
            $where[] = '(platform = ? OR platform = \'all\')';
            $params[] = $p;
        }
        return Db::all(
            'SELECT id, version, platform, channel, kind, title, body, released_at
             FROM changelog_entries
             WHERE ' . implode(' AND ', $where) . '
             ORDER BY released_at DESC, sort_weight DESC, id DESC
             LIMIT ' . $limit,
            $params
        );
    }

    public static function all(int $limit = 100, int $offset = 0): array
    {
        $limit = max(1, min(200, $limit));
        return Db::all(
            'SELECT * FROM changelog_entries ORDER BY released_at DESC, id DESC LIMIT ' . $limit . ' OFFSET ' . max(0, $offset)
        );
    }

    public static function count(): int
    {
        return (int) Db::value('SELECT COUNT(*) FROM changelog_entries', [], 0);
    }

    public static function find(int $id): ?array
    {
        return Db::one('SELECT * FROM changelog_entries WHERE id = ? LIMIT 1', [$id]);
    }

    public static function save(int $appId, array $data, ?int $id = null): int
    {
        $kind = in_array($data['kind'] ?? '', self::KINDS, true) ? $data['kind'] : 'feature';
        $fields = [
            'app_id'      => $appId,
            'release_id'  => !empty($data['release_id']) ? (int) $data['release_id'] : null,
            'version'     => mb_substr(trim((string) ($data['version'] ?? '')), 0, 24, 'UTF-8'),
            'platform'    => (($data['platform'] ?? 'all') === 'all') ? 'all' : platform_norm($data['platform']),
            'channel'     => in_array($data['channel'] ?? 'release', Release::CHANNELS, true) ? $data['channel'] : 'release',
            'kind'        => $kind,
            'title'       => mb_substr(trim((string) ($data['title'] ?? '')), 0, 128, 'UTF-8'),
            'body'        => (string) ($data['body'] ?? ''),
            'released_at' => self::normDate($data['released_at'] ?? null) ?: date('Y-m-d'),
            'published'   => isset($data['published']) ? (!empty($data['published']) ? 1 : 0) : 1,
            'sort_weight' => (int) ($data['sort_weight'] ?? 0),
        ];

        if ($fields['title'] === '') {
            throw new \InvalidArgumentException('日志标题不能为空');
        }

        if ($id === null) {
            Db::exec(
                'INSERT INTO changelog_entries
                    (app_id, release_id, version, platform, channel, kind, title, body, released_at, published, sort_weight, created_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())',
                array_values($fields)
            );
            return Db::lastId();
        }

        $sets = [];
        $params = [];
        foreach ($fields as $key => $value) {
            $sets[] = '`' . $key . '` = ?';
            $params[] = $value;
        }
        $params[] = $id;
        Db::exec('UPDATE changelog_entries SET ' . implode(', ', $sets) . ' WHERE id = ?', $params);
        return $id;
    }

    public static function remove(int $id): bool
    {
        return Db::exec('DELETE FROM changelog_entries WHERE id = ?', [$id]) > 0;
    }

    private static function normDate($value): ?string
    {
        if (!$value) {
            return null;
        }
        $ts = strtotime((string) $value);
        return $ts === false ? null : date('Y-m-d', $ts);
    }
}
