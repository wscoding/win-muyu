import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../constants/app_config.dart';
import '../models/app_settings.dart';
import '../models/update_check_result.dart';
import '../utils/async_utils.dart';
import 'device_identity.dart';
import 'remote_config.dart';

/// 后端通信（接口 v3，站点 https://wid.chr.cc）。
///
/// 设计要点：
/// - **永不阻塞敲击**。所有写接口都是 fire-and-forget，调用方拿到的
///   Future 永不抛异常，异常只写 debug 日志。
/// - **批量攒报**。v2 每次敲击发一个请求（自动敲击 150ms 一次 → 约 7 QPS/人），
///   这里改成攒够 N 次或等 T 毫秒再发一次，QPS 降到个位数。
/// - **累计值语义让重试变成免费**。上报的是「客户端当前累计敲击数」而非增量，
///   所以丢包/失败都不需要补偿队列：下一次成功上报自然把差额补上，
///   服务端也天然幂等（重复上报同一 total 只记 0 增量）。
/// - **签名鉴权**。`app_key` 只作身份标识，请求头带
///   `X-App-Key / X-Timestamp / X-Nonce / X-Signature`（HMAC-SHA256）。
///   签名算法见 `docs/api-v3.md`，与服务端 `Wid\Core\Sign` 一一对应。
class TelemetryService {
  TelemetryService({
    required DeviceIdentity identity,
    RemoteConfig? remoteConfig,
    http.Client? client,
    Logger? logger,
  })  : _identity = identity,
        _config = remoteConfig ?? RemoteConfig.empty(),
        _client = client ?? http.Client(),
        _logger = logger ?? Logger();

  final DeviceIdentity _identity;
  final RemoteConfig _config;
  final http.Client _client;
  final Logger _logger;

  AppSettings _settings = const AppSettings();

  Timer? _flushTimer;
  Timer? _heartbeatTimer;
  int _pendingTaps = 0;
  int _latestTotal = 0;
  bool _disposed = false;

  /// 上次真正发出敲击上报的时刻，用于「最小上报间隔」限流
  DateTime? _lastFlushAt;

  /// 本轮是否已经因为「设备未注册」补发过 /launch。
  /// 补一次就够 —— 补完还失败说明是别的问题，不该无限重试。
  bool _launchRetried = false;

  /// 连续失败的重试次数（成功或达到上限时归零）
  int _retryCount = 0;
  static const int _maxRetries = 3;

  // ---- 服务端返回的、界面可能用到的信息 ----

  /// 服务端记录的本机累计敲击（与本地计数是两套数字）
  int serverTaps = 0;

  /// 全网在线人数（最近一次心跳/上报返回的值）
  int onlineCount = 0;

  /// 全网累计敲击（最近一次上报/心跳返回的值；看板同口径）
  int globalTaps = 0;

  /// 全网今日敲击（最近一次上报返回的值）
  int globalTodayTaps = 0;

  /// 最近一次上报是否成功。`null` = 还没上报过。
  ///
  /// 给设置页做「同步状态」展示用 —— 敲击看不出是否上报成功，
  /// 而用户第一个疑问永远是「我的数据到底上去没有」。
  bool? lastReportOk;

  /// 最近一次上报的时间
  DateTime? lastReportAt;

  /// 服务端按累计敲击给出的称号（如「木鱼达人」）
  String deviceTitle = '';

  /// 服务端下发的公告（原样透出，界面自行决定怎么展示）
  List<Map<String, dynamic>> announcements = <Map<String, dynamic>>[];

  DeviceIdentity get identity => _identity;
  RemoteConfig get remoteConfig => _config;

  bool _enabled(AppSettings settings) =>
      AppConfig.backendEnabled && settings.telemetryEnabled;

  /// 把最新的设置同步进来。
  ///
  /// 心跳定时器需要「当前设置」才能判断用户是否关掉了上报，
  /// 而服务层拿不到 Riverpod 容器，所以由调用方在设置变化时喂进来
  /// （见 `app.dart` 的设置变更副作用）。
  void setSettings(AppSettings settings) {
    _settings = settings;
    // 用户在设置里重新打开统计后，心跳要能自己恢复
    if (_enabled(settings) && _heartbeatTimer == null) {
      _startHeartbeat();
    }
  }

  // ============================================================
  // 生命周期
  // ============================================================

  /// 启动上报（`POST /launch`）。
  ///
  /// 一次请求完成四件事：注册设备、累加启动数、建立在线会话，
  /// **顺带下发**运行时配置与公告 —— 冷启动只花一个请求。
  Future<void> reportStartup(AppSettings settings) {
    return _guard(() async {
      // setSettings 内部会在统计开启时拉起心跳
      setSettings(settings);
      if (!_enabled(settings)) {
        return;
      }

      final data = await _post('/launch', <String, dynamic>{
        'device_id': _identity.deviceId,
        'platform': _identity.platform,
        'os_version': _identity.osVersion,
        'client_version': AppConfig.clientVersion,
        'channel': settings.releaseChannel ? 'release' : 'beta',
        'color': settings.isLight ? 'black' : 'white',
        'session_id': _identity.sessionId,
      });

      if (data == null) {
        return;
      }
      await _adoptLaunchPayload(data);
    });
  }

  /// 消化 /launch 的返回：运行配置、累计值、称号、公告
  Future<void> _adoptLaunchPayload(Map<String, dynamic> data) async {
    final rawConfig = data['config'];
    if (rawConfig is Map) {
      await _config.apply(rawConfig.cast<String, dynamic>());
      // 服务端可能改了心跳间隔，按新值重启定时器
      _startHeartbeat();
    }

    final taps = data['server_taps'];
    if (taps is num) {
      serverTaps = taps.toInt();
    }
    final title = data['title'];
    if (title is Map && title['title'] != null) {
      deviceTitle = title['title'].toString();
    }
    final list = data['announcements'];
    if (list is List) {
      announcements = list
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList(growable: false);
    }

    _logger.d(
      '启动上报完成：服务端累计 $serverTaps 次'
      '${deviceTitle.isEmpty ? '' : '，称号 $deviceTitle'}'
      '${announcements.isEmpty ? '' : '，公告 ${announcements.length} 条'}',
    );
  }

  /// 心跳（`POST /heartbeat`）。服务端以「120 秒内有心跳」判定在线。
  Future<void> reportOnline(AppSettings settings) {
    return _guard(() async {
      setSettings(settings);
      if (!_enabled(settings)) {
        return;
      }
      final data = await _post('/heartbeat', <String, dynamic>{
        'device_id': _identity.deviceId,
        'session_id': _identity.sessionId,
        'client_version': AppConfig.clientVersion,
      });
      final online = data == null ? null : data['online'];
      if (online is num) {
        onlineCount = online.toInt();
      }
    });
  }

  /// 主动下线（`POST /offline`）。只是立刻把本机从在线列表移除；
  /// 不调用也行 —— 心跳超时同样会自动离线。
  Future<void> reportOffline() {
    return _guard(() async {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      await _sendTaps();
      if (!_enabled(_settings)) {
        return;
      }
      await _post('/offline', <String, dynamic>{
        'device_id': _identity.deviceId,
      });
    });
  }

  /// 启动心跳定时器（幂等）。会在 /launch 拿到服务端配置后按新间隔重启。
  void _startHeartbeat() {
    if (_disposed) {
      return;
    }
    _heartbeatTimer?.cancel();
    final seconds = _config.heartbeatSeconds;
    _heartbeatTimer = Timer.periodic(Duration(seconds: seconds), (_) {
      unawaitedSafely(reportOnline(_settings));
    });
    _logger.d('心跳已启动，间隔 $seconds 秒');
  }

  // ============================================================
  // 敲击上报（批量）
  // ============================================================

  /// 记录一次敲击。**立即返回**，真正的网络请求由攒报队列发出。
  ///
  /// [tapCount] 是客户端当前的**累计**敲击数（不是增量）。
  ///
  /// 攒报策略有三条触发线，取最先满足的那条：
  /// 1. 攒够 [RemoteConfig.tapBatchSize] 次 —— 连击时的主路径；
  /// 2. **空闲后的第一次敲击立即上报** —— 用户敲一下就能在看板上看到变化，
  ///    这是「敲了没反应」类反馈的直接解法；
  /// 3. 距上次上报超过 [RemoteConfig.tapBatchIntervalMs] —— 兜底定时器。
  ///
  /// 其中第 2 条受 [RemoteConfig.tapMinIntervalMs] 约束：自动敲击最低
  /// 150ms 一次，没有这个下限的话每一次都会命中「空闲即报」，
  /// QPS 会退回 v2 的量级。
  Future<void> reportTap({required AppSettings settings, required int tapCount}) {
    setSettings(settings);
    // 先判空闲：_pendingTaps 在 _sendTaps 里清零，所以「上一次已发完」
    // 就等价于「现在处于空闲」，不需要额外维护状态机
    final wasIdle = _pendingTaps == 0 && _flushTimer == null;
    _pendingTaps++;
    if (tapCount > _latestTotal) {
      _latestTotal = tapCount;
    }
    if (!_enabled(settings) || _disposed) {
      return Future<void>.value();
    }

    if (_pendingTaps >= _config.tapBatchSize) {
      unawaitedSafely(flushTaps());
      return Future<void>.value();
    }

    if (wasIdle && _quietEnough()) {
      // 空闲后的第一下立即发，让「敲一下看板就动」成立
      unawaitedSafely(flushTaps());
      return Future<void>.value();
    }

    _flushTimer ??= Timer(
      Duration(milliseconds: _config.tapBatchIntervalMs),
      () => unawaitedSafely(flushTaps()),
    );
    return Future<void>.value();
  }

  /// 距上次上报是否已超过最小间隔
  bool _quietEnough() {
    final last = _lastFlushAt;
    if (last == null) {
      return true;
    }
    return DateTime.now().difference(last) >=
        Duration(milliseconds: _config.tapMinIntervalMs);
  }

  /// 立即把攒下的敲击发出去（退出前、或界面主动刷新时调用）。
  Future<void> flushTaps() => _guard(_sendTaps);

  Future<void> _sendTaps() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    final pending = _pendingTaps;
    _pendingTaps = 0;

    final settings = _settings;
    if (!_enabled(settings) || _latestTotal <= 0 || _disposed) {
      return;
    }

    final total = _latestTotal;
    // 记录**发起**时间而不是成功时间：连击时上一次请求可能还在飞，
    // 若等它回来再记，中间这几下都会误判成「空闲」而各自发一次请求。
    _lastFlushAt = DateTime.now();
    final payload = <String, dynamic>{
      'device_id': _identity.deviceId,
      'total': total,
      'merit': total ~/ _config.meritPerTap,
      'client_version': AppConfig.clientVersion,
      'color': settings.isLight ? 'black' : 'white',
    };

    Map<String, dynamic>? data;
    try {
      data = await _post('/taps', payload);
    } catch (error) {
      // 409 = 设备未注册。启动时的 /launch 若失败过（弱网、服务端抖动），
      // 本次运行的所有敲击都会被静默丢弃 —— 补一次注册再重试就能自愈。
      // 只补一次：补完还失败就是别的问题，不该无限重试。
      if (error is TelemetryHttpException &&
          error.statusCode == 409 &&
          !_launchRetried) {
        _launchRetried = true;
        _logger.d('敲击被拒（设备未注册），补发一次 /launch 后重试');
        await reportStartup(settings);
        try {
          data = await _post('/taps', payload);
        } catch (_) {
          data = null;
        }
      }
    }

    if (data == null) {
      // 失败不影响正确性：total 是累计值，下次上报会带上全部差额。
      // 但要重排一次定时器 —— 否则用户敲完最后一下就停手的话，
      // 这批数据要等下次敲击才会补发。
      _markReport(false);
      _scheduleRetry();
      return;
    }

    _launchRetried = false;
    _markReport(true);

    final device = data['device'];
    if (device is Map && device['taps_total'] is num) {
      serverTaps = (device['taps_total'] as num).toInt();
    }
    final global = data['global'];
    if (global is Map) {
      if (global['online'] is num) {
        onlineCount = (global['online'] as num).toInt();
      }
      if (global['taps'] is num) {
        globalTaps = (global['taps'] as num).toInt();
      }
      if (global['taps_today'] is num) {
        globalTodayTaps = (global['taps_today'] as num).toInt();
      }
    }
    _logger.d('敲击上报：本次 $pending 次，累计 $total，服务端记为 $serverTaps');
  }

  /// 上报失败后重排一次定时器（退避到攒报间隔，不做指数增长：
  /// 敲击是累计口径，重试失败也只是晚几秒看到数字）。
  ///
  /// 连续失败 [_maxRetries] 次就停手，等下一次敲击再带上来 ——
  /// 否则服务端长时间不可用时，空闲的客户端会一直空转重试。
  void _scheduleRetry() {
    if (_disposed || _flushTimer != null || _latestTotal <= 0) {
      return;
    }
    if (_retryCount >= _maxRetries) {
      _retryCount = 0;
      return;
    }
    _retryCount++;
    _flushTimer = Timer(
      Duration(milliseconds: _config.tapBatchIntervalMs),
      () => unawaitedSafely(flushTaps()),
    );
  }

  void _markReport(bool ok) {
    lastReportOk = ok;
    lastReportAt = DateTime.now();
    if (ok) {
      _retryCount = 0;
    }
  }

  // ============================================================
  // 看板 / 功德榜 / 本机档案
  // ============================================================

  /// 拉取看板全量数据（`GET /stats/overview`）。
  ///
  /// 与网页版看板同一个接口 —— 客户端展示的「全网今日」必须与网页上
  /// 看到的数字一致，否则用户会以为上报丢了。
  Future<Map<String, dynamic>?> fetchOverview({
    int trendDays = 30,
    String leaderboardRange = 'week',
  }) {
    return _guardReturning<Map<String, dynamic>?>(() async {
      final uri = AppConfig.api('/stats/overview', <String, Object?>{
        'days': trendDays,
        'range': leaderboardRange,
        'limit': 20,
      });
      final response = await _client.get(uri).timeout(AppConfig.requestTimeout);
      return _decode(response, uri);
    }, null);
  }

  /// 拉取功德榜（`GET /leaderboard`）。返回 `items` 列表，失败返回 null。
  Future<List<Map<String, dynamic>>> fetchLeaderboard({
    String range = 'week',
    int limit = 20,
  }) async {
    final data = await _guardReturning<Map<String, dynamic>?>(() async {
      final uri = AppConfig.api('/leaderboard', <String, Object?>{
        'range': range,
        'limit': limit,
      });
      final response = await _client.get(uri).timeout(AppConfig.requestTimeout);
      return _decode(response, uri);
    }, null);
    final items = data?['items'];
    if (items is! List) return const <Map<String, dynamic>>[];
    return items
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);
  }

  /// 拉取本机档案（`GET /profile`）：称号、名次、是否上榜。
  Future<Map<String, dynamic>?> fetchProfile() {
    return _guardReturning<Map<String, dynamic>?>(() async {
      final uri = AppConfig.api('/profile', <String, Object?>{
        'device_id': _identity.deviceId,
      });
      final response = await _client.get(uri).timeout(AppConfig.requestTimeout);
      return _decode(response, uri);
    }, null);
  }

  /// 开启 / 关闭功德榜并设置昵称（`POST /profile/opt-in`）。
  ///
  /// 返回服务端回传的 profile；失败返回 null。
  /// 开启了统计但设备还没注册时会返回 null，调用方应先确保 /launch 成功。
  Future<Map<String, dynamic>?> setLeaderboardOptIn({
    required AppSettings settings,
    required bool enabled,
    String nickname = '',
  }) {
    return _guardReturning<Map<String, dynamic>?>(() async {
      setSettings(settings);
      if (!_enabled(settings)) {
        return null;
      }
      return _post('/profile/opt-in', <String, dynamic>{
        'device_id': _identity.deviceId,
        'enabled': enabled,
        'nickname': nickname,
      });
    }, null);
  }

  // ============================================================
  // 更新检测 / 内容 / 配置
  // ============================================================

  /// 检查更新（`GET /version`）。
  ///
  /// 与写接口不同，这里**会把异常抛给调用方**：更新页需要在失败时
  /// 回退到本地缓存，并告诉用户「当前展示的是缓存」。
  Future<UpdateCheckResult> fetchVersionInfo(AppSettings settings) async {
    setSettings(settings);
    if (!_enabled(settings)) {
      throw const TelemetrySkipped('后端未启用或用户关闭了统计');
    }
    final uri = AppConfig.api('/version', <String, Object?>{
      'platform': _identity.platform,
      'channel': settings.releaseChannel ? 'release' : 'beta',
      'current': AppConfig.clientVersion,
    });
    final response = await _client.get(uri).timeout(AppConfig.requestTimeout);
    final data = _decode(response, uri);
    return UpdateCheckResult.fromJson(data ?? const <String, dynamic>{});
  }

  /// 拉取每日一签（`GET /blessing`）。失败返回 null，由界面回退。
  Future<String?> fetchBlessing(AppSettings settings) async {
    setSettings(settings);
    if (!_enabled(settings)) {
      return null;
    }
    try {
      final uri = AppConfig.api('/blessing', <String, Object?>{
        'device_id': _identity.deviceId,
      });
      final response = await _client.get(uri).timeout(AppConfig.requestTimeout);
      final data = _decode(response, uri);
      final content = data == null ? null : data['content'];
      return content?.toString();
    } catch (error) {
      _logger.d('拉取每日一签失败（已忽略）：$error');
      return null;
    }
  }

  /// 主动刷新运行时配置（`GET /config`）。通常在打开设置面板时调用。
  Future<bool> refreshRemoteConfig(AppSettings settings) {
    return _guardReturning<bool>(() async {
      final uri = AppConfig.api('/config', <String, Object?>{
        'platform': _identity.platform,
      });
      final response = await _client.get(uri).timeout(AppConfig.requestTimeout);
      final data = _decode(response, uri);
      final raw = data == null ? null : data['config'];
      if (raw is! Map) {
        return false;
      }
      await _config.apply(raw.cast<String, dynamic>());
      return true;
    }, false);
  }

  // ============================================================
  // 反馈 / 崩溃 / 设置同步
  // ============================================================

  /// 提交反馈（`POST /feedback`）。返回是否成功，供界面提示。
  Future<bool> submitFeedback({
    required AppSettings settings,
    required String content,
    String category = 'other',
    String contact = '',
  }) {
    return _guardReturning<bool>(() async {
      setSettings(settings);
      if (!_enabled(settings)) {
        throw const TelemetrySkipped('后端未启用或用户关闭了统计');
      }
      final data = await _post('/feedback', <String, dynamic>{
        'device_id': _identity.deviceId,
        'category': category,
        'content': content,
        'contact': contact,
        'client_version': AppConfig.clientVersion,
        'platform': _identity.platform,
        'os_version': _identity.osVersion,
      });
      return data != null;
    }, false);
  }

  /// 崩溃上报（`POST /crash`）。同设备同错误在服务端 10 分钟内只记一条。
  Future<void> reportCrash({
    required AppSettings settings,
    required Object error,
    StackTrace? stackTrace,
    String errorType = 'DartException',
  }) {
    return _guard(() async {
      setSettings(settings);
      if (!_enabled(settings)) {
        return;
      }
      await _post('/crash', <String, dynamic>{
        'device_id': _identity.deviceId,
        'error_type': errorType,
        'message': '$error',
        'detail': stackTrace?.toString() ?? '',
        'client_version': AppConfig.clientVersion,
        'platform': _identity.platform,
        'os_version': _identity.osVersion,
      });
    });
  }

  /// 拉取云端设置（`POST /settings/pull`）
  Future<Map<String, dynamic>?> pullSettings(AppSettings settings) {
    return _guardReturning<Map<String, dynamic>?>(() async {
      setSettings(settings);
      if (!_enabled(settings)) {
        return null;
      }
      return _post('/settings/pull', <String, dynamic>{
        'device_id': _identity.deviceId,
      });
    }, null);
  }

  /// 推送云端设置（`POST /settings/push`）。
  ///
  /// 服务端用乐观锁：`baseRevision` 与服务器当前 revision 不一致时返回
  /// 409 并把服务器版本带回来（不做静默覆盖），这里把结果原样返回，
  /// 由调用方决定合并还是 [force] 覆盖。
  Future<Map<String, dynamic>?> pushSettings({
    required AppSettings settings,
    required Map<String, dynamic> payload,
    int baseRevision = 0,
    bool force = false,
  }) {
    return _guardReturning<Map<String, dynamic>?>(() async {
      setSettings(settings);
      if (!_enabled(settings)) {
        return null;
      }
      return _post('/settings/push', <String, dynamic>{
        'device_id': _identity.deviceId,
        'payload': payload,
        'base_revision': baseRevision,
        'force': force,
      });
    }, null);
  }

  // ============================================================
  // 传输与签名
  // ============================================================

  /// 空请求体的 SHA256，与 PHP 端 `Sign::EMPTY_BODY_HASH` 一致
  static final String _emptyBodyHash = sha256.convert(const <int>[]).toString();

  /// 生成签名请求头。待签名字符串见 `docs/api-v3.md`：
  ///
  /// ```
  /// METHOD
  /// PATH
  /// APP_KEY
  /// TIMESTAMP
  /// NONCE
  /// SHA256_HEX(BODY)
  /// ```
  Map<String, String> _signedHeaders(String method, String path, List<int> body) {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final nonce = DeviceIdentity.randomHex(16);
    final bodyHash = body.isEmpty ? _emptyBodyHash : sha256.convert(body).toString();
    final canonical = <String>[
      method.toUpperCase(),
      path,
      AppConfig.appKey,
      timestamp,
      nonce,
      bodyHash,
    ].join('\n');
    final signature = Hmac(sha256, utf8.encode(AppConfig.appSecret))
        .convert(utf8.encode(canonical))
        .toString();

    return <String, String>{
      'X-App-Key': AppConfig.appKey,
      'X-Timestamp': timestamp,
      'X-Nonce': nonce,
      'X-Signature': signature,
      'Accept': 'application/json',
    };
  }

  /// 带签名的 POST，返回响应里的 `data`（可能为 null）
  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> payload) async {
    final uri = AppConfig.api(path);
    final body = utf8.encode(jsonEncode(payload));
    final headers = _signedHeaders('POST', AppConfig.signPath(path), body)
      ..['Content-Type'] = 'application/json';
    final response = await _client
        .post(uri, headers: headers, body: body)
        .timeout(AppConfig.requestTimeout);
    return _decode(response, uri);
  }

  /// 解析统一响应结构 `{ok, code, msg, ts, data}`
  Map<String, dynamic>? _decode(http.Response response, Uri uri) {
    // 中文必须按 UTF-8 解，否则版本说明会乱码（v2 的老问题）
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw TelemetryHttpException(uri, response.statusCode, text);
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('响应不是 JSON 对象：$text');
    }
    if (decoded['ok'] != true) {
      throw TelemetryApiException(
        decoded['code'] is int ? decoded['code'] as int : -1,
        decoded['msg']?.toString() ?? '接口返回失败',
      );
    }
    final data = decoded['data'];
    return data is Map<String, dynamic> ? data : null;
  }

  // ============================================================
  // 异常兜底
  // ============================================================

  /// 吞掉一切异常（fire-and-forget 接口的统一入口）
  Future<void> _guard(Future<void> Function() action) async {
    if (_disposed) {
      return;
    }
    try {
      await action();
    } catch (error) {
      _logger.d('上报任务异常（已忽略）：$error');
    }
  }

  /// 同 [_guard]，但需要一个返回值
  Future<T> _guardReturning<T>(Future<T> Function() action, T fallback) async {
    if (_disposed) {
      return fallback;
    }
    try {
      return await action();
    } catch (error) {
      _logger.d('上报任务异常（已忽略）：$error');
      return fallback;
    }
  }

  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _heartbeatTimer?.cancel();
    _client.close();
  }
}

/// 后端未启用 / 用户关闭了统计时抛出。
///
/// 公开这个类型是为了让调用方把「功能关闭」和「网络失败」分开提示。
class TelemetrySkipped implements Exception {
  const TelemetrySkipped(this.reason);

  final String reason;

  @override
  String toString() => 'TelemetrySkipped: $reason';
}

/// HTTP 层失败（非 200）
class TelemetryHttpException implements Exception {
  const TelemetryHttpException(this.uri, this.statusCode, this.body);

  final Uri uri;
  final int statusCode;
  final String body;

  @override
  String toString() => 'TelemetryHttpException: HTTP $statusCode @ $uri';
}

/// 业务层失败（`ok != true`），携带服务端给的用户可读文案
class TelemetryApiException implements Exception {
  const TelemetryApiException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'TelemetryApiException($code): $message';
}
