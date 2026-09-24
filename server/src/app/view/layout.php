<?php
/**
 * 页面外壳：head / 导航 / 页脚。
 *
 * 这一层刻意不依赖任何前端框架 —— 服务器只有 4G 内存、内存可用不足 1G，
 * 页面全部服务端渲染（首屏零请求、对 SEO 友好、断网也能看），
 * 只有实时数字用一小段原生 JS 做增量刷新。
 */
if (!defined('WID_APP')) {
    exit('forbidden');
}

require_once __DIR__ . '/components.php';

/** 站点资源版本号，改静态文件后 bump 它即可击穿缓存 */
if (!defined('WID_ASSET_VER')) {
    define('WID_ASSET_VER', '20260923a');
}

function wid_base_url(string $path = ''): string
{
    $base = rtrim((string) cfg('site.base_url', ''), '/');
    return $base . '/' . ltrim($path, '/');
}

/** 给静态资源拼上版本号 */
function wid_asset(string $path): string
{
    return '/assets/' . ltrim($path, '/') . '?v=' . WID_ASSET_VER;
}

function view_head(array $opts = []): void
{
    $title = $opts['title'] ?? cfg('site.name');
    $desc = $opts['desc'] ?? '一款常驻桌面的电子木鱼小部件：无边框、透明背景、始终置顶。敲一下，功德 +1。';
    $active = $opts['active'] ?? '';
    $canonical = wid_base_url(ltrim((string) ($_SERVER['REQUEST_URI'] ?? '/'), '/'));
    ?><!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= e($title) ?></title>
<meta name="description" content="<?= e($desc) ?>">
<link rel="canonical" href="<?= e($canonical) ?>">
<meta name="theme-color" content="#0b0d0c">
<meta property="og:type" content="website">
<meta property="og:title" content="<?= e($title) ?>">
<meta property="og:description" content="<?= e($desc) ?>">
<meta property="og:url" content="<?= e($canonical) ?>">
<link rel="icon" href="data:image/svg+xml,<?= rawurlencode('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><circle cx="16" cy="19" r="11" fill="#7fd1ae"/><path d="M16 3c3 0 5 2 5 5H11c0-3 2-5 5-5z" fill="#3d8f70"/><path d="M4 20c0-5 5-9 12-9s12 4 12 9H4z" fill="#7fd1ae"/></svg>') ?>">
<link rel="stylesheet" href="<?= e(wid_asset('css/site.css')) ?>">
</head>
<body class="page-<?= e($active) ?>">
<a class="skip" href="#main">跳到主要内容</a>
<?php view_nav($active); ?>
<main id="main">
<?php
}

function view_nav(string $active): void
{
    $items = [
        ['home', '/', '首页'],
        ['dashboard', '/dashboard', '数据看板'],
        ['download', '/download', '下载'],
        ['changelog', '/changelog', '更新日志'],
        ['docs', '/docs', '接口文档'],
    ];
    ?>
<header class="nav">
  <div class="nav-inner">
    <a class="brand" href="/" aria-label="返回首页">
      <svg viewBox="0 0 32 32" width="26" height="26" aria-hidden="true">
        <path d="M4 20c0-5 5-9 12-9s12 4 12 9H4z" fill="#7fd1ae"/>
        <rect x="4" y="19" width="24" height="5" rx="2.5" fill="#3d8f70"/>
        <path d="M11 10c0-3 2-5 5-5s5 2 5 5" fill="none" stroke="#7fd1ae" stroke-width="2" stroke-linecap="round"/>
      </svg>
      <span><?= e(cfg('site.name')) ?></span>
    </a>
    <nav class="nav-links" aria-label="主导航">
      <?php foreach ($items as list($key, $href, $label)): ?>
        <a href="<?= e($href) ?>"<?= $active === $key ? ' class="active" aria-current="page"' : '' ?>><?= e($label) ?></a>
      <?php endforeach; ?>
    </nav>
  </div>
</header>
<?php
}

function view_foot(): void
{
    // 页脚的总敲击数属于"锦上添花"，数据库不可用时不能连累整页渲染
    $totalTaps = 0;
    try {
        $totalTaps = \Wid\Model\Stats::totals()['taps'];
    } catch (\Throwable $e) {
        $totalTaps = 0;
    }
    ?>
</main>
<footer class="foot">
  <div class="foot-inner">
    <div class="foot-brand">
      <strong><?= e(cfg('site.name')) ?></strong>
      <span><?= e(cfg('site.subtitle')) ?></span>
    </div>
    <div class="foot-links">
      <a href="/download">下载</a>
      <a href="/changelog">更新日志</a>
      <a href="/docs">接口文档</a>
      <a href="/api/v1/health" rel="nofollow">服务状态</a>
    </div>
    <div class="foot-meta">
      <span>共 <?= e(num($totalTaps)) ?> 次敲击被记录</span>
      <span>·</span>
      <span>&copy; <?= date('Y') ?> <?= e(cfg('site.name')) ?></span>
    </div>
  </div>
</footer>
<script src="<?= e(wid_asset('js/site.js')) ?>" defer></script>
</body>
</html>
<?php
}

/** 页面内的小型 SVG 图标 */
function icon(string $name, int $size = 20): string
{
    $paths = [
        'tap'    => '<circle cx="12" cy="14" r="7"/><path d="M12 3v4"/><path d="M6 20h12"/>',
        'cloud'  => '<path d="M6 18h11a4 4 0 100-8 6 6 0 00-11.5 1.6A3.5 3.5 0 006 18z"/>',
        'leaf'   => '<path d="M5 19c0-8 6-13 14-13 0 8-5 13-14 13z"/><path d="M5 19c3-4 6-6 10-8"/>',
        'chart'  => '<path d="M4 20V10"/><path d="M10 20V4"/><path d="M16 20v-7"/><path d="M20 20H3"/>',
        'shield' => '<path d="M12 3l7 3v6c0 5-3 8-7 9-4-1-7-4-7-9V6l7-3z"/>',
        'gift'   => '<rect x="4" y="9" width="16" height="11" rx="2"/><path d="M4 13h16"/><path d="M12 9v11"/>',
        'bell'   => '<path d="M7 16V11a5 5 0 0110 0v5l2 3H5l2-3z"/><path d="M10 19a2 2 0 004 0"/>',
        'sync'   => '<path d="M20 11a8 8 0 00-14-4"/><path d="M4 13a8 8 0 0014 4"/><path d="M4 5v4h4"/><path d="M20 19v-4h-4"/>',
        'trophy' => '<path d="M8 5h8v5a4 4 0 01-8 0V5z"/><path d="M8 7H5v2a3 3 0 003 3"/><path d="M16 7h3v2a3 3 0 01-3 3"/><path d="M10 19h4"/><path d="M12 14v5"/>',
        'code'   => '<path d="M9 8l-4 4 4 4"/><path d="M15 8l4 4-4 4"/>',
        'download' => '<path d="M12 4v10"/><path d="M8 11l4 4 4-4"/><path d="M5 19h14"/>',
        'check'  => '<path d="M5 13l4 4L19 7"/>',
        'info'   => '<circle cx="12" cy="12" r="8"/><path d="M12 11v5"/><path d="M12 8h.01"/>',
        'warn'   => '<path d="M12 4l8 15H4l8-15z"/><path d="M12 10v4"/><path d="M12 17h.01"/>',
        'heart'  => '<path d="M12 20s-7-4.5-7-9a4 4 0 017-2.6A4 4 0 0119 11c0 4.5-7 9-7 9z"/>',
    ];
    $path = $paths[$name] ?? $paths['info'];
    return '<svg class="ic" viewBox="0 0 24 24" width="' . $size . '" height="' . $size
        . '" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
        . $path . '</svg>';
}
