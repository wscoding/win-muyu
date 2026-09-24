# win-muyu 后端（wid.chr.cc）

Prue Widgets（桌面电子木鱼）的**网站 + 接口**。独立于客户端仓库之外的
服务端工程：PHP 7.4 + MySQL 5.7，部署在已有的宝塔服务器上，
站点根目录 `/www/wwwroot/wid.chr.cc`。

- 线上站点：`https://wid.chr.cc`
- 接口契约：`https://wid.chr.cc/docs`（源文件 `src/app/content/api-v3.md`）
- 管理后台：`https://wid.chr.cc/admin/`（口令见本地 `Scripts/.wid_secrets.json`）

---

## 做了什么

| 模块 | 说明 |
|---|---|
| **接口 v3** | 23 个接口：生命周期、敲击统计、版本更新检测、数据看板、内容与配置、反馈与同步。HTTPS + HMAC-SHA256 签名 + 时间戳窗口 + nonce 防重放 + 双层限流 |
| **落地页** | 产品介绍、实时数据、每日一签、下载入口 |
| **数据看板** | 在线/敲击/功德/设备、30 日趋势、平台与版本分布、周功德榜。**整页每 30 秒自动刷新**（数字卡 + 趋势图 + 明细表 + 分布 + 榜单），可暂停/立即刷新 |
| **下载页** | 各平台版本卡片 + 「检查更新」小工具（与应用内检测走同一接口） |
| **更新日志页** | 数据源与 `/changelog` 一致 |
| **接口文档页** | 渲染 Markdown 契约，带目录与复制按钮 |
| **管理后台** | 概览、设备（封禁/详情）、版本发布、更新日志、运行时配置、公告、功德语、资源包、反馈与崩溃、应用密钥与令牌、审计与维护 |
| **数据层** | 20 张表，覆盖应用/设备/在线/日聚合/发布/日志/内容/运营 |

设计取舍看 `docs/extensibility.md`；部署与踩坑看 `docs/deployment.md`。

---

## 快速开始

```bash
cd server

python Scripts/init_wid_db.py       # 1) 建库 + 表结构 + 初始内容（幂等）
python Scripts/deploy_wid_site.py   # 2) 部署代码（会自动刷新 OPcache）
python Scripts/test_wid_api.py      # 3) 接口契约测试（本机 + 外网双通道）
python Scripts/test_dashboard_live.py  # 敲一下 -> 看板数字真的变了（闭环）
python Scripts/check_web.py         #    网页与静态资源检查
python Scripts/test_admin_api.py    #    管理后台接口测试
```

依赖：`paramiko`（已装在
`C:/Users/无书/.workbuddy/binaries/python/envs/default`）。

### 目前的自检结果（2026-09-24）

| 脚本 | 结果 |
|---|---|
| `test_wid_api.py` | **146 / 146 通过**（双通道） |
| `test_dashboard_live.py` | **25 / 25 通过**（敲击 → 看板闭环） |
| `check_web.py` | **40 / 40 通过** |
| `test_admin_api.py` | **42 / 42 通过** |
| `flutter test`（客户端） | **85 / 85 通过** |
| `flutter test integration/live_api_check.dart` | **11 / 11 通过**（真实客户端 ↔ 线上服务端） |

---

## 常用脚本

| 脚本 | 用途 |
|---|---|
| `ssh_client.py "<命令>"` | 远程执行一条命令 |
| `init_wid_db.py [--drop] [--show-secret]` | 数据库初始化 / 重建 / 查看密钥 |
| `deploy_wid_site.py [--no-nginx] [--force-config] [--dry-run]` | 部署 |
| `test_wid_api.py [--local-only\|--remote-only] [--filter 关键词] [--keep-data]` | 接口契约测试 |
| `test_dashboard_live.py [--filter 关键词] [--keep-data]` | **看板闭环测试**：用真实密钥走 launch → taps，断言看板数字真的增加了 |
| `test_admin_api.py [--local-only]` | 后台测试 |
| `check_web.py [-v]` | 网页检查（含 **PHP 源码泄露**断言） |
| `cleanup_live_device.py --list \| <device_id>` | 清理联调设备及其统计痕迹（会扣减增量并重算全量） |
| `check_dnssec.py [域名…] [--strict]` | **域名 DNSSEC 健康巡检**：抓「DS 与 DNSKEY 不匹配导致全站无法解析」这类静默故障；`--strict` 可用于监控 |
| `debug_sign.py` | 签名链路排查（本机 curl / 服务器 curl / 经 Cloudflare 三条路径比对） |

---

## 客户端接入

客户端（Flutter）已切到 v3：

- `lib/constants/app_config.dart`：`apiBaseUrl` / `appKey` / `appSecret`
- `lib/services/telemetry_service.dart`：HMAC 签名、批量攒报、心跳、更新检测、云同步、反馈与崩溃
- `lib/services/device_identity.dart`：匿名设备标识（本地随机生成并持久化）
- `lib/services/remote_config.dart`：服务端下发的运行时配置（本地缓存）
- `lib/models/update_check_result.dart`：更新检测结果（含强制更新与更新日志）

判断跨语言签名是否一致，最快的方法是跑一次：

```bash
flutter test integration/live_api_check.dart
```

它用**真实客户端代码**打线上接口，失败会直接告诉你签名或参数对不上。
跑完按提示用 `cleanup_live_device.py` 清理测试数据。

---

## 安全须知

- `src/app/` 已由 nginx 层封禁（`/app/` 整体 404），配置与 SQL 不会经 HTTP 泄露；
  `check_web.py` 会对所有页面断言「响应里不含 PHP 源码」。
- `app/config.php` 含数据库口令与会话密钥，权限 640、属主 `www:www`，**不进版本库**。
- 接口签名密钥（`app_secret`）硬编码在客户端里，只能防低成本伪造，**不能防逆向**；
  真正的风控靠限流与设备维度统计。
- 隐私立场：`device_id` 是本地随机生成的匿名标识而非硬件指纹；
  功德榜**默认不参与**且昵称打码；服务端**不存敲击明细**。
