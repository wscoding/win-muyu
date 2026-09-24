<?php
/**
 * 下载页。同时承载「检查更新」小工具 —— 它直接调用 /api/v1/version，
 * 与客户端内置的更新检测走同一套逻辑，所以在这里能验证线上的发布是否正确。
 */
require_once __DIR__ . '/app/bootstrap.php';
require_once WID_APP_DIR . '/view/layout.php';

use Wid\Model\AppKey;
use Wid\Model\Release;

$releases = [];
$error = null;
try {
    $releases = Release::latestAll(AppKey::defaultId());
} catch (\Throwable $e) {
    $error = '数据库暂时不可用，版本信息可能不完整。';
}

$byPlatform = [];
foreach ($releases as $row) {
    $byPlatform[$row['platform']][$row['channel']] = $row;
}

$platforms = [
    'windows' => ['label' => 'Windows 10 / 11', 'note' => '免安装绿色版，双击即用', 'req' => 'Windows 10 1809 及以上，64 位'],
    'macos'   => ['label' => 'macOS 12+', 'note' => '通用二进制，Apple Silicon 原生', 'req' => 'macOS Monterey 及以上'],
    'android' => ['label' => 'Android', 'note' => '移动端适配版，随缘更新', 'req' => 'Android 8.0 及以上'],
    'ios'     => ['label' => 'iOS / iPadOS', 'note' => '开发中', 'req' => 'iOS 15 及以上'],
];

view_head([
    'active' => 'download',
    'title' => '下载 · ' . cfg('site.name'),
    'desc' => '下载 Prue Widgets 桌面电子木鱼：Windows 与 macOS 版本，支持一键检查更新。',
]);
?>

<section class="hero" style="padding-bottom:16px">
  <div class="eyebrow">Download</div>
  <h1 style="font-size:clamp(26px,4vw,38px)">下载 <?= e(cfg('site.name')) ?></h1>
  <p class="lead">
    选择你的平台直接下载。安装包信息（版本号、构建号、体积、SHA-256）全部来自服务端发布记录，
    与应用内的「检查更新」完全一致。
  </p>
</section>

<?php if ($error): ?>
  <div class="note note-amber"><?= icon('warn', 18) ?><div><?= e($error) ?></div></div>
<?php endif; ?>

<section aria-labelledby="dl-title">
  <h2 class="section-title" id="dl-title"><?= icon('download', 19) ?>选择平台</h2>
  <div class="grid grid-2">
  <?php foreach ($platforms as $key => $meta): ?>
    <?php $rel = $byPlatform[$key]['release'] ?? ($byPlatform[$key]['beta'] ?? null); ?>
    <div class="card">
      <h3><?= icon($key === 'windows' ? 'tap' : 'leaf', 18) ?><?= e($meta['label']) ?></h3>
      <p><?= e($meta['note']) ?></p>
      <div style="margin:12px 0" class="tag-row">
        <?php if ($rel): ?>
          <span class="tag tag-jade">v<?= e($rel['version']) ?></span>
          <?php if ($rel['build_number'] !== ''): ?><span class="tag">构建 <?= e($rel['build_number']) ?></span><?php endif; ?>
          <?php if ($rel['file_size']): ?><span class="tag"><?= e(human_size($rel['file_size'])) ?></span><?php endif; ?>
          <?php if ($rel['installer_store'] !== ''): ?><span class="tag"><?= e($rel['installer_store']) ?></span><?php endif; ?>
          <?php if ($rel['force_upgrade']): ?><span class="tag tag-rose">强制更新</span><?php endif; ?>
        <?php else: ?>
          <span class="tag">暂无发布</span>
        <?php endif; ?>
      </div>
      <div class="flex">
        <?php if ($rel && $rel['download_url']): ?>
          <a class="btn btn-primary" href="<?= e($rel['download_url']) ?>"><?= icon('download', 17) ?>下载</a>
        <?php else: ?>
          <span class="btn" style="opacity:.5;cursor:not-allowed">即将上线</span>
        <?php endif; ?>
        <span class="dim" style="font-size:13px">需要 <?= e($meta['req']) ?></span>
      </div>
      <?php if ($rel && $rel['file_hash']): ?>
        <p class="mono dim" style="margin-top:12px;word-break:break-all;font-size:12px">SHA-256：<?= e($rel['file_hash']) ?></p>
      <?php endif; ?>
      <?php if ($rel && $rel['newlog']): ?>
        <p style="margin-top:12px;font-size:13.5px"><?= e($rel['newlog']) ?></p>
      <?php endif; ?>
    </div>
  <?php endforeach; ?>
  </div>
</section>

<section aria-labelledby="upd-title">
  <h2 class="section-title" id="upd-title"><?= icon('sync', 19) ?>检查更新</h2>
  <p class="section-sub">与应用内「更多 → 检查更新」调用的是同一个接口，可用来验证发布是否正确。</p>
  <div class="chart-wrap">
    <form id="update-form" class="inline-form">
      <div class="field">
        <label for="up-platform">平台</label>
        <select id="up-platform" name="platform">
          <option value="windows">Windows</option>
          <option value="macos">macOS</option>
          <option value="android">Android</option>
          <option value="ios">iOS</option>
        </select>
      </div>
      <div class="field">
        <label for="up-channel">渠道</label>
        <select id="up-channel" name="channel">
          <option value="release">正式版 release</option>
          <option value="beta">测试版 beta</option>
        </select>
      </div>
      <div class="field" style="flex:1 1 200px">
        <label for="up-current">当前版本号（可留空）</label>
        <input type="text" id="up-current" name="current" placeholder="例如 3.0.0" autocomplete="off">
      </div>
      <button class="btn btn-primary" type="submit">检查更新</button>
    </form>
    <div id="update-result" class="result"></div>
  </div>
</section>

<section aria-labelledby="rel-title">
  <h2 class="section-title" id="rel-title"><?= icon('bell', 19) ?>发布记录</h2>
  <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th>平台</th><th>渠道</th><th>版本</th><th>构建</th>
          <th>构建日期</th><th class="num">体积</th><th>发布渠道</th><th>强制</th>
        </tr>
      </thead>
      <tbody>
      <?php if (!$releases): ?>
        <tr><td colspan="8" class="dim">暂无发布记录</td></tr>
      <?php endif; ?>
      <?php foreach ($releases as $row): ?>
        <tr>
          <td><?= e(platform_label((string) $row['platform'])) ?></td>
          <td><?= $row['channel'] === 'beta' ? '<span class="tag tag-amber">beta</span>' : '<span class="tag tag-jade">release</span>' ?></td>
          <td class="mono">v<?= e($row['version']) ?></td>
          <td class="mono"><?= e($row['build_number'] ?: '—') ?></td>
          <td class="dim"><?= e($row['appbuild'] ?: '—') ?></td>
          <td class="num"><?= e(human_size($row['file_size'])) ?></td>
          <td class="dim"><?= e($row['installer_store'] ?: '—') ?></td>
          <td><?= $row['force_upgrade'] ? '<span class="tag tag-rose">是</span>' : '<span class="dim">否</span>' ?></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
  <div class="note" style="margin-top:14px">
    <?= icon('info', 18) ?>
    <div>
      接口：<a href="/api/v1/downloads"><code>/api/v1/downloads</code></a>
      · <a href="/api/v1/version?platform=windows&amp;channel=release&amp;current=3.0.0"><code>/api/v1/version</code></a>
      · 完整更新记录见 <a href="/changelog">更新日志</a>。
    </div>
  </div>
</section>

<?php view_foot(); ?>
