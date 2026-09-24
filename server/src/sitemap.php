<?php
/**
 * 站点地图。nginx 侧用 `location = /sitemap.xml { rewrite ^ /sitemap.php last; }`
 * 把 /sitemap.xml 映射到这里（见宝塔 extension 目录的 deny_internal.conf）。
 */
require_once __DIR__ . '/app/bootstrap.php';

$base = rtrim((string) cfg('site.base_url'), '/');
$urls = [
    ['loc' => '/', 'priority' => '1.0', 'freq' => 'daily'],
    ['loc' => '/dashboard', 'priority' => '0.9', 'freq' => 'hourly'],
    ['loc' => '/download', 'priority' => '0.9', 'freq' => 'weekly'],
    ['loc' => '/changelog', 'priority' => '0.7', 'freq' => 'weekly'],
    ['loc' => '/docs', 'priority' => '0.6', 'freq' => 'weekly'],
];
$lastmod = date('Y-m-d');

// 有更新日志时，用最新一条的日期作为 lastmod，让搜索引擎知道页面确实更新了
try {
    $logs = \Wid\Model\Changelog::forPublic(\Wid\Model\AppKey::defaultId(), null, 1);
    if ($logs && !empty($logs[0]['released_at'])) {
        $lastmod = date('Y-m-d', strtotime((string) $logs[0]['released_at']));
    }
} catch (\Throwable $e) {
    // 数据库不可用时沿用今天
}

header('Content-Type: application/xml; charset=utf-8');
header('Cache-Control: public, max-age=3600');
echo '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
<?php foreach ($urls as $url): ?>
  <url>
    <loc><?= e($base . $url['loc']) ?></loc>
    <lastmod><?= e($lastmod) ?></lastmod>
    <changefreq><?= e($url['freq']) ?></changefreq>
    <priority><?= e($url['priority']) ?></priority>
  </url>
<?php endforeach; ?>
</urlset>
