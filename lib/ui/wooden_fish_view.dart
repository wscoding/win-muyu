import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../constants/asset_catalog.dart';
import '../models/merit_text.dart';
import '../state/providers.dart';
import '../utils/async_utils.dart';
import 'menu_page.dart';
import 'widgets/merit_toast.dart';

/// 悬浮在桌面上的木鱼本体。
///
/// 交互（沿用 v2）：
/// - 左键单击：功德 +1，播放音效并飘出提示
/// - 左键长按：黑 / 白图案切换
/// - 右键单击：打开设置菜单
/// - 按住拖动：移动窗口（无边框窗口需要手动触发拖动）
class WoodenFishView extends ConsumerStatefulWidget {
  const WoodenFishView({super.key});

  @override
  ConsumerState<WoodenFishView> createState() => _WoodenFishViewState();
}

class _WoodenFishViewState extends ConsumerState<WoodenFishView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  Timer? _autoTapTimer;
  int _autoTapIntervalMs = 0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: AppConstants.tapAnimationDuration,
    );
    _scaleAnimation = Tween<double>(
      begin: AppConstants.tapAnimationBegin,
      end: AppConstants.tapAnimationEnd,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticInOut,
        reverseCurve: Curves.easeOut,
      ),
    );
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reverse();
      }
    });

    final settings = ref.read(settingsProvider);
    _syncAutoTap(
      enabled: settings.autoTapEnabled,
      intervalMs: settings.autoTapIntervalMs,
    );

    // 启动后补一次「在线人数」，v2 是在右键时顺手发的
    unawaitedSafely(ref.read(telemetryServiceProvider).reportOnline(settings));
  }

  @override
  void dispose() {
    _autoTapTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  /// 让自动敲击的开关与间隔跟随设置。
  ///
  /// v2 的「帮我敲」是：开启后任意一次点击都会启动一个永不停止的定时器，
  /// 只能靠再次点击才会停；这里改为开关打开就持续自动敲、关闭即停，
  /// 手动点击永远只敲一次。
  void _syncAutoTap({required bool enabled, required int intervalMs}) {
    if (!enabled) {
      _autoTapTimer?.cancel();
      _autoTapTimer = null;
      _autoTapIntervalMs = intervalMs;
      return;
    }

    if (_autoTapTimer != null && _autoTapIntervalMs == intervalMs) return;

    _autoTapTimer?.cancel();
    _autoTapIntervalMs = intervalMs;
    _autoTapTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _performTap(),
    );
  }

  /// 一次完整的敲击：计数 -> 音效 -> 动画 -> 提示 -> 上报
  void _performTap() {
    if (!mounted) return;

    final settings = ref.read(settingsProvider);
    final counter = ref.read(tapCounterProvider.notifier);
    counter.increment();
    final count = ref.read(tapCounterProvider);

    unawaitedSafely(ref.read(audioServiceProvider).playTap(settings));

    _animationController.forward(from: 0);

    MeritToast.show(
      context,
      text: MeritText.forTapCount(tapCount: count, settings: settings),
      textColor: settings.isLight ? Colors.black : Colors.white,
    );

    unawaitedSafely(
      ref
          .read(telemetryServiceProvider)
          .reportTap(settings: settings, tapCount: count),
    );
  }

  Future<void> _toggleIsLight() async {
    await ref.read(settingsProvider.notifier).toggleIsLight();
  }

  Future<void> _openMenu() async {
    final windowService = ref.read(windowServiceProvider);
    final navigator = Navigator.of(context);

    // 悬浮窗只有屏幕高度的 15%，直接推进菜单会挤成一团
    await windowService.enterPanelMode();
    try {
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const MenuPage(),
          fullscreenDialog: true,
        ),
      );
    } finally {
      await windowService.exitPanelMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final tapCount = ref.watch(tapCounterProvider);

    // 只订阅自动敲击相关字段：皮肤、文案、上报开关等变化不会把这里叫醒
    ref.listen(
      settingsProvider.select(
        (settings) => (
          enabled: settings.autoTapEnabled,
          intervalMs: settings.autoTapIntervalMs,
        ),
      ),
      (_, next) =>
          _syncAutoTap(enabled: next.enabled, intervalMs: next.intervalMs),
    );

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _performTap,
            onLongPress: _toggleIsLight,
            onSecondaryTap: _openMenu,
            onPanStart: (_) => ref.read(windowServiceProvider).startDragging(),
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) => Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final edge = constraints.biggest.shortestSide;
                  final size = edge * AppConstants.fishSizeRatio;
                  return _FishImage(
                    imageName: settings.imageName,
                    isLight: settings.isLight,
                    size: size,
                  );
                },
              ),
            ),
          ),

          // 敲击次数角标：v2 只能进菜单才看得到，这里直接显示在角落
          if (tapCount > 0)
            Positioned(
              right: 4,
              top: 4,
              child: IgnorePointer(
                child: _TapCountBadge(
                  count: tapCount,
                  color: settings.isLight ? Colors.black : Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FishImage extends StatelessWidget {
  const _FishImage({
    required this.imageName,
    required this.isLight,
    required this.size,
  });

  final String imageName;
  final bool isLight;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        AssetCatalog.imagePath(imageName),
        color: isLight ? Colors.black : Colors.white,
        fit: BoxFit.contain,
        // v2 在图片缺失时会直接抛异常并白屏
        errorBuilder: (context, error, stackTrace) => Image.asset(
          AssetCatalog.imagePath(AppConstants.defaultImageName),
          color: isLight ? Colors.black : Colors.white,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _TapCountBadge extends StatelessWidget {
  const _TapCountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count',
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(
            color: color.computeLuminance() > 0.5
                ? Colors.black45
                : Colors.white60,
            blurRadius: 2,
          ),
        ],
      ),
    );
  }
}