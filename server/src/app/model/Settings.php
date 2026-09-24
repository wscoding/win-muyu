<?php
namespace Wid\Model;

use Wid\Core\Db;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 设置云同步（单设备命名空间）。
 *
 * 现在没有账号体系，所以同步的粒度是「设备」——换机器就等于新命名空间。
 * 之所以仍然做这一层，是因为它把「设置项」和「存储位置」解耦了：
 * 将来接入账号后，只要把 namespace 从 device_pk 换成 account_id，
 * 客户端的接口调用一行都不用改（这正是先定接口的价值）。
 *
 * 冲突策略是乐观锁 + 明确回报：
 * - 客户端 pull 时拿到 revision；
 * - push 时带上 base_revision，若与服务器当前 revision 不一致，
 *   服务端不写入（避免覆盖别的设备刚改的内容），回 409 语义并把
 *   服务器版本一起返回，由客户端决定合并还是强制覆盖（force = true）。
 */
final class Settings
{
    /** 允许同步的键（白名单，避免把任意内容当配置传上来） */
    const ALLOWED_KEYS = [
        'themeColor', 'soundEnabled', 'volume', 'autoTapEnabled', 'autoTapInterval',
        'autoTapCount', 'showMeritPanel', 'meritTemplate', 'hotkeys', 'language',
        'launchAtStartup', 'localSoundPath', 'tapSoundPack', 'woodenFishSkin',
        'floatTipStyle', 'trayIconStyle', 'windowPosition', 'windowOpacity',
    ];

    public static function pull(int $devicePk): array
    {
        $row = Db::one('SELECT * FROM device_settings WHERE device_pk = ? LIMIT 1', [$devicePk]);
        if (!$row) {
            return ['revision' => 0, 'payload' => new \stdClass(), 'updated_at' => null];
        }
        $payload = json_decode((string) $row['payload'], true);
        return [
            'revision'   => (int) $row['revision'],
            'payload'    => is_array($payload) ? $payload : new \stdClass(),
            'updated_at' => $row['updated_at'],
        ];
    }

    /**
     * @return array{revision:int,conflict:bool,payload:mixed,updated_at:?string,accepted_keys:array}
     */
    public static function push(int $devicePk, int $appId, array $payload, int $baseRevision = 0, bool $force = false): array
    {
        // 只接受白名单键，且拒绝内嵌数组过深的可疑结构
        $clean = [];
        foreach ($payload as $key => $value) {
            if (!in_array($key, self::ALLOWED_KEYS, true)) {
                continue;
            }
            if (is_array($value) || is_scalar($value) || $value === null) {
                $clean[(string) $key] = $value;
            }
        }
        $encoded = json_encode($clean, JSON_UNESCAPED_UNICODE);

        $current = Db::one('SELECT revision, payload, updated_at FROM device_settings WHERE device_pk = ? LIMIT 1', [$devicePk]);
        $currentRevision = $current ? (int) $current['revision'] : 0;

        if ($current && !$force && $baseRevision < $currentRevision) {
            $serverPayload = json_decode((string) $current['payload'], true);
            return [
                'revision'    => $currentRevision,
                'conflict'    => true,
                'payload'     => is_array($serverPayload) ? $serverPayload : new \stdClass(),
                'updated_at'  => $current['updated_at'],
                'accepted_keys' => [],
            ];
        }

        $newRevision = $currentRevision + 1;
        if ($current) {
            Db::exec(
                'UPDATE device_settings SET payload = ?, revision = ?, updated_at = NOW() WHERE device_pk = ?',
                [$encoded, $newRevision, $devicePk]
            );
        } else {
            Db::exec(
                'INSERT INTO device_settings (device_pk, app_id, payload, revision, created_at, updated_at)
                 VALUES (?, ?, ?, ?, NOW(), NOW())',
                [$devicePk, $appId, $encoded, $newRevision]
            );
        }

        return [
            'revision'      => $newRevision,
            'conflict'      => false,
            'payload'       => $clean,
            'updated_at'    => date('Y-m-d H:i:s'),
            'accepted_keys' => array_keys($clean),
        ];
    }

    public static function removeFor(int $devicePk): bool
    {
        return Db::exec('DELETE FROM device_settings WHERE device_pk = ?', [$devicePk]) > 0;
    }

    public static function count(): int
    {
        return (int) Db::value('SELECT COUNT(*) FROM device_settings', [], 0);
    }
}
