# wid.chr.cc 部署与运维手册

> 站点根目录：`/www/wwwroot/wid.chr.cc`
> 服务器：`123.207.67.197:2026`（root），宝塔站点，**全机只有 PHP 7.4**
> 本文记录的是**实际踩过的坑**，改配置前请先读第 3 节。

---

## 1. 目录结构与职责

```
server/
├── src/                     # 站点源码，部署脚本会同步到 /www/wwwroot/wid.chr.cc
│   ├── index.php            # 落地页
│   ├── dashboard.php        # 数据看板
│   ├── download.php         # 下载页 + 检查更新小工具
│   ├── changelog.php        # 更新日志页
│   ├── docs.php             # 接口文档页（渲染 app/content/api-v3.md）
│   ├── sitemap.php          # /sitemap.xml 动态生成
│   ├── 404.php / 404.html   # 404（PHP 供应用层兜底，HTML 供 nginx error_page）
│   ├── api/index.php        # 接口前端控制器（唯一入口）
│   ├── app/                 # ★ 全部内部代码，nginx 已封禁外部访问
│   │   ├── config.php       # 真实配置（部署时生成，权限 640，不进版本库）
│   │   ├── config.dist.php  # 配置模板
│   │   ├── bootstrap.php    # 常量 / 自动加载 / 异常兜底
│   │   ├── schema.sql       # 20 张表结构（幂等）
│   │   ├── seed.sql         # 初始内容（功德语、配置、发布记录、日志）
│   │   ├── content/api-v3.md# 接口契约（站点 /docs 渲染的就是它）
│   │   ├── core/            # Db / Http / Sign / Rate / Respond / Event / Support
│   │   ├── model/           # 数据访问层
│   │   ├── api/             # 接口处理器 + 路由表
│   │   └── view/            # 页面外壳与组件
│   ├── admin/               # 管理后台（index.php 页面 + api.php 接口）
│   └── assets/              # 前台 CSS/JS
└── Scripts/
    ├── widlib.py            # SSH/SFTP/HTTP 公共库（凭据集中在这里）
    ├── ssh_client.py        # 随手执行一条远程命令
    ├── init_wid_db.py       # 建库建用户 + 导入表结构与种子数据
    ├── deploy_wid_site.py   # 部署（staging → 语法预检 → 备份 → 同步 → nginx → 刷 OPcache）
    ├── test_wid_api.py      # 接口契约测试（双通道）
    ├── test_admin_api.py    # 管理后台接口测试
    ├── check_web.py         # 网页与静态资源检查（含源码泄露断言）
    ├── cleanup_live_device.py  # 清理联调/测试设备及其统计痕迹
    └── debug_sign.py        # 签名链路排查（三条路径比对）
```

---

## 2. 首次部署（三步）

```bash
cd server

# 1) 建库、建用户、导入表结构与初始内容，并生成 app_secret 到 .wid_secrets.json
python Scripts/init_wid_db.py

# 2) 部署代码（会生成 app/config.php 并打印后台口令，请立即保存）
python Scripts/deploy_wid_site.py

# 3) 验证
python Scripts/test_wid_api.py      # 接口契约，双通道
python Scripts/test_admin_api.py    # 管理后台
python Scripts/check_web.py         # 网页与静态资源
```

`.wid_secrets.json`（本地，**不要进版本库**）保存：数据库口令、`app_key`/`app_secret`、
后台口令与会话密钥。重装站点时 `--force-config` 会重新生成并覆盖线上 `config.php`
（注意：轮换 `session_secret` 会让已登录的后台会话失效）。

### 日常改动部署

```bash
python Scripts/deploy_wid_site.py            # 全量（幂等）
python Scripts/deploy_wid_site.py --no-nginx # 只传文件
python Scripts/deploy_wid_site.py --dry-run  # 只打印计划
```

部署流程是 **all-or-nothing**：先上传到 `/www/wwwroot/_wid_staging`，
远端对所有 PHP 做 `php -l` 语法预检，**任何一个文件不通过就中止**，
不会把半成品代码落到站点目录。通过后才备份站点（tar 到 `/www/wwwroot/_backup_wid/`，
只保留最近 10 份）并同步。

---

## 3. 已知坑（全部为实战踩过，改配置前必读）

### 3.1 OPcache 会把新代码延迟 60 秒生效 ★

本机 `opcache.validate_timestamps=1` 且 `opcache.revalidate_freq=60`，
意味着**刚部署完立刻验证，跑的还是旧字节码**。曾因此怀疑「代码改了却没生效」
排查很久。`deploy_wid_site.py` 已在部署末尾自动 `systemctl restart php-fpm-74`
（约 1 秒）刷新；手工改线上文件后请自行重启或等 60 秒。

### 3.2 宝塔全局开了 `fastcgi_intercept_errors on` ★

宝塔的 `/www/server/nginx/conf/nginx.conf` 在 http 段开启了它，
于是 **PHP 返回的 404 会被 nginx 换成 HTML 错误页**，接口的 JSON 契约被破坏
（实测 `/api/v1/profile` 设备不存在时拿到的是 `404.html`）。

修复：在站点的 server 段覆盖为 `off`（见 `deny_internal.conf` 第 1.5 节）。
**必须写在 server 段**：`try_files` 内部重定向后生效的是 PHP location 的继承值，
只写进 `location` 不起作用。

### 3.3 `try_files` 的两个反直觉行为 ★

1. **最后一项是 URI 时必须显式带 `?$args`**，否则查询串在内部重定向时被丢掉。
   表现为 `/api/v1/version?platform=windows` 拿不到任何参数。
2. **中间参数命中文件时不会内部重定向**，而是留在当前 location 按静态文件返回。
   所以 `try_files $uri $uri/ $uri.php` 会把 `.php` 当文本直出 ——
   实测泄露过 `/changelog`、`/docs` 的完整源码。
   无扩展名路由必须用 `rewrite ... last`（见 `deny_internal.conf` 第 3 节）。

### 3.4 宝塔默认的 `location ~ .*\.(js|css)?$` 会吞掉所有路径 ★

`(js|css)?` 是可选的，因此这条正则**匹配任意 URI**；而正则 location 的优先级
高于普通前缀 location，于是 `/dashboard` 这类无扩展名路由直接 404。

本项目的做法：在 `extension/<站点>/` 里用正则 location 声明自己的规则。
**include 顺序决定了正则的匹配优先级** ——
`extension/*.conf` 在 vhost 中位于 `enable-php-74.conf` 之前，所以能先命中。

### 3.5 二进制列不能直接进 JSON ★

`ip` 列是 `VARBINARY(16)`，直接塞进 `json_encode` 会因非法 UTF-8
**返回 false，响应体变成空字符串 + HTTP 200**（客户端完全无法判断发生了什么）。
凡是取出二进制列的接口都必须转成文本（`Http::ipText()`）。
另外 `Respond::json()` 已加 `JSON_INVALID_UTF8_SUBSTITUTE` 兜底，
宁可把坏字节替换成 U+FFFD 也绝不返回空响应。

### 3.6 不要用 `^~ /api/` 做接口路由

`^~` 前缀匹配的优先级高于 PHP 的 regex location，`try_files` 回落到
`/api/index.php` 后会**把 PHP 源码当静态文件吐出来**。
必须用带负向先行断言的 regex：`location ~ ^/api/(?!index\.php)`。

### 3.7 数据库连接字符集

命令行 `mysql` 客户端默认 `character_set_client=utf8`（三字节），
写入 emoji 等四字节字符会乱码。所有脚本的 mysql 调用都带
`--default-character-set=utf8mb4`。

### 3.8 其它

- **本机内存偏紧（可用约 0.9G），绝对不要在本机编译任何软件**：
  曾为装 PHP 5.6 跑 `make` 打爆内存导致服务器 OOM 重启（见服务器交接文档已知坑 26）。
- **`/usr/bin/mysql` 是 MariaDB 5.5 客户端**，与服务端 5.7 配合会给出矛盾结论；
  判定站点能否连库一律用 PHP PDO。
- **宝塔面板对无浏览器 UA 的 curl 返回 404 属正常**（防扫描），验证面板存活要带 UA。
- 宝塔改写 vhost 主文件时**不会动** `extension/<站点>/*.conf`，
  所以本站的加固与路由规则都放在那里，面板里改站点设置后无需重新对齐。

---

## 4. 服务器上的固定路径

| 用途 | 路径 |
|---|---|
| 站点根 | `/www/wwwroot/wid.chr.cc` |
| 配置（含口令） | `/www/wwwroot/wid.chr.cc/app/config.php`（640，www:www） |
| PHP 错误日志 | `/www/wwwroot/wid.chr.cc/app/log/php-error.log` |
| 站点访问日志 | `/www/wwwlogs/wid.chr.cc.log` |
| nginx 加固/路由 | `/www/server/panel/vhost/nginx/extension/wid.chr.cc/deny_internal.conf` |
| 部署备份 | `/www/wwwroot/_backup_wid/wid_site_<时间戳>.tar.gz` |
| 部署暂存 | `/www/wwwroot/_wid_staging`（部署结束会删除） |
| PHP / MySQL | `/www/server/php/74/bin/php`、MySQL 5.7.44（root `258051`） |

---

## 5. 回滚

```bash
# 列出备份
python Scripts/ssh_client.py "ls -lt /www/wwwroot/_backup_wid/"

# 回滚到指定快照
python Scripts/ssh_client.py "tar -xzf /www/wwwroot/_backup_wid/wid_site_20260923_050649.tar.gz -C /www/wwwroot/wid.chr.cc && chown -R www:www /www/wwwroot/wid.chr.cc && systemctl restart php-fpm-74"
```

数据库回滚依赖 binlog（本机没有自动 mysqldump 备份，`expire_logs_days=3`）。
**改表结构前先手工导出**：

```bash
python Scripts/ssh_client.py "mysqldump --default-character-set=utf8mb4 -uroot -p258051 wid > /root/wid_backup_$(date +%Y%m%d_%H%M%S).sql"
```

---

## 6. 运维速查

```bash
# 服务状态
python Scripts/ssh_client.py "systemctl is-active nginx mysqld php-fpm-74"

# 接口健康检查（不用登录）
python Scripts/ssh_client.py "curl -sS -H 'Host: wid.chr.cc' http://127.0.0.1/api/v1/health"

# 看最近的 PHP 报错
python Scripts/ssh_client.py "tail -30 /www/wwwroot/wid.chr.cc/app/log/php-error.log"

# 看后台操作审计
python Scripts/ssh_client.py "mysql --default-character-set=utf8mb4 -uroot -p258051 -N wid -e \"SELECT created_at,event,message FROM event_log ORDER BY id DESC LIMIT 20;\" 2>/dev/null"

# 清理联调/测试设备（会连统计增量一起扣掉）
python Scripts/cleanup_live_device.py --list
python Scripts/cleanup_live_device.py <device_id>

# DNSSEC 巡检（抓「DS 与 DNSKEY 不匹配 → 全站无法解析」这类静默故障）
python Scripts/check_dnssec.py            # 体检默认域名清单
python Scripts/check_dnssec.py chr.cc     # 指定域名
python Scripts/check_dnssec.py --strict   # 有问题时以非 0 退出，可挂监控
```

**建议**：把 `check_dnssec.py --strict` 加进定时任务（每天一次）。
DNSSEC 配置错误是**静默的** —— 2026-09-23 `chr.cc` 就因为 DS 算法填错
（写成 8，实际是 13）导致整个域名的所有子域 SERVFAIL，而且没人发现。
脚本会在 DS 与 DNSKEY 不匹配时直接给出「正确的 DS 应该是多少」。

后台里的「维护工具」还提供：清理限流桶 / 过期 nonce / 超时会话 / 60 天前事件 /
30 天前崩溃上报，以及**用 daily_stats 重算 global_stats**（数据核对用）。
