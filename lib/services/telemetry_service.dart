import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../constants/app_config.dart';
import '../models/app_settings.dart';
import '../models/version_info.dart';

/// 匿名统计上报。
///
/// v2 在 `setState` 里直接发起上报请求，没有超时、没有吞异常，
/// 网络不通时会拖慢甚至阻塞敲击。这里统一改为「fire and forget」：
/// - [AppConfig.backendEnabled] 为 false（后端下线期间）时直接返回，不发任何请求；
/// - 所有请求都带超时，失败只记 debug 日志；
/// - 调用方拿到的 Future 永不抛异常。
class TelemetryService {
  TelemetryService({http.Client? client, Logger? logger})
    : _client = client ?? http.Client(),
      _logger = logger ?? Logger();

  final http.Client _client;
  final Logger _logger;

  bool _enabled(AppSettings settings) =>
      AppConfig.backendEnabled && settings.telemetryEnabled;

  /// 启动次数上报（v2 的 `Getadd`）
  Future<void> reportStartup(AppSettings settings) {
    return _guard(() => _safeGet(AppConfig.startupUri, settings, tag: 'startup'));
  }

  /// 在线人数上报（v2 的 `GetOnline`）
  Future<void> reportOnline(AppSettings settings) {
    return _guard(() => _safeGet(AppConfig.onlineUri, settings, tag: 'online'));
  }

  /// 敲击统计上报（v2 的 `Masterpost`）
  Future<void> reportTap({
    required AppSettings settings,
    required int tapCount,
  }) {
    return _guard(() {
      final body = <String, String>{
        'version': AppConfig.clientVersion,
        'appkey': AppConfig.appKey,
        'content': '$tapCount',
        'other': '${tapCount ~/ 100}',
        'color': settings.isLight ? 'black' : 'white',
      };
      return _safePost(AppConfig.statUri, settings, body: body, tag: 'tap');
    });
  }

  /// 拉取版本信息。用于「更多 -> 更新」页，失败时由调用方回退到本地缓存。
  Future<VersionInfo> fetchVersionInfo(AppSettings settings) async {
    final url = settings.releaseChannel
        ? AppConfig.releaseVersionUrl
        : AppConfig.betaVersionUrl;

    if (!_enabled(settings)) {
      _logger.d('统计后端已关闭，跳过版本检查');
      throw const _TelemetrySkipped('后端未启用');
    }

    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode != 200) {
        throw http.ClientException('HTTP ${response.statusCode}', Uri.parse(url));
      }
      return VersionInfo.fromJsonString(utf8.decode(response.bodyBytes));
    } catch (error) {
      _logger.w('拉取版本信息失败：$error');
      rethrow;
    }
  }

  void dispose() => _client.close();

  // ---- 内部实现 ----

  /// 把「连参数求值都可能出错」的情况也兜住。
  ///
  /// `_safeGet(AppConfig.startupUri, ...)` 里 URI 的构造发生在 `_safeGet`
  /// 的 try 之外，若 URI 拼错会直接抛出、绕过所有保护。
  /// 本类的契约是「永不抛异常」，因此入口统一再包一层。
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      _logger.d('上报任务异常（已忽略）：$error');
    }
  }

  Future<void> _safeGet(
    Uri uri,
    AppSettings settings, {
    required String tag,
  }) async {
    if (!_enabled(settings)) return;
    try {
      await _client.get(uri).timeout(AppConfig.requestTimeout);
    } catch (error) {
      _logger.d('[$tag] 上报失败（已忽略）：$error');
    }
  }

  Future<void> _safePost(
    Uri uri,
    AppSettings settings, {
    required Map<String, String> body,
    required String tag,
  }) async {
    if (!_enabled(settings)) return;
    try {
      await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
            body: body,
          )
          .timeout(AppConfig.requestTimeout);
    } catch (error) {
      _logger.d('[$tag] 上报失败（已忽略）：$error');
    }
  }
}

/// 后端未启用时抛出，调用方可据此区分「网络失败」与「功能关闭」
class _TelemetrySkipped implements Exception {
  const _TelemetrySkipped(this.reason);

  final String reason;

  @override
  String toString() => 'TelemetrySkipped: $reason';
}