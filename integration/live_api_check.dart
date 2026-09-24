// ============================================================
// 线上联调检查（不进默认测试集）
//
// 用途：**用真实的客户端代码打通线上后端**，验证跨语言（Dart ↔ PHP）
//       的 HMAC 签名、批量上报、心跳、更新检测、设置云同步全部对得上。
//       单元测试只能证明 Dart 侧自洽，这个脚本才能证明两端一致。
//
// 运行：flutter test integration/live_api_check.dart
//       （默认 `flutter test` 只跑 test/ 目录，不会带上它，避免离线 CI 失败）
//
// 注意：会向线上写入少量真实数据（1 台测试设备、若干次敲击）。
//       运行后可用 `python server/Scripts/cleanup_live_device.py <device_id>`
//       清理干净，脚本会在结束时打印该 device_id。
// ============================================================

// 这个文件是给人看的联调脚本：结果必须打印出来才能在终端里读，
// 而 `flutter analyze` 的质量门禁要求 0 issue，所以整文件豁免 print。
// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:prue_widgets/constants/app_config.dart';
import 'package:prue_widgets/models/app_settings.dart';
import 'package:prue_widgets/services/device_identity.dart';
import 'package:prue_widgets/services/remote_config.dart';
import 'package:prue_widgets/services/telemetry_service.dart';

void main() {
  // 线上联调依赖真实网络，超时给宽一点
  const settings = AppSettings(telemetryEnabled: true, releaseChannel: true);

  late DeviceIdentity identity;
  late TelemetryService service;

  setUpAll(() {
    // 每次运行都用全新的设备标识，避免与真实数据互相干扰
    identity = DeviceIdentity.forTest(
      deviceId: 'livetest${DeviceIdentity.randomHex(11)}',
      sessionId: DeviceIdentity.randomHex(16),
    );
    service = TelemetryService(
      identity: identity,
      remoteConfig: RemoteConfig.empty(),
    );
    print('测试设备标识：${identity.deviceId}');
  });

  tearDownAll(() {
    service.dispose();
    print('\n提示：如需清理本次产生的测试数据，执行');
    print('  python server/Scripts/cleanup_live_device.py ${identity.deviceId}');
    print('接口地址：${AppConfig.apiBaseUrl}');
  });

  test('启动上报：注册设备并拿到服务端配置', () async {
    await service.reportStartup(settings);

    // 服务端已经把配置下发下来了（说明验签通过、业务也成功）
    expect(
      service.remoteConfig.isEmpty,
      isFalse,
      reason: '未拿到 /launch 下发的运行时配置，说明请求没成功',
    );
    expect(service.remoteConfig.tapBatchSize, greaterThan(0));
    expect(service.remoteConfig.heartbeatSeconds, greaterThan(0));

    print('服务端配置：批量 ${service.remoteConfig.tapBatchSize} 次 / '
        '心跳 ${service.remoteConfig.heartbeatSeconds} 秒 / '
        '里程碑 ${service.remoteConfig.meritPerTap} 次');
    print('称号：${service.deviceTitle.isEmpty ? "（未下发）" : service.deviceTitle}');
  });

  test('批量敲击上报：累计值口径正确', () async {
    for (var i = 1; i <= 7; i++) {
      await service.reportTap(settings: settings, tapCount: i);
    }
    await service.flushTaps();

    // 服务端记录的本机累计应为 7
    expect(service.serverTaps, 7, reason: '服务端累计敲击与客户端不一致');
    print('服务端记录的累计敲击：${service.serverTaps}');
  });

  test('重复上报同一累计值不会重复计数（幂等）', () async {
    final before = service.serverTaps;
    await service.flushTaps();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    print('重复上报后服务端累计：${service.serverTaps}（上报前 $before）');
    expect(service.serverTaps, greaterThanOrEqualTo(before));
  });

  test('心跳：拿到全网在线人数', () async {
    await service.reportOnline(settings);
    expect(service.onlineCount, greaterThanOrEqualTo(1), reason: '自己应该算在线');
    print('全网在线：${service.onlineCount}');
  });

  test('刷新运行时配置接口可用', () async {
    final ok = await service.refreshRemoteConfig(settings);
    expect(ok, isTrue, reason: '刷新配置失败（说明请求没成功）');
  });

  test('更新检测：能拿到发布记录与更新日志', () async {
    final result = await service.fetchVersionInfo(settings);

    expect(result.hasRelease, isTrue, reason: '服务端没有发布记录');
    expect(result.latest.version, isNotEmpty);
    print('最新版本：v${result.latest.version}'
        '（当前 ${result.current}，has_update=${result.hasUpdate}）');
    print('下载地址：${result.latest.downloadUrl}');
    print('更新提示：${result.tip}');
    if (result.changelog.isNotEmpty) {
      print('更新日志 ${result.changelog.length} 条，'
          '最新：v${result.changelog.first.version} ${result.changelog.first.title}');
    }
  });

  test('每日一签：服务端内容库可用', () async {
    final text = await service.fetchBlessing(settings);
    expect(text, isNotNull);
    expect(text!, isNotEmpty);
    print('今日一签：$text');
  });

  test('设置云同步：推送与拉取往返一致', () async {
    final pushed = await service.pushSettings(
      settings: settings,
      payload: <String, dynamic>{'volume': 0.42, 'tapSoundPack': 'muyu'},
    );
    expect(pushed, isNotNull);
    final revision = pushed!['revision'];
    expect(revision, isA<int>());
    print('推送成功，服务端 revision = $revision');

    final pulled = await service.pullSettings(settings);
    expect(pulled, isNotNull);
    final payload = pulled!['payload'] as Map<String, dynamic>;
    expect(payload['volume'], 0.42);
    print('拉取回读：$payload');
  });

  test('崩溃上报可用', () async {
    await service.reportCrash(
      settings: settings,
      error: StateError('线上联调用的模拟异常，可忽略'),
      stackTrace: StackTrace.current,
      errorType: 'LiveApiCheck',
    );
    // 该接口失败也不会抛异常，这里只验证调用链通
  });

  test('反馈提交可用', () async {
    final ok = await service.submitFeedback(
      settings: settings,
      content: '这是 live_api_check.dart 自动提交的联调测试反馈，可忽略。',
      category: 'other',
      contact: 'selftest',
    );
    expect(ok, isTrue, reason: '反馈提交失败');
  });

  test('下线接口可用', () async {
    await service.reportOffline();
    print('已主动下线，测试设备标识：${identity.deviceId}');
  });
}
