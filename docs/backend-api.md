# 后端接口约定

> 状态：**v2 的后端已下线，接口待重写。**
> 客户端当前 `AppConfig.backendEnabled = false`，所有上报被短路，
> 不会发出任何请求。本文档记录客户端**期望**的接口形态，作为重写时的契约。

## 客户端侧开关

全部集中在 [lib/constants/app_config.dart](../lib/constants/app_config.dart)：

| 常量 | 含义 |
|---|---|
| `backendEnabled` | 总开关。`false` 时所有请求直接跳过 |
| `hostUrl` | 启动次数 / 在线人数域名（v2: `d.999087.com`） |
| `statUrl` | 敲击统计地址（v2: `zt.999087.com/app/muyu/repo.php`） |
| `releaseVersionUrl` / `betaVersionUrl` | 版本信息 JSON |
| `appKey` | 客户端标识，随请求发送 |
| `clientVersion` | 客户端版本号 |
| `requestTimeout` | 单请求超时（当前 5 秒） |

另有用户侧的 `settings.telemetryEnabled` 开关（默认 `false`）。
**两个开关都为真时才会真正发请求。**

## 客户端行为保证

重写后端时不需要考虑以下情况，客户端已自行处理：

- 请求超时（5 秒）后放弃，不重试、不阻塞 UI
- 任何异常（网络失败、非 200、JSON 解析失败）都被吞掉，只写 debug 日志
- 敲击上报是 fire-and-forget，与敲击响应完全解耦
- 版本信息请求失败时回退到本地缓存

因此：**接口可以放心地返回错误或不可用，不会导致客户端崩溃或卡顿。**

## 接口一：启动次数

```
GET http://{hostUrl}/api.php?type=add&appkey={appKey}
```

- 每次应用启动上报一次
- 响应体内容客户端不解析，只要 HTTP 200 即可
- v2 语义：累加一次启动计数

## 接口二：在线人数

```
GET http://{hostUrl}/api.php?type=addOnlineNumber&appkey={appKey}
```

- 启动后上报一次，用于「当前在线」统计
- 响应体内容客户端不解析

## 接口三：敲击统计

```
POST http://{statUrl}
Content-Type: application/x-www-form-urlencoded
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `version` | string | 客户端版本号 |
| `appkey` | string | 客户端标识 |
| `content` | string | 当前累计敲击次数（十进制字符串） |
| `other` | string | 累计功德数 = `content / 100` 向下取整 |
| `color` | string | 木鱼配色，`black` 或 `white` |

- **每次敲击上报一次**，客户端不做节流。高频自动敲击（最低 150ms 一次）
  下 QPS 可达约 7/秒/用户。重写时建议后端做合并或限流。
- 响应体内容客户端不解析，只要 HTTP 200 即可
- v2 用 `utf8.decode(response.bodyBytes)` 解码，返回体应为 UTF-8 JSON

> 备注：`content` 传的是**累计值**而非增量，因此后端可以直接覆盖，
> 无需依赖请求顺序。若要做「全网敲击次数」，注意区分用户维度与总量维度。

## 接口四：版本信息

```
GET {releaseVersionUrl}   或   {betaVersionUrl}
```

返回单个 JSON 对象（客户端用 `VersionInfo.fromJson` 解析）：

```json
{
  "appName": "Prue Widgets",
  "version": "3.0.0",
  "packageName": "cc.iqg.prueWidgets",
  "buildNumber": "300",
  "buildSignature": "2026-09-23",
  "installerStore": "官网",
  "appbuild": "2026-09-23",
  "newlog": "重构、支持 macOS",
  "download": "https://example.com/download"
}
```

| 字段 | 客户端用途 |
|---|---|
| `appName` | 展示应用名 |
| `version` | 展示服务端版本号 |
| `packageName` | 展示包名 |
| `buildNumber` | 展示构建号 |
| `buildSignature` | 展示构建标识 |
| `installerStore` | 展示分发渠道 |
| `appbuild` | 展示构建日期 |
| `newlog` | 展示更新日志 |
| `download` | 「打开下载页」按钮的目标 URL |

- 所有字段缺失时按空字符串处理，**不会解析失败**
- 客户端会缓存该 JSON（键 `data`），解析失败时清掉缓存并回退
- 两个渠道的区别由用户设置 `releaseChannel` 决定（release / beta）

## 建议的改进方向

重写时可以顺带解决 v2 的几个问题：

1. **统一错误响应格式**，便于客户端区分「业务错误」与「网络错误」。
2. **敲击上报改为批量**：客户端可积累 N 次或 T 秒后一次性提交数组，
   降低 QPS。需要同步改 `TelemetryService.reportTap`。
3. **用 HTTPS**。v2 全部是明文 HTTP，`appkey` 与统计内容都可被中间人读取。
4. **`appkey` 不应作为唯一鉴权手段**。它是硬编码在客户端里的公开值，
   任何人都可以伪造上报。若要防刷，需要引入签名或设备指纹。
5. **区分「匿名统计」与「用户数据」**。当前 `content` 是个人的累计敲击数，
   属于可关联的行为数据。若只做总量统计，建议改为只上报增量或
   在上报前做本地聚合。

## 接入新后端的步骤

1. 修改 `lib/constants/app_config.dart` 里的地址常量
2. 把 `backendEnabled` 改为 `true`
3. 如需调整请求格式，改 `lib/services/telemetry_service.dart`
4. 若要让老用户自动开启上报，需同步调整
   `SettingsRepository.load()` 中 `telemetryEnabled` 的默认值
5. 跑 `flutter test` —— `test/services/settings_repository_test.dart`
   与 `test/state/controllers_test.dart` 覆盖了上报开关的行为