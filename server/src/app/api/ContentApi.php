<?php
namespace Wid\Api;

use Wid\Core\Http;
use Wid\Core\Respond;
use Wid\Model\Content;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 内容与运行时配置（公开只读）。
 *
 * 这一组接口的价值在于「不发版就能改行为」：
 * 公告、功德语文案、功能开关、皮肤与音效包清单都从这里下发。
 * 客户端只需要实现「读配置 → 覆盖本地默认值」这一条逻辑。
 */
final class ContentApi
{
    /** GET /v1/blessing?device_id=&category= */
    public static function blessing(array $ctx, int $cacheSeconds = 0): void
    {
        $deviceId = Http::str('device_id', '', 64);
        $category = Http::str('category', '', 24);
        $category = $category !== '' ? $category : null;

        // 带 device_id 时是「每日一签」（同一天结果稳定），否则随机
        $item = $deviceId !== ''
            ? Content::blessingFor($deviceId, $category)
            : Content::randomBlessing($category);

        if (!$item) {
            Respond::ok([
                'date'    => date('Y-m-d'),
                'content' => '功德自在人心，敲一敲便是修行。',
                'source'  => '内置',
                'fallback' => true,
            ], '内容库为空，返回内置兜底文案', 0);
        }

        Respond::ok([
            'date'     => date('Y-m-d'),
            'category' => $item['category'],
            'content'  => $item['content'],
            'source'   => $item['source'],
            'fallback' => false,
        ], 'ok', 0);
    }

    /** GET /v1/announcement?platform=&client_version= */
    public static function announcement(array $ctx, int $cacheSeconds = 0): void
    {
        $platform = Http::str('platform', '', 16);
        $version = Http::str('client_version', '', 24);
        Respond::ok([
            'items' => Content::announcements($platform !== '' ? $platform : null, $version, 5),
        ], 'ok', $cacheSeconds);
    }

    /** GET /v1/config?platform= */
    public static function config(array $ctx, int $cacheSeconds = 0): void
    {
        $platform = Http::str('platform', '', 16);
        Respond::ok([
            'platform' => $platform !== '' ? platform_norm($platform) : 'all',
            'config'   => Content::clientConfig($platform !== '' ? $platform : null),
        ], 'ok', $cacheSeconds);
    }

    /** GET /v1/assets?platform=&type=skin|sound|font */
    public static function assets(array $ctx, int $cacheSeconds = 0): void
    {
        $platform = Http::str('platform', '', 16);
        $type = Http::str('type', '', 12);
        Respond::ok([
            'items' => Content::assets(
                $platform !== '' ? $platform : null,
                $type !== '' ? $type : null
            ),
        ], 'ok', $cacheSeconds);
    }
}
