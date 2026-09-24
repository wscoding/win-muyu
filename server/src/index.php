<?php
/**
 * 首页（落地页）。
 *
 * 全部服务端渲染：首屏不发任何 fetch 就已是完整内容（数据直接查库），
 * 之后由 assets/js/site.js 每 30 秒刷新一次数字。
 * 好处是 SEO 可抓、断网可看、弱网不白屏 —— 对一个小工具站足够。
 */
require_once __DIR__ . '/app/bootstrap.php';
require_once WID_APP_DIR . '/view/layout.php';

use Wid\Model\AppKey;
use Wid\Model\Changelog;
use Wid\Model\Content;
use Wid\Model\Device;
use Wid\Model\Online;
use Wid\Model\Release;
use Wid\Model\Stats;

// 页面依赖数据库，但个别查询失败不该导致整页白屏
$summary = ['launches' => 0, 'taps' => 0, 'merit' => 0, 'online' => 0, 'devices' => 0,
    'online_peak' => 0, 'today' => ['taps' => 0, 'launches' => 0, 'devices' => 0]];
$trend = [];
$logs = [];
$releases = [];
$blessing = null;
try {
    $appId = AppKey::defaultId();
    $summary = Stats::summary();
    $trend = Stats::trend(7);
    $logs = Changelog::forPublic($appId, null, 4);
    $releases = Release::latestAll($appId);
    // 访客的"每日一签"：用 IP 哈希做种子，不落库、不追踪
    $blessing = Content::blessingFor('web-' . sha1('wid|' . date('Y-m-d') . '|' . \Wid\Core\Http::ip()));
} catch (\Throwable $e) {
    // 数据库不可用时降级为占位数字
}

// 主推版本（优先 windows release）
$primary = null;
foreach ($releases as $row) {
    if ($row['platform'] === 'windows' && $row['channel'] === 'release') {
        $primary = $row;
        break;
    }
}
$primary = $primary ?: ($releases[0] ?? null);

view_head([
    'active' => 'home',
    'title' => cfg('site.name') . ' · 桌面电子木鱼 · 摸鱼小部件',
    'desc' => '一款常驻桌面的电子木鱼小部件：无边框、透明背景、始终置顶、不进任务栏。支持 Windows 与 macOS，敲击数据实时同步到全网功德榜。',
]);
?>

<section class="hero">
  <div class="eyebrow">Windows · macOS · 桌面小组件</div>
  <h1>敲一下，<span class="accent">功德 +1</span><br>摸鱼也能有仪式感。</h1>
  <p class="lead">
    <?= e(cfg('site.name')) ?> 是一款常驻桌面的电子木鱼小部件：无边框、透明背景、始终置顶，
    不进任务栏、不抢焦点。右键即可打开设置，音效、皮肤、快捷键、自动敲击全都可调。
  </p>
  <div class="hero-actions">
    <?php if ($primary): ?>
      <a class="btn btn-primary" href="<?= e($primary['download_url'] ?: '/download') ?>">
        <?= icon('download', 18) ?>下载 v<?= e($primary['version']) ?>
      </a>
    <?php endif; ?>
    <a class="btn btn-ghost" href="/dashboard"><?= icon('chart', 18) ?>查看全网数据</a>
    <a class="btn btn-ghost" href="/docs"><?= icon('code', 18) ?>接口文档</a>
  </div>
</section>

<section aria-labelledby="live-title">
  <h2 class="section-title" id="live-title"><?= icon('chart', 19) ?>全网实时数据</h2>
  <p class="section-sub">数据来自所有已开启统计的客户端，每 30 秒自动刷新一次。</p>
  <div class="grid grid-4">
    <?= stat_card('当前在线', num($summary['online']), '过去 2 分钟内有心跳的设备', ['key' => 'online', 'live' => true, 'icon' => 'cloud']) ?>
    <?= stat_card('累计敲击', num_short($summary['taps']), '功德 ' . num_short($summary['merit']), ['key' => 'taps', 'short' => true, 'icon' => 'tap']) ?>
    <?= stat_card('累计启动', num_short($summary['launches']), '在线峰值 ' . num($summary['online_peak']), ['key' => 'launches', 'short' => true, 'icon' => 'leaf']) ?>
    <?= stat_card('设备总数', num($summary['devices']), '今日活跃 ' . num($summary['today']['devices']), ['key' => 'devices', 'icon' => 'shield']) ?>
  </div>
</section>

<?php if ($blessing): ?>
<section>
  <div class="card" id="blessing-box" style="text-align:center;padding:28px 22px">
    <div class="eyebrow" style="justify-content:center">今日一签</div>
    <p id="blessing-text" style="font-size:19px;line-height:1.9;color:var(--text);margin:6px 0 8px">
      <?= e($blessing['content']) ?>
    </p>
    <p id="blessing-source" class="dim mb-0" style="font-size:13px"><?= e($blessing['source'] ? '— ' . $blessing['source'] : '') ?></p>
  </div>
</section>
<?php endif; ?>

<section aria-labelledby="feat-title">
  <h2 class="section-title" id="feat-title"><?= icon('gift', 19) ?>它能做什么</h2>
  <p class="section-sub">刻意做减法：只保留真正会被用到的功能。</p>
  <div class="grid grid-3">
    <div class="card">
      <h3><?= icon('tap', 18) ?>随处可敲</h3>
      <p>单击、长按连击、全局快捷键，三种方式都能敲。自动敲击最低 150ms 一次，摸鱼一整天也不会手酸。</p>
    </div>
    <div class="card">
      <h3><?= icon('cloud', 18) ?>全网功德</h3>
      <p>你的每一次敲击都会汇入全网统计，与所有施主一起把功德堆高。设备是匿名标识，不采集任何个人身份信息。</p>
    </div>
    <div class="card">
      <h3><?= icon('chart', 18) ?>数据看板</h3>
      <p>启动次数、在线人数、敲击趋势、平台分布一目了然。看板只展示聚合数字，不暴露单台设备。</p>
    </div>
    <div class="card">
      <h3><?= icon('leaf', 18) ?>每日一签</h3>
      <p>按日期轮换的禅语与功德语，每天打开都是新的。内容在服务端配置，不发版也能更新。</p>
    </div>
    <div class="card">
      <h3><?= icon('sync', 18) ?>设置云同步</h3>
      <p>音效、皮肤、快捷键、窗口位置都可以同步到云端，换台机器接着敲，配置不用重来一遍。</p>
    </div>
    <div class="card">
      <h3><?= icon('shield', 18) ?>隐私优先</h3>
      <p>统计开关默认关闭，设备标识本地随机生成。排行榜需主动开启并设置昵称，且对外只显示打码后的名字。</p>
    </div>
  </div>
</section>

<section aria-labelledby="trend-title">
  <div class="chart-wrap">
    <div class="chart-head">
      <h3 id="trend-title">近 7 日敲击趋势</h3>
      <div class="chart-legend">
        <span><i style="background:var(--jade)"></i>敲击次数</span>
        <span><i style="background:#4c5a55"></i>活跃设备</span>
        <a href="/dashboard">完整看板 →</a>
      </div>
    </div>
    <?= render_bars($trend, 'date', 'taps', 'devices') ?>
  </div>
</section>

<?php if ($logs): ?>
<section aria-labelledby="log-title">
  <h2 class="section-title" id="log-title"><?= icon('bell', 19) ?>最近更新</h2>
  <p class="section-sub">完整更新记录见<a href="/changelog">更新日志</a>。</p>
  <?= render_log_items($logs, false) ?>
</section>
<?php endif; ?>

<section aria-labelledby="api-title">
  <h2 class="section-title" id="api-title"><?= icon('code', 19) ?>开放的接口</h2>
  <p class="section-sub">所有接口都支持 HTTPS + HMAC 签名，公开只读接口无需鉴权。</p>
  <div class="grid grid-2">
    <div class="card">
      <h3><?= icon('cloud', 18) ?>客户端接入</h3>
      <p class="mono" style="color:var(--jade)">POST /api/v1/launch · heartbeat · taps</p>
      <p style="margin-top:8px">启动注册、在线心跳、批量敲击上报，三步即可接入统计。</p>
    </div>
    <div class="card">
      <h3><?= icon('chart', 18) ?>数据查询</h3>
      <p class="mono" style="color:var(--jade)">GET /api/v1/stats/summary · trend · breakdown</p>
      <p style="margin-top:8px">公开只读，可直接用于网页、桌面小组件或自建看板。</p>
    </div>
  </div>
  <div class="note" style="margin-top:14px">
    <?= icon('info', 18) ?>
    <div>健康检查：<a href="/api/v1/health" rel="nofollow"><code>/api/v1/health</code></a>
      · 完整契约见 <a href="/docs">接口文档</a>。</div>
  </div>
</section>

<?php view_foot(); ?>
