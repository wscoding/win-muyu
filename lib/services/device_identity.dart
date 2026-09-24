import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/pref_keys.dart';

/// 匿名设备身份。
///
/// **隐私立场**：`deviceId` 是客户端本地随机生成的 16 字节十六进制串，
/// 首次启动时生成、之后一直复用。它**不是**硬件指纹，服务端无法据此
/// 回溯到具体的人；重置应用数据就等于换了一台「新设备」。
///
/// `sessionId` 每次启动重新生成，用于服务端区分「同一次运行」，
/// 从而把在线时长算准（心跳超时也能自动离线）。
class DeviceIdentity {
  DeviceIdentity._({
    required this.deviceId,
    required this.sessionId,
    required this.isFirstLaunch,
    required this.platform,
    required this.osVersion,
  });

  /// 匿名设备标识（32 位十六进制）
  final String deviceId;

  /// 本次运行的会话标识（32 位十六进制）
  final String sessionId;

  /// 是否首次启动（仅用于日志与「新设备」埋点）
  final bool isFirstLaunch;

  /// 平台标识，取自窗口服务的平台抽象
  final String platform;

  /// 系统版本
  final String osVersion;

  static final Random _random = Random.secure();

  /// 生成 n 字节随机数的十六进制串
  static String randomHex(int bytes) {
    final buffer = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// 读取（或首次生成）设备标识。
  ///
  /// [platform] / [osVersion] 由 `DesktopWindowService` 提供，
  /// 避免在这一层再写平台判断。
  static Future<DeviceIdentity> load({
    required String platform,
    required String osVersion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(PrefKeys.deviceId) ?? '';
    var isFirstLaunch = false;

    // 校验历史值：格式不对（被改坏、或来自别的应用）就重新生成
    if (deviceId.length < 16 || !RegExp(r'^[0-9a-f]+$').hasMatch(deviceId)) {
      deviceId = randomHex(16);
      await prefs.setString(PrefKeys.deviceId, deviceId);
      isFirstLaunch = true;
    }

    return DeviceIdentity._(
      deviceId: deviceId,
      sessionId: randomHex(16),
      isFirstLaunch: isFirstLaunch,
      platform: platform,
      osVersion: osVersion,
    );
  }

  /// 供测试使用的构造入口（不落盘）
  factory DeviceIdentity.forTest({
    String deviceId = 'testdevice0000000000000000000000',
    String sessionId = 'testsession00000000000000000000',
    String platform = 'windows',
    String osVersion = '10.0.0',
  }) {
    return DeviceIdentity._(
      deviceId: deviceId,
      sessionId: sessionId,
      isFirstLaunch: false,
      platform: platform,
      osVersion: osVersion,
    );
  }
}
