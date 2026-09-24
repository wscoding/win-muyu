<?php
namespace Wid\Api;

use Wid\Core\Event;
use Wid\Core\Http;
use Wid\Core\Respond;

if (!defined('WID_APP')) {
    exit('forbidden');
}

/**
 * 接口路由表。
 *
 * 所有路由集中在这一处声明，字段含义：
 *   [HTTP 方法, 正则, 处理器, 是否要求签名, 公开缓存的秒数]
 *
 * 写接口一律要求签名；公开只读接口允许匿名（只按 IP 限流），
 * 但客户端若带了签名就照样校验，方便端上统一加签。
 */
final class Router
{
    /** @var array<int, array{0:string,1:string,2:array,3:bool,4:int}> */
    private static function routes(): array
    {
        $cache = (int) cfg('api.public_cache', 30);
        return [
            // ---- 健康检查 ----
            ['GET',  '#^/v1/health$#',                        [MiscApi::class, 'health'],          false, 0],

            // ---- 生命周期 ----
            ['POST', '#^/v1/launch$#',                        [Lifecycle::class, 'launch'],        true,  0],
            ['POST', '#^/v1/heartbeat$#',                     [Lifecycle::class, 'heartbeat'],     true,  0],
            ['POST', '#^/v1/offline$#',                       [Lifecycle::class, 'offline'],       true,  0],

            // ---- 敲击统计 ----
            ['POST', '#^/v1/taps$#',                          [Taps::class, 'handle'],             true,  0],
            ['POST', '#^/v1/taps/batch$#',                    [Taps::class, 'batch'],              true,  0],

            // ---- 版本与更新 ----
            ['GET',  '#^/v1/version$#',                       [ReleaseApi::class, 'version'],      false, $cache],
            ['GET',  '#^/v1/changelog$#',                     [ReleaseApi::class, 'changelog'],    false, $cache],
            ['GET',  '#^/v1/downloads$#',                     [ReleaseApi::class, 'downloads'],    false, $cache],

            // ---- 统计看板 ----
            ['GET',  '#^/v1/stats/overview$#',                [StatsApi::class, 'overview'],       false, $cache],
            ['GET',  '#^/v1/stats/summary$#',                 [StatsApi::class, 'summary'],        false, $cache],
            ['GET',  '#^/v1/stats/trend$#',                   [StatsApi::class, 'trend'],          false, $cache],
            ['GET',  '#^/v1/stats/breakdown$#',               [StatsApi::class, 'breakdown'],      false, $cache],
            ['GET',  '#^/v1/leaderboard$#',                   [StatsApi::class, 'leaderboard'],    false, $cache],
            ['GET',  '#^/v1/profile$#',                       [StatsApi::class, 'profile'],        false, $cache],

            // ---- 内容与配置 ----
            ['GET',  '#^/v1/blessing$#',                      [ContentApi::class, 'blessing'],     false, 0],
            ['GET',  '#^/v1/announcement$#',                  [ContentApi::class, 'announcement'], false, $cache],
            ['GET',  '#^/v1/config$#',                        [ContentApi::class, 'config'],       false, $cache],
            ['GET',  '#^/v1/assets$#',                        [ContentApi::class, 'assets'],       false, $cache],

            // ---- 上报与同步 ----
            ['POST', '#^/v1/feedback$#',                      [MiscApi::class, 'feedback'],        true,  0],
            ['POST', '#^/v1/crash$#',                         [MiscApi::class, 'crash'],           true,  0],
            ['POST', '#^/v1/settings/pull$#',                 [MiscApi::class, 'settingsPull'],    true,  0],
            ['POST', '#^/v1/settings/push$#',                 [MiscApi::class, 'settingsPush'],    true,  0],
            ['POST', '#^/v1/profile/opt-in$#',                [StatsApi::class, 'optIn'],          true,  0],
        ];
    }

    public static function dispatch(): void
    {
        $method = Http::method();
        $path = Http::path();

        if ($method === 'OPTIONS') {
            Respond::cors();
            http_response_code(204);
            exit;
        }

        foreach (self::routes() as $route) {
            list($routeMethod, $pattern, $handler, $needSign, $cacheSeconds) = $route;
            if ($routeMethod !== $method) {
                continue;
            }
            if (!preg_match($pattern, $path)) {
                continue;
            }
            if ($cacheSeconds > 0) {
                Respond::cors();
            }
            try {
                $ctx = ['app' => null];
                if ($needSign) {
                    $ctx = Base::guard(true);
                } elseif (Http::header('X-App-Key') !== '' || Http::header('X-Signature') !== '') {
                    // 公开接口也走一遍鉴权，带签名的请求同样受校验
                    $ctx = Base::guard(false);
                }
                call_user_func($handler, $ctx, $cacheSeconds);
            } catch (\InvalidArgumentException $e) {
                Respond::fail(Respond::E_PARAM, $e->getMessage(), 400);
            } catch (\Throwable $e) {
                Event::exception($e);
                Respond::fail(
                    Respond::E_SERVER,
                    '服务暂时不可用，请稍后重试',
                    500,
                    cfg('api.debug') ? ['exception' => get_class($e), 'message' => $e->getMessage()] : null
                );
            }
            return;
        }

        // 方法不匹配时给出更明确的提示
        foreach (self::routes() as $route) {
            if (preg_match($route[1], $path)) {
                header('Allow: ' . $route[0]);
                Respond::fail(Respond::E_PARAM, '该接口只接受 ' . $route[0] . ' 请求', 405);
            }
        }

        Respond::fail(Respond::E_NOTFOUND, '接口不存在：' . $path, 404);
    }
}
