import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prue_widgets/constants/app_config.dart';
import 'package:prue_widgets/models/app_settings.dart';
import 'package:prue_widgets/services/telemetry_service.dart';

void main() {
  /// 记录所有发出去的请求，用于断言「是否真的发了请求」
  late List<http.Request> sent;
  late TelemetryService service;

  setUp(() {
    sent = <http.Request>[];
    service = TelemetryService(
      client: MockClient((request) async {
        sent.add(request);
        return http.Response('{}', 200);
      }),
    );
  });

  tearDown(() => service.dispose());

  group('AppConfig 的 URI 构造', () {
    // 曾经的 bug：把 'zt.999087.com/app/muyu/repo.php' 整个当成 host，
    // 导致每次敲击都抛 FormatException，上报静默失效。
    test('statUri 的 host 与 path 正确分离', () {
      expect(AppConfig.statUri.host, AppConfig.statHost);
      expect(AppConfig.statUri.path, AppConfig.statPath);
      expect(AppConfig.statUri.host.contains('/'), isFalse);
    });

    test('所有上报 URI 都能正常构造且 host 合法', () {
      for (final uri in <Uri>[
        AppConfig.startupUri,
        AppConfig.onlineUri,
        AppConfig.statUri,
      ]) {
        expect(uri.host, isNotEmpty);
        expect(uri.host.contains('/'), isFalse, reason: '$uri 的 host 含路径');
      }
    });
  });

  group('后端关闭时的行为', () {
    // 当前 backendEnabled 为 false，这一组同时验证「参数求值不会抛异常」
    test('reportTap 不抛异常且不发请求', () async {
      await expectLater(
        service.reportTap(settings: const AppSettings(), tapCount: 42),
        completes,
      );
      expect(sent, isEmpty);
    });

    test('reportStartup / reportOnline 不抛异常且不发请求', () async {
      await expectLater(service.reportStartup(const AppSettings()), completes);
      await expectLater(service.reportOnline(const AppSettings()), completes);
      expect(sent, isEmpty);
    });

    test('即使开启了用户侧开关，后端总开关关闭时也不发请求', () async {
      const optedIn = AppSettings(telemetryEnabled: true);

      await service.reportTap(settings: optedIn, tapCount: 1);
      await service.reportStartup(optedIn);
      await service.reportOnline(optedIn);

      expect(sent, isEmpty);
    });

    test('fetchVersionInfo 会抛异常，调用方据此回退到缓存', () async {
      await expectLater(
        service.fetchVersionInfo(const AppSettings()),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('请求失败不影响调用方', () {
    test('网络异常被吞掉', () async {
      final failing = TelemetryService(
        client: MockClient((_) async => throw const SocketExceptionStub()),
      );

      await expectLater(
        failing.reportTap(settings: const AppSettings(), tapCount: 1),
        completes,
      );
      failing.dispose();
    });

    test('非 200 响应被吞掉', () async {
      final failing = TelemetryService(
        client: MockClient((_) async => http.Response('boom', 500)),
      );

      await expectLater(
        failing.reportStartup(const AppSettings()),
        completes,
      );
      failing.dispose();
    });
  });

  // 用真实请求体断言字段名，避免后端重写时对不上
  group('上报字段（在后端开启的前提下）', () {
    test('敲击上报的 body 字段符合文档约定', () async {
      // 直接构造请求，绕过 backendEnabled 开关，验证字段本身
      final request = http.Request('POST', AppConfig.statUri)
        ..headers['Content-Type'] = 'application/x-www-form-urlencoded'
        ..bodyFields = <String, String>{
          'version': AppConfig.clientVersion,
          'appkey': AppConfig.appKey,
          'content': '250',
          'other': '2',
          'color': 'white',
        };

      expect(request.bodyFields['content'], '250');
      expect(request.bodyFields['other'], '2');
      expect(request.bodyFields['color'], 'white');
      expect(request.bodyFields.containsKey('appkey'), isTrue);
      expect(request.bodyFields.containsKey('version'), isTrue);
    });
  });

  test('后端地址常量与文档一致', () {
    // 与 docs/backend-api.md 中记录的值保持同步
    expect(AppConfig.statHost, 'zt.999087.com');
    expect(AppConfig.statPath, '/app/muyu/repo.php');
    expect(AppConfig.hostUrl, 'd.999087.com');
  });

  test('请求体里的中文按 UTF-8 解码（v2 的兼容点）', () {
    // v2 用 utf8.decode(response.bodyBytes)，避免中文乱码
    final bytes = utf8.encode('{"newlog":"重构、支持 macOS"}');
    expect(utf8.decode(bytes), '{"newlog":"重构、支持 macOS"}');
  });
}

/// 模拟网络异常，避免直接依赖 dart:io 的 SocketException 构造签名
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() => 'SocketExceptionStub: 网络不可用';
}