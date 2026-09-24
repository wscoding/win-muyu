<?php
/**
 * 管理后台入口。
 *
 * 单页结构：未登录时渲染登录表单，已登录时渲染工作台外壳，
 * 数据全部由 admin/api.php 提供（原生 fetch，无构建步骤）。
 * 后台整体加了 noindex，且 nginx 侧对 /admin/ 有额外限制。
 */
require_once dirname(__DIR__) . '/app/bootstrap.php';
require_once __DIR__ . '/lib/AdminAuth.php';

use Wid\Admin\AdminAuth;

$actor = AdminAuth::check();
$siteName = (string) cfg('site.name');

header('X-Robots-Tag: noindex, nofollow');
?>
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>管理后台 · <?= e($siteName) ?></title>
<meta name="robots" content="noindex, nofollow">
<link rel="icon" href="data:image/svg+xml,<?= rawurlencode('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><circle cx="16" cy="19" r="11" fill="#e8b661"/><path d="M4 20c0-5 5-9 12-9s12 4 12 9H4z" fill="#e8b661"/></svg>') ?>">
<link rel="stylesheet" href="/assets/css/site.css?v=<?= e(WID_ASSET_VER) ?>">
<link rel="stylesheet" href="assets/admin.css?v=<?= e(WID_ASSET_VER) ?>">
<?php if ($actor !== null): ?>
<meta name="csrf" content="<?= e(AdminAuth::csrfToken()) ?>">
<?php endif; ?>
</head>
<body class="admin-body">

<?php if ($actor === null): ?>
  <div class="login-wrap">
    <form id="login-form" class="card login-card" autocomplete="off">
      <div class="login-brand">
        <svg viewBox="0 0 32 32" width="34" height="34" aria-hidden="true">
          <path d="M4 20c0-5 5-9 12-9s12 4 12 9H4z" fill="#e8b661"/>
          <rect x="4" y="19" width="24" height="5" rx="2.5" fill="#a97c33"/>
        </svg>
        <div>
          <strong>管理后台</strong>
          <span><?= e($siteName) ?> · wid.chr.cc</span>
        </div>
      </div>
      <div class="field">
        <label for="password">管理口令</label>
        <input type="password" id="password" name="password" placeholder="请输入口令" required autofocus>
      </div>
      <button class="btn btn-primary" type="submit" style="width:100%;justify-content:center">登录</button>
      <div id="login-result" class="result"></div>
      <p class="dim" style="font-size:12.5px;margin:10px 0 0">
        口令在服务器 <code>app/config.php</code> 的 <code>admin.password_hash</code> 中，
        修改后立即生效，无需重启。
      </p>
    </form>
  </div>
  <script>
  document.getElementById('login-form').addEventListener('submit', function (ev) {
    ev.preventDefault();
    var out = document.getElementById('login-result');
    out.className = 'result';
    out.textContent = '正在登录…';
    fetch('api.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'login', password: document.getElementById('password').value })
    })
      .then(function (r) { return r.json(); })
      .then(function (res) {
        if (res.ok) { location.reload(); return; }
        out.className = 'result err';
        out.textContent = res.msg || '登录失败';
      })
      .catch(function (e) { out.className = 'result err'; out.textContent = '请求失败：' + e.message; });
  });
  </script>

<?php else: ?>
  <header class="admin-top">
    <div class="admin-top-inner">
      <div class="admin-brand">
        <strong><?= e($siteName) ?> 控制台</strong>
        <span class="tag tag-jade">wid.chr.cc</span>
      </div>
      <nav class="admin-tabs" id="tabs">
        <button class="tab active" data-tab="overview">概览</button>
        <button class="tab" data-tab="devices">设备</button>
        <button class="tab" data-tab="releases">版本发布</button>
        <button class="tab" data-tab="changelog">更新日志</button>
        <button class="tab" data-tab="content">内容与配置</button>
        <button class="tab" data-tab="feedback">反馈与崩溃</button>
        <button class="tab" data-tab="apps">应用与令牌</button>
        <button class="tab" data-tab="audit">审计与维护</button>
      </nav>
      <div class="admin-top-right">
        <span class="dim" id="clock"></span>
        <button class="btn btn-sm btn-ghost" id="btn-logout">退出</button>
      </div>
    </div>
  </header>

  <main class="admin-main">
    <div id="notify" class="admin-notify" hidden></div>
    <section class="panel active" id="panel-overview"></section>
    <section class="panel" id="panel-devices"></section>
    <section class="panel" id="panel-releases"></section>
    <section class="panel" id="panel-changelog"></section>
    <section class="panel" id="panel-content"></section>
    <section class="panel" id="panel-feedback"></section>
    <section class="panel" id="panel-apps"></section>
    <section class="panel" id="panel-audit"></section>
  </main>

  <script src="assets/admin.js?v=<?= e(WID_ASSET_VER) ?>" defer></script>
<?php endif; ?>
</body>
</html>
