import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../services/audio_service.dart';
import '../services/hotkey_service.dart';
import '../services/settings_repository.dart';
import '../services/telemetry_service.dart';
import '../services/tray_service.dart';
import '../services/window/desktop_window_service.dart';
import 'settings_controller.dart';
import 'tap_counter_controller.dart';

/// 平台与基础设施服务的注入点。
///
/// 默认实现直接抛异常，强制在 `ProviderScope.overrides` 中注入真实实例
/// （见 `main.dart` 的 `AppBootstrap`）。测试里可以覆盖成假实现。
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError('settingsRepositoryProvider 必须在启动时注入'),
);

final audioServiceProvider = Provider<AudioService>(
  (ref) => throw UnimplementedError('audioServiceProvider 必须在启动时注入'),
);

final telemetryServiceProvider = Provider<TelemetryService>(
  (ref) => throw UnimplementedError('telemetryServiceProvider 必须在启动时注入'),
);

final windowServiceProvider = Provider<DesktopWindowService>(
  (ref) => throw UnimplementedError('windowServiceProvider 必须在启动时注入'),
);

final trayServiceProvider = Provider<TrayService>(
  (ref) => throw UnimplementedError('trayServiceProvider 必须在启动时注入'),
);

final hotkeyServiceProvider = Provider<HotkeyService>(
  (ref) => throw UnimplementedError('hotkeyServiceProvider 必须在启动时注入'),
);

/// 悬浮窗口的几何信息，由启动流程写入（用于计算提示气泡的偏移）
final overlayGeometryProvider = Provider<OverlayWindowGeometry?>((ref) => null);

/// 全部应用设置
final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// 敲击次数
final tapCounterProvider = NotifierProvider<TapCounterController, int>(
  TapCounterController.new,
);