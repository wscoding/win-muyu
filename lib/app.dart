import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'constants/app_constants.dart';
import 'models/app_settings.dart';
import 'services/app_lifecycle.dart';
import 'state/providers.dart';
import 'ui/wooden_fish_view.dart';
import 'utils/async_utils.dart';

/// 应用根。
///
/// 除了构建 `MaterialApp`，还负责串起托盘、全局快捷键，以及
/// 「设置变化 -> 音源重新加载」这类跨服务的副作用。
class PrueWidgetsApp extends ConsumerStatefulWidget {
  const PrueWidgetsApp({super.key});

  @override
  ConsumerState<PrueWidgetsApp> createState() => _PrueWidgetsAppState();
}

class _PrueWidgetsAppState extends ConsumerState<PrueWidgetsApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaitedSafely(_setupDesktopIntegrations());
    });
  }

  Future<void> _setupDesktopIntegrations() async {
    final windowService = ref.read(windowServiceProvider);
    final trayService = ref.read(trayServiceProvider);
    final hotkeyService = ref.read(hotkeyServiceProvider);

    Future<void> toggleVisibility() async {
      await windowService.toggleVisibility();
      await trayService.updateWindowVisible(await windowService.isVisible());
    }

    await trayService.initialize(
      onToggleVisibility: toggleVisibility,
      onResetCount: () => ref.read(tapCounterProvider.notifier).reset(),
      onQuit: () => shutdownApp(ref),
    );

    await hotkeyService.registerDefaults(
      onToggleVisibility: toggleVisibility,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 音源相关设置变化时重新加载音频通道
    ref.listen<AppSettings>(settingsProvider, (previous, next) {
      final sourceChanged = previous?.activeAudioSource != next.activeAudioSource;
      final rateChanged = previous?.speedMultiplier != next.speedMultiplier;
      if (sourceChanged || rateChanged) {
        unawaitedSafely(ref.read(audioServiceProvider).prepare(next));
      }
    });

    return ScreenUtilInit(
      designSize: AppConstants.designSize,
      builder: (context, _) => MaterialApp(
        title: 'Prue Widgets',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const WoodenFishView(),
      ),
    );
  }
}

/// 悬浮小部件本身是透明的，主题主要服务于设置面板
ThemeData buildAppTheme() {
  const seed = Color(0xFF8D6E63);
  final scheme = ColorScheme.fromSeed(seedColor: seed);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    visualDensity: VisualDensity.compact,
    listTileTheme: const ListTileThemeData(
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12),
    ),
  );
}