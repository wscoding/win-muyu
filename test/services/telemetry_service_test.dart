import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prue_widgets/constants/app_config.dart';
import 'package:prue_widgets/models/app_settings.dart';
import 'package:prue_widgets/services/device_identity.dart';
import 'package:prue_widgets/services/remote_config.dart';
import 'package:prue_widgets/services/telemetry_service.dart';

// ---------------------------------------------------------------------------
// 构造响应的小工具
//
// ⚠️ 必须用 http.Response.bytes + 显式 charset：
//    http.Response(String, status) 在没有 charset 时按 **latin1** 编码，
//    响应里带中文（版本说明、错误文案）会直接抛 ArgumentError，
//    看起来像是"业务代码没处理"，其实是被测试桩坑了。
// ---------------------------------------------------------------------------

http.Response _jsonResponse(
  Object? body, {
  int status = 200,
  Map<String, String>? headers,
}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: headers ?? const <String, String>{'content-type': 'application/json; charset=utf-8'},
  );
}

/// `{ok:true, code:0, data:…}`
http.Response _okResponse(Object? data) => _jsonResponse(<String, dynamic>{
  'ok': true,
  'code': 0,
  'msg': 'ok',
  'ts': 1,
  'data': data,
});

/// `{ok:false, code:…, msg:…}`
http.Response _failResponse(int code, String msg, {int status = 200}) =>
    _jsonResponse(<String, dynamic>{
      'ok': false,
      'code': code,
      'msg': msg,
      'ts': 1,
    }, status: status);

void main() {
  late List<http.Request> sent;
  late TelemetryService service;

  /// 统计开启：远端上报的默认前置条件
  const optedIn = AppSettings(telemetryEnabled: true, releaseChannel: true);

  setUp(() {
    sent = <http.Request>[];
    service = _buildTelemetry(sent, (_) async => _okResponse(<String, dynamic>{}));
  });

  tearDown(() => service.dispose());

  group('AppConfig 的地址构造', () {
    test('api() 拼出完整路径，且与签名的 PATH 一致', () {
      final uri = AppConfig.api('/launch');
      expect(uri.toString(), '${AppConfig.apiBaseUrl}/launch');
      expect(uri.path, '/api/v1/launch');
      // 签名用的路径必须与真实请求路径一致，否则服务端验签必然失败
      expect(AppConfig.signPath('/launch'), uri.path);
    });

    test('查询参数会拼进 URL，且不影响签名路径', () {
      final uri = AppConfig.api('/version', <String, Object?>{
        'platform': 'windows',
        'channel': 'release',
        'current': AppConfig.clientVersion,
        'nul': null,
      });
      expect(uri.path, '/api/v1/version');
      expect(uri.queryParameters['platform'], 'windows');
      expect(
        uri.queryParameters.containsKey('nul'),
        isFalse,
        reason: '空值参数不应出现在 URL 里',
      );
    });

    test('后端地址是 HTTPS（v2 全明文属历史遗留）', () {
      expect(AppConfig.apiBaseUrl.startsWith('https://'), isTrue);
      expect(AppConfig.backendEnabled, isTrue);
      expect(AppConfig.appSecret.length, 64);
    });
  });

  /// 统计关闭：显式关掉才叫关，不能依赖默认值
  const optedOut = AppSettings(telemetryEnabled: false);

  group('接口关闭时的行为', () {
    test('telemetryEnabled=false 时不发任何请求', () async {
      await service.reportStartup(optedOut);
      await service.reportOnline(optedOut);
      await service.reportTap(settings: optedOut, tapCount: 10);
      await service.flushTaps();

      expect(sent, isEmpty);
    });

    test('fetchVersionInfo 在功能关闭时抛 TelemetrySkipped', () async {
      await expectLater(
        service.fetchVersionInfo(optedOut),
        throwsA(isA<TelemetrySkipped>()),
      );
    });

    test('默认设置是开启的（看板数据源）', () {
      expect(const AppSettings().telemetryEnabled, isTrue);
    });
  });

  group('请求签名', () {
    test('写接口携带完整签名头，且签名可被本地复算校验', () async {
      await service.reportStartup(optedIn);
      expect(sent, hasLength(1));

      final request = sent.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/launch');

      final appKey = request.headers['X-App-Key'];
      final timestamp = request.headers['X-Timestamp'];
      final nonce = request.headers['X-Nonce'];
      final signature = request.headers['X-Signature'];

      expect(appKey, AppConfig.appKey);
      expect(int.tryParse(timestamp!), isNotNull);
      expect(nonce!.length, 32);
      expect(signature!.length, 64);

      // 复算：METHOD\nPATH\nAPP_KEY\nTS\nNONCE\nSHA256(BODY)
      final bodyHash = sha256.convert(request.bodyBytes).toString();
      final canonical = <String>[
        'POST',
        request.url.path,
        appKey!,
        timestamp,
        nonce,
        bodyHash,
      ].join('\n');
      final expected = Hmac(sha256, utf8.encode(AppConfig.appSecret))
          .convert(utf8.encode(canonical))
          .toString();
      expect(signature, expected);
    });

    test('请求体是 JSON，且带上设备标识与会话标识', () async {
      await service.reportStartup(optedIn);
      final payload = jsonDecode(sent.single.body) as Map<String, dynamic>;
      expect(payload['device_id'], service.identity.deviceId);
      expect(payload['session_id'], service.identity.sessionId);
      expect(payload['platform'], 'windows');
      expect(payload['client_version'], AppConfig.clientVersion);
      expect(payload['channel'], 'release');
    });
  });

  group('批量敲击', () {
    test('空闲后的第一次敲击立即上报（敲一下看板就该动）', () async {
      final batching = _buildTelemetry(sent, (_) async => _okResponse(<String, dynamic>{}));
      addTearDown(batching.dispose);

      await batching.reportTap(settings: optedIn, tapCount: 1);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sent, hasLength(1), reason: '第一下就该发，否则用户看不到反馈');
      final payload = jsonDecode(sent.single.body) as Map<String, dynamic>;
      expect(payload['total'], 1);
    });

    test('最小间隔内的连击走攒报，不会每敲一下都发', () async {
      final batching = _buildTelemetry(sent, (_) async => _okResponse(<String, dynamic>{}));
      addTearDown(batching.dispose);

      await batching.reportTap(settings: optedIn, tapCount: 1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      sent.clear();

      // 自动敲击最低 150ms 一次，这几下都落在最小上报间隔内
      for (var i = 2; i <= 10; i++) {
        await batching.reportTap(settings: optedIn, tapCount: i);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sent, isEmpty, reason: '最小间隔内不该重复发请求（否则 QPS 回到 v2）');
    });

    test('攒够阈值后立即合并成一个请求', () async {
      final batching = _buildTelemetry(sent, (_) async => _okResponse(<String, dynamic>{}));
      addTearDown(batching.dispose);

      // 第 1 下立即发，之后攒够 20 下再发一次
      for (var i = 1; i <= 21; i++) {
        await batching.reportTap(settings: optedIn, tapCount: i);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sent, hasLength(2));
      final payload = jsonDecode(sent.last.body) as Map<String, dynamic>;
      expect(payload['total'], 21, reason: '上报的是累计值而非增量');
    });

    test('功德按每 100 次折算，与服务端口径一致', () async {
      final batching = _buildTelemetry(sent, (_) async => _okResponse(<String, dynamic>{}));
      addTearDown(batching.dispose);

      for (var i = 1; i <= 260; i++) {
        await batching.reportTap(settings: optedIn, tapCount: i);
      }
      await batching.flushTaps();

      final payload = jsonDecode(sent.last.body) as Map<String, dynamic>;
      expect(payload['total'], 260);
      expect(payload['merit'], 2);
    });

    test('flushTaps 可立刻发出（退出流程用）', () async {
      await service.reportTap(settings: optedIn, tapCount: 3);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sent, hasLength(1), reason: '空闲后第一下已经发过一次');
      await service.flushTaps();
      expect(sent, hasLength(2));
      final payload = jsonDecode(sent.last.body) as Map<String, dynamic>;
      expect(payload['total'], 3);
    });

    test('上报失败会重排定时器，不会把最后一批丢在内存里', () async {
      var attempts = 0;
      final failing = TelemetryService(
        identity: DeviceIdentity.forTest(),
        remoteConfig: RemoteConfig.empty(),
        client: MockClient((request) async {
          attempts++;
          return _failResponse(50001, '服务暂时不可用', status: 500);
        }),
      );
      addTearDown(failing.dispose);

      await failing.reportTap(settings: optedIn, tapCount: 7);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(attempts, 1);
      expect(failing.lastReportOk, isFalse);

      // 攒报间隔 3 秒，等它自动重试一次
      await Future<void>.delayed(const Duration(seconds: 4));
      expect(attempts, greaterThan(1), reason: '失败后应有一次自动重试');
    });
  });

  group('设备未注册的自愈', () {
    test('/taps 收到 409 时补一次 /launch 再重试', () async {
      final paths = <String>[];
      var tapsRejected = true;
      final healing = TelemetryService(
        identity: DeviceIdentity.forTest(),
        remoteConfig: RemoteConfig.empty(),
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/api/v1/taps' && tapsRejected) {
            tapsRejected = false;
            return _jsonResponse(
              <String, dynamic>{'ok': false, 'code': 40001, 'msg': '设备未注册'},
              status: 409,
            );
          }
          return _okResponse(<String, dynamic>{});
        }),
      );
      addTearDown(healing.dispose);

      await healing.reportTap(settings: optedIn, tapCount: 5);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(paths, contains('/api/v1/launch'), reason: '应当补发一次注册');
      expect(
        paths.where((path) => path == '/api/v1/taps').length,
        2,
        reason: '敲击应重试一次而不是被静默丢弃',
      );
      expect(healing.lastReportOk, isTrue);
    });

    test('补注册只做一次，失败后不再无限重试', () async {
      var launchCount = 0;
      final broken = TelemetryService(
        identity: DeviceIdentity.forTest(),
        remoteConfig: RemoteConfig.empty(),
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/launch') {
            launchCount++;
            return _okResponse(<String, dynamic>{});
          }
          return _jsonResponse(
            <String, dynamic>{'ok': false, 'code': 40001, 'msg': '设备未注册'},
            status: 409,
          );
        }),
      );
      addTearDown(broken.dispose);

      await broken.reportTap(settings: optedIn, tapCount: 5);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(launchCount, 1);
    });
  });

  group('请求失败不影响调用方', () {
    test('网络异常被吞掉', () async {
      final failing = _buildTelemetry(sent, (_) async => throw const _NetworkDown());
      addTearDown(failing.dispose);

      await expectLater(failing.reportStartup(optedIn), completes);
      await expectLater(failing.reportOnline(optedIn), completes);
      await expectLater(
        failing.reportTap(settings: optedIn, tapCount: 1),
        completes,
      );
      await expectLater(failing.flushTaps(), completes);
      await expectLater(failing.reportOffline(), completes);
    });

    test('非 200 与业务错误都被吞掉', () async {
      final failing = _buildTelemetry(
        sent,
        (_) async => _failResponse(42901, '请求过于频繁', status: 429),
      );
      addTearDown(failing.dispose);
      await expectLater(failing.reportStartup(optedIn), completes);

      final apiError = _buildTelemetry(
        sent,
        (_) async => _failResponse(40101, '签名校验失败'),
      );
      addTearDown(apiError.dispose);
      await expectLater(apiError.reportStartup(optedIn), completes);
    });

    test('响应不是 JSON 也不会抛给调用方', () async {
      final failing = _buildTelemetry(
        sent,
        (_) async => http.Response('<html>502</html>', 200),
      );
      addTearDown(failing.dispose);
      await expectLater(failing.reportStartup(optedIn), completes);
    });
  });

  group('启动响应会被采纳', () {
    test('运行配置、累计敲击、称号、公告都会更新到内存', () async {
      final rich = _buildTelemetry(
        sent,
        (_) async => _okResponse(<String, dynamic>{
          'server_taps': 1234,
          'title': <String, dynamic>{'title': '木鱼达人', 'level': 4},
          'config': <String, dynamic>{'tapBatchSize': 5, 'heartbeatInterval': 30},
          'announcements': <dynamic>[
            <String, dynamic>{'id': 1, 'title': '新后端已上线'},
          ],
        }),
      );
      addTearDown(rich.dispose);

      await rich.reportStartup(optedIn);

      expect(rich.serverTaps, 1234);
      expect(rich.deviceTitle, '木鱼达人');
      expect(rich.announcements, hasLength(1));
      expect(rich.remoteConfig.tapBatchSize, 5);
      expect(rich.remoteConfig.heartbeatSeconds, 30);
    });

    test('服务端配置的批量阈值会立即生效', () async {
      final rich = _buildTelemetry(
        sent,
        (_) async => _okResponse(<String, dynamic>{
          'config': <String, dynamic>{'tapBatchSize': 2},
        }),
      );
      addTearDown(rich.dispose);

      await rich.reportStartup(optedIn);
      sent.clear();

      await rich.reportTap(settings: optedIn, tapCount: 1);
      await rich.reportTap(settings: optedIn, tapCount: 2);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sent, hasLength(1), reason: '阈值改成 2 后第二次敲击就该上报');
    });
  });

  group('更新检测', () {
    test('解析 has_update / force_upgrade / 更新日志', () async {
      final updating = _buildTelemetry(
        sent,
        (_) async => _okResponse(<String, dynamic>{
          'platform': 'windows',
          'channel': 'release',
          'current': '3.0.0',
          'has_update': true,
          'force_upgrade': true,
          'update_type': 'minor',
          'reason': 'below_min_supported',
          'upgrade_tip': '发现功能更新 v3.1.0，本次为必要更新',
          'latest': <String, dynamic>{
            'version': '3.1.0',
            'build_number': '310',
            'appbuild': '2026-10-01',
            'newlog': '新增功德榜、修复 macOS 透明窗口问题',
            'download_url': 'https://wid.chr.cc/download',
            'file_size': 12345678,
            'file_hash': 'sha256:abc',
            'installer_store': '官网',
          },
          'changelog': <dynamic>[
            <String, dynamic>{
              'version': '3.1.0',
              'kind': 'feature',
              'title': '功德榜',
              'body': '新增功德榜\n修复若干问题',
              'released_at': '2026-10-01',
            },
          ],
        }),
      );
      addTearDown(updating.dispose);

      final result = await updating.fetchVersionInfo(optedIn);

      expect(result.hasUpdate, isTrue);
      expect(result.forceUpgrade, isTrue);
      expect(result.reason, 'below_min_supported');
      expect(result.updateTypeLabel, '功能更新');
      expect(result.latest.version, '3.1.0');
      expect(result.latest.buildNumber, '310');
      expect(result.latest.downloadUrl, 'https://wid.chr.cc/download');
      expect(result.latest.fileSizeLabel, '11.8 MB');
      expect(result.changelog, hasLength(1));
      expect(result.changelog.single.kindLabel, '功能');
      expect(result.changelog.single.bulletPoints, hasLength(2));
    });

    test('请求参数带上平台、渠道与当前版本', () async {
      final checking = _buildTelemetry(sent, (_) async => _okResponse(<String, dynamic>{}));
      addTearDown(checking.dispose);

      await checking.fetchVersionInfo(optedIn);
      var uri = sent.single.url;
      expect(uri.queryParameters['platform'], 'windows');
      expect(uri.queryParameters['current'], AppConfig.clientVersion);
      expect(uri.queryParameters['channel'], 'release');

      // 切换到测试版渠道后，参数随之变化
      await checking.fetchVersionInfo(
        const AppSettings(telemetryEnabled: true, releaseChannel: false),
      );
      uri = sent.last.url;
      expect(uri.queryParameters['channel'], 'beta');
    });

    test('失败时抛异常，供页面回退到本地缓存', () async {
      final broken = _buildTelemetry(
        sent,
        (_) async => _failResponse(50001, '服务暂时不可用', status: 500),
      );
      addTearDown(broken.dispose);
      await expectLater(
        broken.fetchVersionInfo(optedIn),
        throwsA(isA<TelemetryHttpException>()),
      );

      final apiError = _buildTelemetry(
        sent,
        (_) async => _failResponse(40401, '接口不存在'),
      );
      addTearDown(apiError.dispose);
      await expectLater(
        apiError.fetchVersionInfo(optedIn),
        throwsA(isA<TelemetryApiException>()),
      );
    });
  });

  group('其他接口', () {
    test('心跳与下线都走签名 POST', () async {
      await service.reportOnline(optedIn);
      await service.reportOffline();
      final paths = sent.map((request) => request.url.path).toList();
      expect(
        paths,
        containsAll(<String>['/api/v1/heartbeat', '/api/v1/offline']),
      );
      for (final request in sent) {
        expect(request.headers['X-Signature'], isNotNull);
      }
    });

    test('设置云同步返回服务端的 revision', () async {
      final syncing = _buildTelemetry(
        sent,
        (_) async => _okResponse(<String, dynamic>{
          'revision': 3,
          'conflict': false,
          'payload': <String, dynamic>{'volume': 0.5},
        }),
      );
      addTearDown(syncing.dispose);

      final result = await syncing.pushSettings(
        settings: optedIn,
        payload: <String, dynamic>{'volume': 0.5},
        baseRevision: 2,
      );
      expect(result?['revision'], 3);
      final body = jsonDecode(sent.last.body) as Map<String, dynamic>;
      expect(body['base_revision'], 2);
    });

    test('中文按 UTF-8 解析（v2 的乱码老问题）', () async {
      final chinese = _buildTelemetry(
        sent,
        (_) async => _okResponse(<String, dynamic>{'content': '心若不动，风又奈何。'}),
      );
      addTearDown(chinese.dispose);
      expect(await chinese.fetchBlessing(optedIn), '心若不动，风又奈何。');
    });
  });
}

/// 构造一个注入 MockClient 的服务
TelemetryService _buildTelemetry(
  List<http.Request> sent,
  Future<http.Response> Function(http.Request request) handler,
) {
  return TelemetryService(
    identity: DeviceIdentity.forTest(),
    remoteConfig: RemoteConfig.empty(),
    client: MockClient((request) async {
      sent.add(request);
      return handler(request);
    }),
  );
}

/// 模拟网络异常，避免直接依赖 dart:io 的 SocketException 构造签名
class _NetworkDown implements Exception {
  const _NetworkDown();

  @override
  String toString() => 'SocketException: 网络不可用';
}
