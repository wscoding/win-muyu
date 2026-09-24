<?php
namespace Wid\Api;

use Wid\Core\Http;
use Wid\Core\Respond;
use Wid\Model\Changelog;
use Wid\Model\Content;
use Wid\Model\Release;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 版本与更新检测。
 *
 * 客户端「检查更新」只需要一次请求：带上 platform / channel / current，
 * 服务端返回最新版本、更新幅度、是否强制，以及从当前版本起的更新日志。
 * 判定逻辑全部放在服务端，是为了让"强制升级"这种运营决策不发版就能生效。
 */
final class ReleaseApi
{
    /** GET /v1/version */
    public static function version(array $ctx, int $cacheSeconds = 0): void
    {
        $appId = Lifecycle::appIdOf($ctx);
        $platform = Http::str('platform', '', 16);
        $channel = Http::str('channel', 'release', 16);
        $channel = in_array($channel, Release::CHANNELS, true) ? $channel : 'release';
        $current = Http::str('current', '', 24);

        // 不指定平台：返回所有平台的最新版清单（下载页用）
        if ($platform === '') {
            $rows = Release::latestAll($appId);
            $list = [];
            foreach ($rows as $row) {
                $list[] = Release::toApi($row);
            }
            Respond::ok([
                'platforms'     => $list,
                'download_page' => rtrim((string) cfg('site.base_url'), '/') . '/download',
            ], 'ok', $cacheSeconds);
        }

        $normalized = platform_norm($platform);
        $row = Release::latest($appId, $normalized, $channel);
        if (!$row) {
            Respond::ok([
                'platform'   => $normalized,
                'channel'    => $channel,
                'current'    => $current,
                'latest'     => null,
                'has_update' => false,
                'update_type' => 'none',
                'force_upgrade' => false,
                'reason'     => 'no_release',
                'changelog'  => [],
            ], '该平台暂无发布记录', $cacheSeconds);
        }

        $latestVersion = (string) $row['version'];
        $hasUpdate = $current !== '' && version_compare_semver($current, $latestVersion) < 0;
        $updateType = $current !== '' ? \Semver::diff_type($current, $latestVersion) : 'unknown';

        // 强制升级的两条路径：显式 force_upgrade，或当前版本低于最低支持版本
        $force = (bool) $row['force_upgrade'];
        $reason = $force ? 'force_upgrade' : '';
        $minSupported = (string) $row['min_supported_version'];
        if (!$force && $current !== '' && $minSupported !== ''
            && version_compare_semver($current, $minSupported) < 0) {
            $force = true;
            $reason = 'below_min_supported';
        }

        Respond::ok([
            'platform'      => $normalized,
            'channel'       => $channel,
            'current'       => $current,
            'latest'        => Release::toApi($row),
            'has_update'    => $hasUpdate,
            'update_type'   => $updateType,
            'force_upgrade' => $force,
            'reason'        => $reason,
            'upgrade_tip'   => self::tip($hasUpdate, $force, $updateType, $latestVersion),
            'changelog'     => Changelog::forPublic($appId, $normalized, 5),
            'announcements' => Content::announcements($normalized, $current, 2),
            'download_page' => rtrim((string) cfg('site.base_url'), '/') . '/download',
        ], 'ok', $cacheSeconds);
    }

    /** GET /v1/changelog */
    public static function changelog(array $ctx, int $cacheSeconds = 0): void
    {
        $appId = Lifecycle::appIdOf($ctx);
        $limit = Http::int('limit', 20);
        $platform = Http::str('platform', '', 16);
        $version = Http::str('version', '', 24);

        $items = Changelog::forPublic($appId, $platform !== '' ? $platform : null, $limit);
        if ($version !== '') {
            $items = array_values(array_filter($items, static function ($item) use ($version) {
                return $item['version'] === $version;
            }));
        }

        Respond::ok([
            'total' => Changelog::count(),
            'items' => $items,
        ], 'ok', $cacheSeconds);
    }

    /** GET /v1/downloads —— 下载页用的全平台清单（含 beta 通道） */
    public static function downloads(array $ctx, int $cacheSeconds = 0): void
    {
        $appId = Lifecycle::appIdOf($ctx);
        $rows = Release::latestAll($appId);
        $grouped = [];
        foreach ($rows as $row) {
            $api = Release::toApi($row);
            $grouped[$api['platform']][$api['channel']] = $api;
        }
        Respond::ok([
            'platforms' => $grouped,
            'page'      => rtrim((string) cfg('site.base_url'), '/') . '/download',
        ], 'ok', $cacheSeconds);
    }

    private static function tip(bool $hasUpdate, bool $force, string $type, string $latest): string
    {
        if (!$hasUpdate) {
            return '已是最新版本';
        }
        $label = ['major' => '大版本更新', 'minor' => '功能更新', 'patch' => '修复更新'][$type] ?? '新版本';
        if ($force) {
            return '发现' . $label . ' v' . $latest . '，本次为必要更新，请尽快升级';
        }
        return '发现' . $label . ' v' . $latest . '，建议升级体验';
    }
}
