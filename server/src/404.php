<?php
/**
 * 404 页面。
 * nginx vhost 里配置了 `error_page 404 /404.html`，但 .php 也需要一份，
 * 供 Http::notFoundPage() 与应用级路由兜底使用。
 */
require_once __DIR__ . '/app/bootstrap.php';
require_once WID_APP_DIR . '/view/layout.php';

http_response_code(404);
view_head([
    'active' => '404',
    'title' => '页面不存在 · ' . cfg('site.name'),
    'desc' => '你访问的页面不存在。',
]);
?>
<section class="hero" style="text-align:center;padding:80px 0 40px">
  <div class="eyebrow" style="justify-content:center">404</div>
  <h1 style="font-size:clamp(26px,4vw,40px)">这个页面不存在</h1>
  <p class="lead" style="margin:0 auto 26px">
    可能是链接写错了，或者这个页面已经被合并到了别处。<br>
    不如回去敲一下木鱼，功德 +1。
  </p>
  <div class="hero-actions" style="justify-content:center">
    <a class="btn btn-primary" href="/"><?= icon('tap', 18) ?>返回首页</a>
    <a class="btn btn-ghost" href="/docs"><?= icon('code', 18) ?>接口文档</a>
  </div>
</section>
<?php view_foot(); ?>
