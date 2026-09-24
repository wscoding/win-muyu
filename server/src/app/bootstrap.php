<?php
/**
 * 站点引导：常量、配置、自动加载、异常兜底、公共函数。
 *
 * 所有入口文件（站点页面 / api 前端控制器 / admin）都先 require 本文件。
 * 约定：任何被 web 直接访问的 PHP 都要先定义 WID_APP，库文件被直接请求时
 * 会因缺少常量而静默退出，避免源码泄露。
 */
if (!defined('WID_APP')) {
    define('WID_APP', 1);
}
define('WID_APP_DIR', __DIR__);                       // .../app
define('WID_ROOT', dirname(__DIR__));                 // 站点根 /www/wwwroot/wid.chr.cc
define('WID_START', microtime(true));

/**
 * 静态资源版本号。改完 css/js 后 bump 它，即可击穿浏览器与 Cloudflare 缓存。
 * 放在 bootstrap 里是为了让前台页面与后台页面共用同一个版本号。
 */
if (!defined('WID_ASSET_VER')) {
    define('WID_ASSET_VER', '20260923a');
}

require_once WID_APP_DIR . '/core/Support.php';

// ---- 自动加载：Wid\Core\Db -> app/core/Db.php ----
spl_autoload_register(static function ($class) {
    $prefix = 'Wid\\';
    if (strncmp($class, $prefix, strlen($prefix)) !== 0) {
        return;
    }
    $rel = str_replace('\\', '/', substr($class, strlen($prefix)));
    $file = WID_APP_DIR . '/' . strtolower(dirname($rel)) . '/' . basename($rel) . '.php';
    if (is_file($file)) {
        require_once $file;
    }
});

// ---- 配置 ----
$GLOBALS['WID_CONFIG'] = null;

function wid_config(): array
{
    if ($GLOBALS['WID_CONFIG'] === null) {
        $file = WID_APP_DIR . '/config.php';
        if (!is_file($file)) {
            $file = WID_APP_DIR . '/config.dist.php';
        }
        $cfg = require $file;
        $GLOBALS['WID_CONFIG'] = is_array($cfg) ? $cfg : [];
    }
    return $GLOBALS['WID_CONFIG'];
}

function cfg(string $path, $default = null)
{
    $node = wid_config();
    foreach (explode('.', $path) as $seg) {
        if (!is_array($node) || !array_key_exists($seg, $node)) {
            return $default;
        }
        $node = $node[$seg];
    }
    return $node;
}

// 时区必须在使用任何 date() 之前设置
date_default_timezone_set((string) cfg('site.timezone', 'Asia/Shanghai'));

// ---- 错误处理 ----
$widIsApi = (strncmp($_SERVER['REQUEST_URI'] ?? '', '/api/', 5) === 0)
    || (strpos($_SERVER['SCRIPT_NAME'] ?? '', '/api/') !== false);

error_reporting(E_ALL);
ini_set('display_errors', '0');
ini_set('log_errors', '1');
$logDir = WID_APP_DIR . '/log';
if (!is_dir($logDir)) {
    @mkdir($logDir, 0755, true);
}
ini_set('error_log', $logDir . '/php-error.log');

set_exception_handler(static function ($e) use ($widIsApi) {
    \Wid\Core\Event::exception($e);
    if ($widIsApi) {
        \Wid\Core\Respond::fail(
            \Wid\Core\Respond::E_SERVER,
            '服务暂时不可用，请稍后重试',
            500,
            cfg('api.debug') ? ['exception' => get_class($e), 'message' => $e->getMessage()] : null
        );
    } else {
        http_response_code(500);
        header('Content-Type: text/html; charset=utf-8');
        echo '<!doctype html><meta charset="utf-8"><title>500</title>'
            . '<div style="font:16px/1.8 -apple-system,Segoe UI,sans-serif;max-width:520px;margin:18vh auto;color:#e8e8ea">'
            . '<h1 style="font-size:22px">服务暂时不可用</h1>'
            . '<p style="color:#9aa0a6">页面渲染出错，已记录日志。请稍后刷新重试。</p>'
            . '<p><a style="color:#7fd1ae" href="/">返回首页</a></p></div>';
    }
    exit;
});
