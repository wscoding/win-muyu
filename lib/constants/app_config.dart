/// 后端与全局功能开关。
///
/// 注意：v2.x 使用的统计后端（`d.999087.com` / `zt.999087.com`）已经下线，
/// 这里的地址仅作为占位保留，方便后续重写接口时直接替换。
/// 接口约定见 `docs/backend-api.md`。
class AppConfig {
  const AppConfig._();

  /// 客户端上报时使用的版本号
  static const String clientVersion = '3.0.0';

  /// 应用标识，后端用它区分不同客户端
  static const String appKey = '8f23f05b4a50b6481ff020320692f9e9';

  /// 启动次数上报 + 在线人数
  static const String hostUrl = 'd.999087.com';

  /// 敲击统计上报
  static const String statHost = 'zt.999087.com';

  /// 敲击统计路径
  static const String statPath = '/app/muyu/repo.php';

  /// 版本信息（release 渠道）
  static const String releaseVersionUrl =
      'http://zt.999087.com/app/muyu/version.json';

  /// 版本信息（beta 渠道）
  static const String betaVersionUrl = 'http://code.iqg.cc/app/version.json';

  /// 后端整体开关。后端下线期间保持 `false`，此时所有网络上报都会被跳过，
  /// 不会产生任何无效请求，也不会拖慢敲击响应。
  static const bool backendEnabled = false;

  /// 单个网络请求的超时时间
  static const Duration requestTimeout = Duration(seconds: 5);

  static Uri get startupUri => Uri(
    scheme: 'http',
    host: hostUrl,
    path: '/api.php',
    queryParameters: {'type': 'add', 'appkey': appKey},
  );

  static Uri get onlineUri => Uri(
    scheme: 'http',
    host: hostUrl,
    path: '/api.php',
    queryParameters: {'type': 'addOnlineNumber', 'appkey': appKey},
  );

  static Uri get statUri =>
      Uri(scheme: 'http', host: statHost, path: statPath);
}