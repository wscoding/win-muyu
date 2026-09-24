# Prue Widgets 后端接口 v3

> 站点根地址：`https://wid.chr.cc`　·　接口前缀：`/api/v1`
> 本文档同时是站内 `/docs` 页面的内容源（文件位于 `app/content/api-v3.md`）。

## 1. 设计目标

| 目标 | 做法 |
|---|---|
| 高频敲击上报不能拖慢客户端 | 客户端**批量攒报**，服务端只写聚合口径，不存敲击明细 |
| 不能靠硬编码常量伪造上报 | `app_key` 只做身份标识，真正的凭据是 `app_secret` + HMAC-SHA256 签名 |
| 客户端不需要发版就能改行为 | 公告、功德语、功能开关、皮肤清单全部由服务端下发 |
| 弱网 / 断网不影响使用 | 写接口失败可静默丢弃，客户端本地累计，下次开机补报 |
| 出问题能定位 | 统一响应结构 + 统一错误码 + 服务端事件日志 |

## 2. 统一约定

### 2.1 响应结构

所有接口（含错误）都返回 UTF-8 JSON：

```json
{
  "ok": true,
  "code": 0,
  "msg": "ok",
  "ts": 1789000000,
  "data": { }
}
```

- `ok`：布尔，仅表示业务是否成功，与 HTTP 状态码一致；
- `code`：业务码，`0` 表示成功，非 0 见下表；
- `msg`：给人看的说明，可直接展示给用户；
- `ts`：服务端 unix 秒，客户端可据此校准时间（用于签名）；
- `data`：业务数据，错误响应中可能为 `null` 或携带 `detail`。

### 2.2 错误码

| code | HTTP | 含义 | 客户端建议处理 |
|---|---|---|---|
| `0` | 200 | 成功 | — |
| `40001` | 400 | 参数缺失或非法 | 修参数，不要重试 |
| `40101` | 401 | 签名不匹配 | 检查 `app_secret` 与待签名字符串拼装 |
| `40102` | 401 | 时间戳超出窗口（±300 秒） | 用响应里的 `ts` 校准本地时间后重试 |
| `40103` | 401 | nonce 重复（重放） | 换一个新 nonce 重试 |
| `40104` | 401 | app_key 不存在 | 检查客户端内置常量 |
| `40301` | 403 | app_key 已停用 | 提示用户升级客户端，不要重试 |
| `40401` | 404 | 接口不存在 | 检查版本兼容性 |
| `42901` | 429 | 请求过于频繁 | 读取 `Retry-After` 后再退避重试 |
| `50001` | 500 | 服务端异常 | 指数退避重试，最多 3 次 |

### 2.3 鉴权：HMAC-SHA256 签名

**公开只读接口**（`/version`、`/changelog`、`/downloads`、`/stats/*`、`/leaderboard`、`/profile`、`/blessing`、`/announcement`、`/config`、`/assets`、`/health`）可以匿名调用，仅按 IP 限流。
**写接口**（`/launch`、`/heartbeat`、`/offline`、`/taps`、`/feedback`、`/crash`、`/settings/*`、`/profile/opt-in`）必须携带完整签名。

请求头：

| 头 | 说明 |
|---|---|
| `X-App-Key` | 客户端标识（公开值） |
| `X-Timestamp` | 当前 unix 秒，字符串，与服务端偏差不超过 300 秒 |
| `X-Nonce` | 随机串，8–64 位，同一 `app_key` 下不可重复 |
| `X-Signature` | 64 位小写十六进制 HMAC-SHA256 |

待签名字符串由 6 行组成，行序固定、行尾不加空格：

```
METHOD
PATH
APP_KEY
TIMESTAMP
NONCE
SHA256_HEX(原始请求体)
```

`PATH` 是不含查询串的接口路径，例如 `/api/v1/taps`。
GET 请求体为空，最后一行固定为 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。

### 2.4 签名示例（Python）

```python
import hashlib, hmac, json, time, uuid, urllib.request

BASE = 'https://wid.chr.cc'
APP_KEY = '8f23f05b4a50b6481ff020320692f9e9'
APP_SECRET = '<在客户端内置的密钥>'
EMPTY_SHA256 = hashlib.sha256(b'').hexdigest()

def call(method, path, payload=None):
    body = json.dumps(payload, ensure_ascii=False, separators=(',', ':')).encode() if payload else b''
    ts = str(int(time.time()))
    nonce = uuid.uuid4().hex
    canonical = '\n'.join([
        method, path, APP_KEY, ts, nonce,
        hashlib.sha256(body).hexdigest() if body else EMPTY_SHA256,
    ])
    sign = hmac.new(APP_SECRET.encode(), canonical.encode(), hashlib.sha256).hexdigest()
    req = urllib.request.Request(
        BASE + path, data=body if body else None, method=method,
        headers={
            'Content-Type': 'application/json',
            'X-App-Key': APP_KEY,
            'X-Timestamp': ts,
            'X-Nonce': nonce,
            'X-Signature': sign,
        })
    with urllib.request.urlopen(req, timeout=8) as r:
        return json.loads(r.read().decode())

call('POST', '/api/v1/launch', {
    'device_id': 'a1b2c3d4e5f60718',
    'platform': 'windows',
    'client_version': '3.0.0',
})
```

### 2.5 限流

| 维度 | 默认上限 | 说明 |
|---|---|---|
| 单 IP | 240 次 / 分钟 | 公开只读接口与匿名访问 |
| 单（app × 设备） | 900 次 / 分钟 | 写接口，可由后台按 app 调整 |

超限返回 `429` + `42901`，并带 `Retry-After` 与 `X-RateLimit-*` 头。

## 3. 接口清单

### 3.1 生命周期

#### POST /api/v1/launch

每次启动调用一次：注册设备、累计启动数、建立在线会话，并**顺带下发**运行配置与公告。

| 字段 | 必填 | 说明 |
|---|---|---|
| `device_id` | 是 | 客户端本地生成并持久化的匿名标识，8–64 位字母数字、`_` 或 `-` |
| `platform` | 否 | `windows` / `macos` / `android` / `ios` |
| `os_version` | 否 | 系统版本，如 `10.0.26200` |
| `client_version` | 否 | 客户端版本，如 `3.0.0` |
| `channel` | 否 | `release` / `beta` |
| `color` | 否 | 木鱼配色 `black` / `white` |
| `session_id` | 否 | 本次运行实例的随机串；带上它才能建立在线会话 |

响应 `data`：

```json
{
  "server_time": "2026-09-23T04:30:00+08:00",
  "device": { "device_id": "a1b2c3d4e5f60718", "platform": "windows",
              "first_seen_at": "2026-09-23 04:30:00", "launch_count": 12, "status": 1 },
  "server_taps": 12345,
  "server_merit": 123,
  "new_session": true,
  "global": { "launches": 100, "taps": 900000, "merit": 9000, "online": 7, "devices": 42 },
  "title": { "level": 4, "title": "木鱼达人", "next_title": "敲鱼圣手", "next_at": 100000, "progress": 12 },
  "config": { "heartbeatInterval": 60, "tapBatchSize": 20 },
  "announcements": [ { "id": 1, "title": "新后端已上线", "level": "info" } ]
}
```

> `server_taps` 是**服务端**记录的累计值，与客户端本地计数是两套数字；客户端可用它做校准或展示"全网/本机"对比。

#### POST /api/v1/heartbeat

每分钟一次，刷新在线时间窗。字段：`device_id`（必填）、`session_id`、`client_version`。
服务端以「最后一次心跳在 120 秒内」判定在线，因此**客户端被强杀也会在 2 分钟内自动离线**，不需要可靠的退出上报。

#### POST /api/v1/offline

用户主动退出时调用。字段：`device_id`。只删除在线会话，不影响累计统计。

### 3.2 敲击统计

#### POST /api/v1/taps

| 字段 | 必填 | 说明 |
|---|---|---|
| `device_id` | 是 | 设备标识 |
| `delta` | 否 | 本次增量（客户端自己算的） |
| `total` | 否 | 客户端**当前累计**敲击数；给了它就以它为准 |
| `merit` | 否 | 客户端累计功德；不传则按 `total / 100` 向下取整推算 |
| `client_version` | 否 | 版本号 |
| `color` | 否 | 配色 |

服务端增量计算规则（抗丢包 / 抗乱序 / 抗重发）：

```
给了 total：delta = max(0, total - 上次快照)
只给 delta：delta = max(0, delta)
功德增量  = max(0, 本次功德 - 上次功德)
```

单次 `delta` 超过 `tap_delta_max`（默认 20000）会被截断并记录 `tap_clamped` 事件，防止脏数据污染总量。

响应 `data`：

```json
{
  "accepted": 20,
  "clamped": false,
  "server_time": "2026-09-23T04:30:00+08:00",
  "device": { "taps_total": 12345, "merit_total": 123, "taps_today": 1200 },
  "global": { "taps": 900020, "merit": 9000, "online": 7, "taps_today": 12000 },
  "title": { "level": 4, "title": "木鱼达人", "next_at": 100000, "progress": 12 }
}
```

> `global.taps_today` 是**全网今日**敲击，与看板同一个口径。客户端可以直接回显，
> 让用户不必打开网页也能确认自己的敲击确实上去了。

**设备未注册时返回 409**（`code` 仍为 `40001`）。客户端应当补一次 `/launch`
再重试同一批敲击 —— 启动上报偶尔失败（弱网、服务端抖动）时，
不这么做的话本次运行的所有敲击都会被静默丢弃。客户端只补一次，
补完仍失败就按普通失败处理（累计值语义保证下次能补回来）。

#### POST /api/v1/taps/batch

`items` 为数组（最多 500 条），每项可带 `delta` / `total` / `merit`。
服务端把整批合并成**一次**写库：有 `total` 的取最大值按累计口径算，其余 `delta` 相加。适合离线队列补报。

### 3.3 版本与更新检测

#### GET /api/v1/version

| 参数 | 说明 |
|---|---|
| `platform` | 省略时返回**所有平台**的最新版清单（下载页用） |
| `channel` | `release`（默认）/ `beta` |
| `current` | 客户端当前版本，用于计算是否需要更新 |

响应 `data`：

```json
{
  "platform": "windows",
  "channel": "release",
  "current": "3.0.0",
  "latest": {
    "version": "3.1.0",
    "build_number": "310",
    "build_signature": "2026-10-01",
    "appbuild": "2026-10-01",
    "installer_store": "官网",
    "newlog": "新增功德榜、修复 macOS 透明窗口问题",
    "download_url": "https://wid.chr.cc/download",
    "file_size": 12345678,
    "file_hash": "sha256:....",
    "min_supported_version": "3.0.0",
    "force_upgrade": false,
    "published_at": "2026-10-01 10:00:00"
  },
  "has_update": true,
  "update_type": "minor",
  "force_upgrade": false,
  "reason": "",
  "upgrade_tip": "发现功能更新 v3.1.0，建议升级体验",
  "changelog": [ { "version": "3.1.0", "kind": "feature", "title": "功德榜" } ],
  "announcements": [],
  "download_page": "https://wid.chr.cc/download"
}
```

`update_type`：`none` / `patch` / `minor` / `major` / `unknown`。
强制升级有两条路径，都由服务端判定，客户端只需读 `force_upgrade`：

1. 该版本发布时勾选了「强制更新」（`force_upgrade = true`）；
2. 当前版本低于该平台的 `min_supported_version`（用于淘汰旧协议）。

#### GET /api/v1/changelog

参数：`limit`（默认 20，最大 100）、`platform`、`version`。返回 `{ total, items[] }`。

#### GET /api/v1/downloads

返回按平台 / 渠道分组的最新版本清单，供下载页使用。

### 3.4 统计（公开只读）

| 接口 | 参数 | 返回 |
|---|---|---|
| `GET /stats/overview` | `days`、`range`、`limit` | **看板一次拿全**（见下），网页与客户端共用 |
| `GET /stats/summary` | `platform` | 累计启动 / 敲击 / 功德、在线、峰值、设备数、今日数据 |
| `GET /stats/trend` | `days`（1–180，默认 7）、`platform` | `{ totals, series[] }`，缺数据的日期补 0 |
| `GET /stats/breakdown` | — | 平台分布（设备 / 在线）、版本分布、总量 |
| `GET /leaderboard` | `range`（`day`/`week`/`month`/`all`）、`limit` | 功德榜，仅含 opt-in 设备，昵称打码 |
| `GET /profile` | `device_id` | 该设备的累计、今日、本周、连续天数、称号、排名 |

#### GET /api/v1/stats/overview

把上面四个接口合成一次返回，供网页看板整页 30 秒轮询使用。

| 参数 | 默认 | 说明 |
|---|---|---|
| `days` | 30 | 趋势天数（1–180） |
| `range` | `week` | 榜单口径（`day`/`week`/`month`/`all`） |
| `limit` | 20 | 榜单条数 |

```json
{
  "summary":     { "taps": 900000, "merit": 9000, "online": 7, "today": { "taps": 1200 } },
  "trend":       [{ "date": "2026-09-24", "launches": 3, "taps": 30, "devices": 1 }],
  "breakdown":   { "platforms": [], "versions": [], "devices": 42 },
  "leaderboard": { "range": "week", "items": [] },
  "generated_at": "2026-09-24T02:58:17+08:00"
}
```

> 为什么要有它：分开拉四个接口时，每个看板每 30 秒就是 4 次请求，
> 而且四个区块可能落在不同的统计瞬间，出现"数字对不上"的错位。
> 合并后请求量降到 1/4，且是同一时刻的快照。
> `summary` / `trend` / `breakdown` / `leaderboard` 的字段与各自独立接口完全一致。

#### POST /api/v1/profile/opt-in

开启 / 关闭功德榜。字段：`device_id`、`enabled`（布尔）、`nickname`（≤16 字）。
**默认不参与**；首次开启必须提供昵称。对外展示时昵称只保留首字符（`无书` → `无*`）。

### 3.5 内容与配置（公开只读）

| 接口 | 参数 | 说明 |
|---|---|---|
| `GET /blessing` | `device_id`、`category` | 带 `device_id` 时是「每日一签」（当日结果稳定、次日轮换）；不带则随机 |
| `GET /announcement` | `platform`、`client_version` | 当前生效的公告，支持版本区间与时间窗 |
| `GET /config` | `platform` | 运行时配置键值对，客户端本地默认值之上覆盖 |
| `GET /assets` | `platform`、`type`（`skin`/`sound`/`font`） | 皮肤 / 音效包清单，含下载地址与校验值 |

`category` 取值：`zen` 禅语、`merit` 功德、`humor` 摸鱼。

### 3.6 上报与同步

| 接口 | 字段 | 说明 |
|---|---|---|
| `POST /feedback` | `device_id`、`category`、`content`、`contact` | 用户反馈，落 `feedback` 表待后台处理 |
| `POST /crash` | `device_id`、`error_type`、`message`、`detail` | 崩溃上报；同一设备同一错误 10 分钟内只记一条并累加次数 |
| `POST /settings/pull` | `device_id` | 拉取云端设置 `{ revision, payload, updated_at }` |
| `POST /settings/push` | `device_id`、`payload`、`base_revision`、`force` | 推送设置；版本冲突返回 409 + 服务端最新值 |

`settings/push` 的并发策略是**乐观锁 + 明确回报**：`base_revision` 与服务端不一致时不写入，返回 409 与服务端当前值，由客户端决定合并还是 `force = true` 强制覆盖。
可同步的键见 `Wid\Model\Settings::ALLOWED_KEYS`（白名单，避免任意内容上传）。

### 3.7 健康检查

`GET /api/v1/health` —— 返回进程状态、PHP 版本、数据库可用性与当前在线数。不需要签名，可用于探活。

## 4. 数据与隐私

- 设备标识 `device_id` 由客户端本地随机生成，**不是硬件指纹**，服务端不采集任何可回溯到真人的信息；
- 服务端**不存储敲击明细**，只保留聚合总量与按日汇总；原始敲击序列始终留在客户端本地；
- 排行榜默认关闭，开启后昵称对外打码，且可随时退出；
- 在线人数用心跳时间窗统计，不依赖可靠的退出上报；
- 数据库账号仅授权 `127.0.0.1`，站点 `app/` 目录已在 nginx 层封禁外部访问。

## 5. 客户端接入清单

1. 首启动生成并持久化 `device_id`（建议 16 字节随机数的十六进制，如 `random_hex(8)` 的结果）；
2. 冷启动调用一次 `/launch`，把响应里的 `config` 落到本地配置、`announcements` 入队列展示；
3. 每 60 秒调用一次 `/heartbeat`（间隔可读 `config.heartbeatInterval`）；
4. 敲击按下面三条触发线中最先满足的那条上报 `/taps`，只传 `total`（客户端累计值）即可：
   - 攒够 `config.tapBatchSize` 次（连击主路径）；
   - **空闲后的第一次敲击立即上报** —— 用户敲一下就能在看板上看到数字变化；
   - 距上次上报超过 `config.tapBatchIntervalMs` 毫秒（兜底定时器）。

   其中第二条受 `config.tapMinIntervalMs`（默认 1000）约束：自动敲击最低 150ms 一次，
   没有这个下限的话每一次都会命中「空闲即报」，QPS 会退回 v2 的量级。
5. 上报失败不阻塞 UI，最多自动重试 3 次（间隔同 `tapBatchIntervalMs`）后停手等下次敲击；
   累计值语义保证丢包不需要补偿队列，下一次成功上报会自然把差额补上。
   若失败是 409（设备未注册），补一次 `/launch` 再重试（只补一次）；
6. 「更多 → 检查更新」调 `/version?platform=…&channel=…&current=…`，按 `force_upgrade` 决定是否可跳过；
7. 用户退出时调 `/offline`（可选，心跳超时也能兜底）。

## 6. 服务端扩展位

以下能力数据表与接口结构已经就位，接新功能不需要改表：

| 方向 | 现成的东西 | 下一步 |
|---|---|---|
| 账号体系 | `settings` 已按"命名空间"设计 | 把 `device_pk` 换成 `account_id`，接口签名不变 |
| 皮肤 / 音效市场 | `asset_packages` 表 + `/assets` | 增加上传审核与下载计数 |
| 会员 / 付费 | `apps` 支持多 app、`devices` 有 `status` | 加 `entitlements` 表 |
| 多端同账号 | `daily_active` 已按设备去重 | 加 `account_devices` 关联表 |
| 消息推送 | `announcements` 已支持版本区间 | 加长连接或系统通知桥 |
| 小时级热力图 | — | 新增 `hourly_stats`（当前刻意不写，保护磁盘 IO） |

## 7. 变更记录

### 2026-09-24（看板不刷新修复）

| 变更 | 说明 | 兼容性 |
|---|---|---|
| 新增 `GET /stats/overview` | 看板一次拿全 summary + trend + breakdown + leaderboard | 新增接口，不影响旧调用 |
| `/taps` 响应新增 `global.taps_today` | 全网今日敲击，与看板同口径，供客户端回显 | 纯新增字段 |
| `/taps` 的设备未注册改为 409 | 原为 409 但客户端静默丢弃，导致启动上报失败后整场敲击全丢 | 状态码未变，只是明确了客户端应补 `/launch` 重试 |
| 客户端匿名统计**默认开启** | v2 时代后端下线所以默认关闭；v3 上线后看板数据源全靠它 | 老用户若显式关过（`telemetryEnabled=false`）不会被升级改回来 |
| 客户端新增「空闲后首敲即报」 | 敲一下看板就能动；受 `tapMinIntervalMs` 约束，QPS 不回退 | 服务端无改动 |

修复前线上表现：`global_stats.taps` 长期为 0、`devices` 表为空 —— 接口本身是通的，
问题出在客户端默认不上报，且看板只有数字卡会 30 秒刷新（趋势图与表格永不更新）。
