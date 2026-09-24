import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../constants/app_config.dart';
import '../models/app_settings.dart';
import '../utils/async_utils.dart';
import 'audio_service.dart';
import 'device_identity.dart';
import 'hotkey_service.dart';
import 'remote_config.dart';
import 'settings_repository.dart';
import 'telemetry_service.dart';
import 'tray_service.dart';
import 'window/desktop_window_service.dart';

/// 启动阶段完成的工作，向外暴露已就绪的依赖与初始状态。
///
/// v2 的 `main()` 是「先 `runApp`，再在后台悄悄初始化」：
/// `Config.initWindow()` 与 `TapCounter.initialize()` 都没有 await，
/// 于是首帧经常抛 `LateInitializationError`，窗口也会先闪一下默认位置。
/// 这里改成显式 await 的启动序列，全部就绪后再 `runApp`。
///
/// 各 provider 的 override 在 `main.dart` 中组装——`Override` 类型
/// 没有被 `flutter_riverpod` 公开导出，放在那里可以由参数类型自动推断。
class AppBootstrap {
  const AppBootstrap({
    required this.settings,
    required this.tapCount,
    required this.geometry,
    required this.repository,
    required this.windowService,
    required this.audioService,
    required this.telemetryService,
    required this.trayService,
    required this.hotkeyService,
    required this.logger,
  });

  final AppSettings settings;
  final int tapCount;
  final OverlayWindowGeometry geometry;

  final SettingsRepository repository;
  final DesktopWindowService windowService;
  final AudioService audioService;
  final TelemetryService telemetryService;
  final TrayService trayService;
  final HotkeyService hotkeyService;
  final Logger logger;

  static Future<AppBootstrap> create(List<String> args) async {
    final logger = createAppLogger();

    final repository = SettingsRepository(logger: logger);
    final windowService = DesktopWindowService.create(logger: logger);
    final audioService = AudioService(logger: logger);
    final trayService = TrayService(logger: logger);
    final hotkeyService = HotkeyService(logger: logger);

    // 1. 单实例：非首个实例会在这里唤起已有窗口后退出
    await windowService.ensureSingleInstance(args);

    // 2. 读取本地状态（内部包含 v2 -> v3 的键迁移）
    final settings = await repository.load();
    final tapCount = await repository.loadTapCount();

    // 2.5 后端接入所需的本地身份与运行配置。
    //     设备标识本地随机生成并持久化（不是硬件指纹），
    //     运行配置用上次服务端下发的缓存，离线也能用。
    final remoteConfig = await RemoteConfig.load();
    final identity = await DeviceIdentity.load(
      platform: windowService.platformSlug,
      osVersion: windowService.osVersionLabel,
    );
    final telemetryService = TelemetryService(
      identity: identity,
      remoteConfig: remoteConfig,
      logger: logger,
    );
    logger.i(
      '设备标识 ${identity.deviceId.substring(0, 8)}…（平台 ${identity.platform}）'
      '${identity.isFirstLaunch ? '，首次启动' : ''}',
    );

    // 3. 建窗：窗口选项必须在 runApp 之前应用
    final geometry = await windowService.showOverlayWindow();

    // 4. macOS 上关掉 file_picker 的 App Sandbox entitlement 预检。
    //
    // 本应用刻意不启用 App Sandbox（本地音源要能读用户手输的任意路径，
    // 见 macos/Runner/*.entitlements），因此没有声明
    // com.apple.security.files.user-selected.read-only/read-write。
    // file_picker_darwin 2.1.2 起会在弹窗前校验这两个 entitlement，
    // 非沙盒应用不跳过就会被误拦，报 ENTITLEMENT_NOT_FOUND。
    // 其他平台与 iOS 上是 no-op，所以可以无条件调用。
    try {
      await FilePicker.skipEntitlementsChecks();
      logger.d('已跳过 file_picker 的 macOS entitlement 预检');
    } catch (error) {
      // 只有「选择文件」功能受影响，不该阻断启动
      logger.w('跳过 file_picker entitlement 检查失败：$error');
    }

    // 5. 预加载音效，避免第一次敲击有明显延迟
    await audioService.prepare(settings);

    // 6. 启动上报（后端关闭时内部直接短路，不会发出请求）
    unawaitedSafely(telemetryService.reportStartup(settings));

    logger.i(
      '启动完成：版本 ${AppConfig.clientVersion}，敲击次数 $tapCount，'
      '皮肤 ${settings.imageName}，音源 ${settings.audioSourceType.label}，'
      '快捷键 ${hotkeyService.toggleVisibilityLabel}',
    );

    return AppBootstrap(
      settings: settings,
      tapCount: tapCount,
      geometry: geometry,
      repository: repository,
      windowService: windowService,
      audioService: audioService,
      telemetryService: telemetryService,
      trayService: trayService,
      hotkeyService: hotkeyService,
      logger: logger,
    );
  }
}

/// release 下只留警告以上，debug 下带格式化输出
Logger createAppLogger() {
  return Logger(
    level: kReleaseMode ? Level.warning : Level.debug,
    printer: kReleaseMode ? SimplePrinter() : PrettyPrinter(methodCount: 0),
  );
}