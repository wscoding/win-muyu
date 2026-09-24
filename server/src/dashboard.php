<?php
/**
 * 数据看板。展示口径全部是聚合数字 —— 单台设备的信息不会出现在这里。
 */
require_once __DIR__ . '/app/bootstrap.php';
require_once WID_APP_DIR . '/view/layout.php';

use Wid\Model\AppKey;
use Wid\Model\Device;
use Wid\Model\Online;
use Wid\Model\Rank;
use Wid\Model\Stats;

$summary = null;
$trend7 = [];
$trend30 = [];
$platforms = [];
$versions = [];
$board = [];
$error = null;
try {
    AppKey::defaultId();
    $summary = Stats::summary();
    $trend7 = Stats::trend(7);
    $trend30 = Stats::trend(30);
    $breakdown = [];
    foreach (Device::platformBreakdown() as $row) {
        $breakdown[$row['platform']] = ['devices' => (int) $row['devices'], 'online' => 0];
    }
    foreach (Online::countByPlatform() as $row) {
        $breakdown[$row['platform']]['online'] = (int) $row['online'];
    }
    $platforms = $breakdown;
    $versions = Device::versionBreakdown(8);
    $board = Rank::leaderboard('week', 10);
} catch (\Throwable $e) {
    $error = '数据库暂时不可用，页面已降级显示。';
}

view_head([
    'active' => 'dashboard',
    'title' => '数据看板 · ' . cfg('site.name'),
    'desc' => '全网电子木鱼数据看板：实时在线人数、累计敲击与功德、近 30 日趋势、平台与版本分布、周功德榜。',
]);
?>

<section class="hero" style="padding-bottom:14px">
  <div class="eyebrow">Dashboard</div>
  <h1 style="font-size:clamp(26px,4vw,38px)">全网数据看板</h1>
  <div class="live-bar">
    <span class="live-dot" aria-hidden="true"></span>
    <span class="live-text">
      整页每 <strong>30</strong> 秒自动刷新 · 最后更新
      <strong data-live-updated><?= e(date('H:i:s', strtotime((string) ($summary['updated_at'] ?? 'now')))) ?></strong>
    </span>
    <span class="live-actions">
      <button type="button" class="btn btn-sm" id="dash-refresh">立即刷新</button>
      <button type="button" class="btn btn-sm" id="dash-toggle" aria-pressed="false">暂停</button>
    </span>
  </div>
  <p class="lead">看板只呈现聚合结果，任何单台设备的信息都不会出现在这里。</p>
</section>

<?php if ($error): ?>
  <div class="note note-amber"><?= icon('warn', 18) ?><div><?= e($error) ?></div></div>
<?php endif; ?>

<?php if ($summary): ?>
<section aria-labelledby="s1">
  <h2 class="section-title" id="s1"><?= icon('cloud', 19) ?>实时概览</h2>
  <div class="grid grid-4">
    <?= stat_card('当前在线', num($summary['online']), '窗口 ' . num($summary['online_window']) . ' 秒', ['key' => 'online', 'live' => true, 'icon' => 'cloud']) ?>
    <?= stat_card('今日活跃设备', num($summary['today']['devices']), '今日启动 ' . num($summary['today']['launches']), ['key' => 'today_devices', 'icon' => 'shield']) ?>
    <?= stat_card('在线峰值', num($summary['online_peak']), '历史最高同时在线', ['key' => 'peak', 'icon' => 'trophy']) ?>
    <?= stat_card('设备总数', num($summary['devices']), '累计启动 ' . num_short($summary['launches']), ['key' => 'devices', 'icon' => 'leaf']) ?>
  </div>
  <div class="grid grid-4" style="margin-top:14px">
    <?= stat_card('累计敲击', num($summary['taps']), '含今日 ' . num($summary['today']['taps']), ['key' => 'taps', 'icon' => 'tap']) ?>
    <?= stat_card('累计功德', num($summary['merit']), '每 100 次敲击记 1 功德', ['key' => 'merit', 'icon' => 'heart']) ?>
    <?= stat_card('今日敲击', num($summary['today']['taps']), '今日功德 ' . num($summary['today']['merit']), ['key' => 'today_taps', 'small' => true, 'icon' => 'chart']) ?>
    <?= stat_card('今日心跳', num($summary['today']['heartbeats']), '用于判定在线状态', ['small' => true, 'icon' => 'sync']) ?>
  </div>
</section>

<section aria-labelledby="s2">
  <div class="chart-wrap" data-live-block="trend30">
    <div class="chart-head">
      <h3 id="s2">近 30 日趋势</h3>
      <div class="chart-legend">
        <span><i style="background:var(--jade)"></i>敲击次数</span>
        <span><i style="background:#4c5a55"></i>活跃设备</span>
      </div>
    </div>
    <?= render_bars($trend30, 'date', 'taps', 'devices') ?>
  </div>
  <div class="chart-wrap" style="margin-top:14px">
    <div class="chart-head">
      <h3>近 7 日明细</h3>
      <div class="chart-legend"><span>按日汇总，缺数据的日期显示为 0</span></div>
    </div>
    <div class="table-wrap">
      <table>
        <thead>
          <tr><th>日期</th><th class="num">敲击</th><th class="num">启动</th><th class="num">活跃设备</th></tr>
        </thead>
        <tbody data-live-block="trend7">
        <?php foreach (array_reverse($trend7) as $row): ?>
          <tr>
            <td><?= e($row['date']) ?></td>
            <td class="num"><?= e(num($row['taps'])) ?></td>
            <td class="num"><?= e(num($row['launches'])) ?></td>
            <td class="num"><?= e(num($row['devices'])) ?></td>
          </tr>
        <?php endforeach; ?>
        </tbody>
      </table>
    </div>
  </div>
</section>

<section aria-labelledby="s3">
  <h2 class="section-title" id="s3"><?= icon('shield', 19) ?>平台分布</h2>
  <div class="grid grid-2">
    <div class="chart-wrap">
      <div class="table-wrap">
        <table>
          <thead><tr><th>平台</th><th class="num">设备</th><th class="num">在线</th></tr></thead>
          <tbody data-live-block="platforms">
          <?php if (!$platforms): ?>
            <tr><td colspan="3" class="dim">暂无数据</td></tr>
          <?php endif; ?>
          <?php foreach ($platforms as $key => $row): ?>
            <tr>
              <td><?= e(platform_label((string) $key)) ?></td>
              <td class="num"><?= e(num($row['devices'])) ?></td>
              <td class="num"><?= e(num($row['online'])) ?></td>
            </tr>
          <?php endforeach; ?>
          </tbody>
        </table>
      </div>
    </div>
    <div class="chart-wrap">
      <div class="table-wrap">
        <table>
          <thead><tr><th>客户端版本</th><th class="num">设备数</th></tr></thead>
          <tbody data-live-block="versions">
          <?php if (!$versions): ?>
            <tr><td colspan="2" class="dim">暂无数据</td></tr>
          <?php endif; ?>
          <?php foreach ($versions as $row): ?>
            <tr>
              <td class="mono">v<?= e($row['version'] ?: '未知') ?></td>
              <td class="num"><?= e(num($row['devices'])) ?></td>
            </tr>
          <?php endforeach; ?>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</section>

<section aria-labelledby="s4">
  <h2 class="section-title" id="s4"><?= icon('trophy', 19) ?>本周功德榜</h2>
  <p class="section-sub">仅统计主动开启「功德榜」的设备，昵称已打码；默认不参与。</p>
  <div class="table-wrap">
    <table>
      <thead><tr><th>名次</th><th>施主</th><th>平台</th><th class="num">本周敲击</th></tr></thead>
      <tbody data-live-block="board">
      <?php if (!$board): ?>
        <tr><td colspan="4" class="dim">还没有人开启功德榜。在客户端「设置 → 功德榜」里开启即可上榜。</td></tr>
      <?php endif; ?>
      <?php foreach ($board as $item): ?>
        <tr>
          <td class="num" style="width:64px"><?= (int) $item['rank'] ?></td>
          <td><?= e((string) $item['nickname']) ?></td>
          <td class="dim"><?= e(platform_label((string) $item['platform'])) ?></td>
          <td class="num"><?= e(num($item['taps'])) ?></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</section>

<section>
  <div class="note">
    <?= icon('info', 18) ?>
    <div>
      数据接口：<a href="/api/v1/stats/summary"><code>/api/v1/stats/summary</code></a>
      · <a href="/api/v1/stats/trend?days=30"><code>/api/v1/stats/trend?days=30</code></a>
      · <a href="/api/v1/stats/breakdown"><code>/api/v1/stats/breakdown</code></a>
      · <a href="/api/v1/leaderboard?range=week"><code>/api/v1/leaderboard?range=week</code></a>
    </div>
  </div>
</section>
<?php endif; ?>

<?php view_foot(); ?>
