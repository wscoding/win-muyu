/// 后端与全局功能开关（接口 v3，站点 `https://wid.chr.cc`）。
///
/// 与 v2 的区别：
/// - 地址从明文 HTTP 换成 HTTPS；
/// - `appKey` 只作身份标识，真正的凭据是 [appSecret]（HMAC-SHA256 签名）；
/// - 上报不再是「每次敲击一个请求」，而是批量攒报（见
///   [tapBatchSize] / [tapBatchInterval]）；
/// - 心跳间隔、批量大小等运行参数由服务端下发，可随时改而无需发版
///   （见 `RemoteConfig`）。
///
/// 接口契约见 `docs/api-v3.md`（线上 `https://wid.chr.cc/docs`）。
class AppConfig {
  const AppConfig._();

  /// 客户端上报时使用的版本号
  static const String clientVersion = '3.0.0';

  /// 应用标识：公开值，随客户端分发，仅用于区分客户端
  static const String appKey = '8f23f05b4a50b6481ff020320692f9e9';

  /// HMAC-SHA256 签名密钥。
  ///
  /// 与服务端 `apps.app_secret` 对应。它硬编码在客户端里，
  /// 能防住「随便拿到 app_key 就能伪造上报」的低成本刷量，
  /// 但**不能防逆向**——真正的风控靠服务端限流与设备维度统计。
  static const String appSecret =
      '9ad6de90df1e5f8ee8aaed3653569c97cb66b5aec99b5c2b878263112a57d278';

  /// 接口根地址。签名里的 PATH 用的就是它的 path 部分（`/api/v1/xxx`）。
  static const String apiBaseUrl = 'https://wid.chr.cc/api/v1';

  /// 站点地址（下载页、数据看板等）
  static const String siteUrl = 'https://wid.chr.cc';

  /// 后端总开关。关闭后所有网络请求都会被短路。
  static const bool backendEnabled = true;

  /// 单个请求的超时时间。全部上报都是 fire-and-forget，
  /// 不会阻塞敲击响应；8 秒在桌面端弱网下足够。
  static const Duration requestTimeout = Duration(seconds: 8);

  // ---- 上报节奏的本地默认值（服务端可在 /config 里覆盖）----

  /// 心跳间隔：服务端以「120 秒内有过心跳」判定在线
  static const Duration heartbeatInterval = Duration(seconds: 60);

  /// 攒够多少次敲击立即上报
  static const int tapBatchSize = 20;

  /// 攒报的最长等待时间：即使没攒够也会定时发一次
  static const Duration tapBatchInterval = Duration(seconds: 3);

  /// 两次敲击上报之间的最小间隔。
  ///
  /// 存在的原因：客户端在「空闲后第一次敲击」会立即上报（用户敲一下就能在
  /// 看板上看到数字变化），但自动敲击最低 150ms 一次 —— 若没有这个下限，
  /// 连击时每一次都会命中「空闲即报」，QPS 会回到 v2 的 7/秒/人。
  /// 有了它，最坏情况也就是 1 req/s。
  static const Duration tapMinInterval = Duration(milliseconds: 1000);

  /// 每多少次敲击记 1 功德（与服务端口径一致）
  static const int meritPerTap = 100;

  /// 构造接口 Uri。`path` 形如 `/version`，
  /// 最终得到 `https://wid.chr.cc/api/v1/version`。
  static Uri api(String path, [Map<String, Object?>? query]) {
    final base = Uri.parse(apiBaseUrl);
    final params = <String, String>{};
    query?.forEach((key, value) {
      if (value != null) {
        params[key] = '$value';
      }
    });
    return base.replace(
      path: '${base.path}$path',
      queryParameters: params.isEmpty ? null : params,
    );
  }

  /// 签名用的请求路径，必须与 [api] 生成的完整路径一致
  static String signPath(String path) => '${Uri.parse(apiBaseUrl).path}$path';
}
