import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/app_bootstrap.dart';
import 'state/providers.dart';
import 'state/settings_controller.dart';
import 'state/tap_counter_controller.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 启动序列全部 await 完成后再建界面：
  // 单实例判定 -> 读本地状态 -> 建窗 -> 预加载音效
  final bootstrap = await AppBootstrap.create(args);

  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(bootstrap.repository),
        windowServiceProvider.overrideWithValue(bootstrap.windowService),
        audioServiceProvider.overrideWithValue(bootstrap.audioService),
        telemetryServiceProvider.overrideWithValue(bootstrap.telemetryService),
        trayServiceProvider.overrideWithValue(bootstrap.trayService),
        hotkeyServiceProvider.overrideWithValue(bootstrap.hotkeyService),
        overlayGeometryProvider.overrideWithValue(bootstrap.geometry),
        settingsProvider.overrideWith(
          () => SettingsController(initial: bootstrap.settings),
        ),
        tapCounterProvider.overrideWith(
          () => TapCounterController(initial: bootstrap.tapCount),
        ),
      ],
      child: const PrueWidgetsApp(),
    ),
  );
}