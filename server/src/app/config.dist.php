<?php
/**
 * 站点配置模板。
 *
 * 部署脚本 Scripts/deploy_wid_site.py 会把它复制为 app/config.php，
 * 并注入数据库口令、后台口令哈希与会话密钥。
 *
 * 该文件位于 /www/wwwroot/wid.chr.cc/app/ 下，nginx 已对 /app/ 整体封禁
 * 外部访问（见 /www/server/panel/vhost/nginx/extension/wid.chr.cc/deny_internal.conf），
 * 因此配置不会通过 HTTP 泄露。
 */
if (!defined('WID_APP')) {
    exit('forbidden');
}

return [
    // ---- 数据库 ----
    'db' => [
        'host'    => '127.0.0.1',
        'port'    => 3306,
        'name'    => 'wid',
        'user'    => 'wid',
        'pass'    => '__DB_PASS__',
        'charset' => 'utf8mb4',
    ],

    // ---- 站点信息 ----
    'site' => [
        'name'     => 'Prue Widgets',
        'subtitle' => '桌面电子木鱼 · 摸鱼小部件',
        'base_url' => 'https://wid.chr.cc',
        'timezone' => 'Asia/Shanghai',
        'icp'      => '',
    ],

    // ---- 管理后台 ----
    'admin' => [
        // password_hash('...', PASSWORD_DEFAULT) 的结果
        'password_hash'  => '__ADMIN_PW_HASH__',
        // 会话 Cookie 签名密钥（随机 64 位十六进制）
        'session_secret' => '__SESSION_SECRET__',
        'session_ttl'    => 43200,
        'cookie_name'    => 'wid_admin',
        'login_fail_limit' => 8,
    ],

    // ---- 接口 ----
    'api' => [
        // 签名时间戳允许的时钟偏移（秒）
        'ts_window'        => 300,
        // 防重放 nonce 保留时长（秒）
        'nonce_ttl'        => 600,
        // 公开只读接口的单 IP 每分钟上限
        'ip_rate_per_min'  => 240,
        // 超过该秒数未收到心跳即视为离线
        'online_window'    => 120,
        // 单次敲击批量上报的最大增量，超出即判为异常数据
        'tap_delta_max'    => 20000,
        // 公开接口响应缓存秒数
        'public_cache'     => 30,
        // 打开后会向响应体附加调试信息（生产保持 false）
        'debug'            => false,
    ],
];
