<?php
/**
 * 更新日志页。数据源与 /api/v1/changelog 相同（changelog_entries 表）。
 */
require_once __DIR__ . '/app/bootstrap.php';
require_once WID_APP_DIR . '/view/layout.php';

use Wid\Model\AppKey;
use Wid\Model\Changelog;

$items = [];
$error = null;
try {
    $items = Changelog::forPublic(AppKey::defaultId(), null, 60);
} catch (\Throwable $e) {
    $error = '数据库暂时不可用，暂时无法显示更新日志。';
}

view_head([
    'active' => 'changelog',
    'title' => '更新日志 · ' . cfg('site.name'),
    'desc' => 'Prue Widgets 桌面电子木鱼的完整更新记录：新功能、修复与优化。',
]);
?>

<section class="hero" style="padding-bottom:16px">
  <div class="eyebrow">Changelog</div>
  <h1 style="font-size:clamp(26px,4vw,38px)">更新日志</h1>
  <p class="lead">每一次改动都记在这里。客户端也会通过更新接口读取同一份数据。</p>
  <div class="hero-actions">
    <a class="btn btn-ghost" href="/download"><?= icon('download', 18) ?>前往下载</a>
    <a class="btn btn-ghost" href="/api/v1/changelog?limit=50"><?= icon('code', 18) ?>以 JSON 获取</a>
  </div>
</section>

<?php if ($error): ?>
  <div class="note note-amber"><?= icon('warn', 18) ?><div><?= e($error) ?></div></div>
<?php endif; ?>

<section>
  <?= render_log_items($items, true) ?>
</section>

<?php view_foot(); ?>
