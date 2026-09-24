<?php
/**
 * 接口文档页。内容源为 app/content/api-v3.md（与仓库里的契约文档同一份），
 * 用 app/core/Support.php 里的极简 Markdown 渲染器转成 HTML。
 */
require_once __DIR__ . '/app/bootstrap.php';
require_once WID_APP_DIR . '/view/layout.php';

$file = WID_APP_DIR . '/content/api-v3.md';
$markdown = is_file($file) ? (string) file_get_contents($file) : '';
$html = $markdown !== '' ? Markdown::render($markdown) : '<p class="muted">文档文件缺失。</p>';
$toc = $markdown !== '' ? Markdown::toc($markdown) : [];

view_head([
    'active' => 'docs',
    'title' => '接口文档 v3 · ' . cfg('site.name'),
    'desc' => 'Prue Widgets 后端接口契约：HMAC 签名鉴权、生命周期、敲击统计、版本更新检测、数据看板与云同步。',
]);
?>

<section class="hero" style="padding-bottom:14px">
  <div class="eyebrow">API v3</div>
  <h1 style="font-size:clamp(26px,4vw,38px)">后端接口文档</h1>
  <p class="lead">
    全部接口走 HTTPS，写接口使用 HMAC-SHA256 签名。公开只读接口无需鉴权，可直接用于自建看板或第三方客户端。
  </p>
  <div class="hero-actions">
    <a class="btn btn-ghost" href="/api/v1/health" rel="nofollow"><?= icon('check', 18) ?>健康检查</a>
    <a class="btn btn-ghost" href="/api/v1/config"><?= icon('code', 18) ?>运行时配置</a>
    <a class="btn btn-ghost" href="/api/v1/stats/summary"><?= icon('chart', 18) ?>统计接口</a>
  </div>
</section>

<?php if ($toc): ?>
<section style="padding-top:10px">
  <div class="card">
    <h3><?= icon('info', 18) ?>目录</h3>
    <div class="grid grid-3" style="margin-top:10px">
      <?php foreach ($toc as $item): ?>
        <?php if ($item['level'] === 2): ?>
          <a href="#<?= e($item['anchor']) ?>" style="font-size:14px"><?= e($item['text']) ?></a>
        <?php endif; ?>
      <?php endforeach; ?>
    </div>
  </div>
</section>
<?php endif; ?>

<section>
  <div class="card doc-body">
    <?= $html ?>
  </div>
</section>

<?php view_foot(); ?>
