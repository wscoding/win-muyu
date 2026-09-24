# 项目长期记忆（win-muyu / Prue Widgets）

## 后端与线上资产

- **接口 v3 已上线**：`https://wid.chr.cc`，服务端工程在仓库 `server/`。
  契约 `server/src/app/content/api-v3.md`；`docs/backend-api.md` 是 v2 存档已作废。
- **站点目录**：`/www/wwwroot/wid.chr.cc`（宝塔站点，root，PHP 7.4，MySQL 5.7）。
- **数据库**：库 `wid`，用户 `wid`，口令 `wid`（本服务器约定：密码==用户名，仅授权 127.0.0.1）。
- **凭据文件**：`server/Scripts/.wid_secrets.json`（db/app_key/app_secret/后台口令/session_secret）。
  **不进版本库**；后台口令只在首次生成时打印一次。
- **部署**：`cd server && python Scripts/deploy_wid_site.py`
  （staging→远端 `php -l` 预检→备份→同步→nginx 校验→重启 php-fpm 刷 OPcache）。
- **服务器凭据**：见 `server/Scripts/widlib.py`（复用 xianyan 项目约定，未改动该项目）。

## 客户端与后端的连接点

- `lib/constants/app_config.dart`：`apiBaseUrl` / `appKey` / `appSecret` / 上报节奏默认值。
- `lib/services/telemetry_service.dart`：签名、批量攒报、心跳、更新检测、云同步、反馈/崩溃。
- `lib/services/device_identity.dart`：匿名设备标识（本地随机生成，非硬件指纹）。
- `lib/services/remote_config.dart`：服务端下发的运行时配置（本地缓存，离线可用）。
- `lib/models/update_check_result.dart`：更新检测结果（含强制更新与更新日志）。
- `crypto` 已作为直接依赖加入（仅用于 HMAC-SHA256）。
- **改上报代码后必须跑** `flutter test integration/live_api_check.dart`
  （真实客户端 ↔ 线上后端，能暴露跨语言签名不一致；跑完用
  `server/Scripts/cleanup_live_device.py <device_id>` 清理数据）。
- **改「敲击 → 看板」链路后必须跑** `python server/Scripts/test_dashboard_live.py`
  （闭环测试：真实密钥 launch → taps，断言看板数字真的增加了）。
- **匿名统计默认开启**（2026-09-24 起）。`AppSettings.telemetryEnabled` 默认 `true`
  —— 看板数据源全靠它，默认关等于看板永远不动。老用户显式关过的不被升级改回来。
- 上报节奏三条触发线：攒够 `tapBatchSize` / **空闲后首敲即报** / 超时兜底，
  受 `tapMinIntervalMs`（默认 1000ms）约束以防 QPS 回退。
  坑：`_lastFlushAt` 必须记**发起**时间而非成功时间，否则连击时中间几下
  全被误判成「空闲」而各发一次请求。

## 该服务器的硬约束（务必遵守）

- **不在本机编译任何东西**：内存可用约 0.9G，曾因 `make` 打爆内存导致 OOM 重启。
- **不重启 Redis**（已被站长停用）；**不动 443**（站长明确不处理证书）。
- PHP-FPM 重启（约 1 秒）是安全的，且是刷新 OPcache 的必要手段。
- 宝塔的 `extension/<站点>/*.conf` 不受面板改写 vhost 影响，站点自定义规则都放那里。
- 数据库命令行客户端默认 utf8（三字节），所有 `mysql` 调用带
  `--default-character-set=utf8mb4`。

## 待办与已知阻塞

- **DNSSEC 阻塞（域名侧，需站长处理）**：`chr.cc` 的 DS 是算法 8（RSA），
  Cloudflare 权威 DNSKEY 是算法 13（ECDSA），校验型 DNS 全部 SERVFAIL。
  详见 `server/docs/extensibility.md` 第 6 节。
- 服务端接口 23 个、后台 8 个功能页均已自检通过；客户端 85 项单测 + 11 项线上联调 +
  25 项看板闭环测试通过。
- 可扩展方向与「交互增强盘点」见 `server/docs/extensibility.md`
  （P0 剩余：崩溃上报接入；P1：设置云同步开关、敲击物理上限校验）。
