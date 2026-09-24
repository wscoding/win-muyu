import 'dart:io';
import 'dart:math' show max, min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import '../../constants/app_constants.dart';

/// 悬浮窗口的尺寸与位置
@immutable
class OverlayWindowGeometry {
  const OverlayWindowGeometry({required this.size, required this.position});

  /// 窗口边长
  final double size;

  /// 窗口左上角在桌面上的坐标
  final Offset position;

  Size get asSize => Size(size, size);
}

/// 平台相关的桌面窗口能力。
///
/// 这一层是唯一允许出现 `Platform.isXxx` 分支的地方：
/// 上层 UI 与状态管理只依赖本接口，后续接入 Flutter multi-window
/// 或增加 Linux 支持时，只需要新增一个实现。
abstract interface class DesktopWindowService {
  /// 单实例保护。第二次启动时应唤起已有窗口并让新进程退出。
  Future<void> ensureSingleInstance(List<String> args);

  /// 按屏幕尺寸计算布局，创建并显示悬浮窗口，返回最终几何信息
  Future<OverlayWindowGeometry> showOverlayWindow();

  Future<void> hide();
  Future<void> showAndFocus();

  /// 在显示 / 隐藏之间切换，供托盘菜单与全局快捷键使用
  Future<void> toggleVisibility();

  Future<bool> isVisible();

  /// 拖动窗口（无边框窗口没有系统标题栏，需要手动触发）
  Future<void> startDragging();

  /// 临时把窗口放大成「设置面板」尺寸。
  ///
  /// v2 把 `MenuPage` 直接推进悬浮小窗（边长只有屏幕高度的 15%，1080p 下约 162px），
  /// 设置列表被压缩到几乎不可读。这里在打开菜单时把窗口撑开，
  /// 关闭后恢复，小部件的常驻形态保持不变。
  Future<void> enterPanelMode();

  /// 从「设置面板」恢复成悬浮小部件
  Future<void> exitPanelMode();

  /// 平台标识（windows / macos / other），用于上报与问题定位。
  ///
  /// 之所以放在这一层：平台分支按约定只允许出现在本文件，
  /// 上报层只需读取这个字符串，不必自己判断 `Platform.isXxx`。
  String get platformSlug;

  /// 系统版本号，例如 `10.0.26200`。取不到时返回空串。
  String get osVersionLabel;

  static DesktopWindowService create({Logger? logger}) {
    if (Platform.isWindows) {
      return WindowsDesktopWindowService(logger: logger);
    }
    if (Platform.isMacOS) {
      return MacosDesktopWindowService(logger: logger);
    }
    return UnsupportedDesktopWindowService(logger: logger);
  }
}

/// 基于 `window_manager` 的公共实现，把两端一致的逻辑集中在这里。
abstract class WindowManagerDesktopService implements DesktopWindowService {
  WindowManagerDesktopService({Logger? logger}) : logger = logger ?? Logger();

  final Logger logger;

  /// 窗口与屏幕边缘的留白
  static const double screenMargin = 100;

  /// 设置面板的尺寸上限与占屏比例
  static const double panelMaxWidth = 420;
  static const double panelMaxHeight = 640;
  static const double panelWidthRatio = 0.42;
  static const double panelHeightRatio = 0.72;

  WindowManager get _manager => WindowManager.instance;

  OverlayWindowGeometry? _overlayGeometry;
  bool _panelMode = false;

  /// 平台特有的悬浮样式设置，在窗口显示前调用
  Future<void> applyPlatformOverlayStyle();

  @override
  Future<OverlayWindowGeometry> showOverlayWindow() async {
    final geometry = await _resolveGeometry();
    _overlayGeometry = geometry;

    await _manager.ensureInitialized();

    // 注意：`waitUntilReadyToShow` 的 callback 参数是同步调用、并不会被 await，
    // 依赖它做「建窗 -> 设样式 -> 显示」的顺序会存在竞态。
    // 因此这里不传 callback，改为显式逐步 await。
    await _manager.waitUntilReadyToShow(
      WindowOptions(
        size: geometry.asSize,
        minimumSize: geometry.asSize,
        alwaysOnTop: true,
        skipTaskbar: true,
        titleBarStyle: TitleBarStyle.hidden,
        backgroundColor: Colors.transparent,
        title: 'Prue Widgets',
      ),
    );

    // macOS 上 setAsFrameless 会把 isOpaque 重新设回 true，
    // 所以平台样式必须在它之后应用，否则窗口不是透明的。
    await _manager.setAsFrameless();
    await _manager.setPosition(geometry.position);
    await applyPlatformOverlayStyle();

    await _manager.show();
    await _manager.focus();

    logger.i(
      '悬浮窗口已就绪：边长 ${geometry.size.toStringAsFixed(1)}，'
      '位置 ${geometry.position}',
    );
    return geometry;
  }

  /// 以主屏幕的可用区域（排除菜单栏 / 任务栏）为基准，
  /// 把窗口放在右下角往内缩 [screenMargin] 的位置。
  Future<OverlayWindowGeometry> _resolveGeometry() async {
    final display = await screenRetriever.getPrimaryDisplay();
    final workSize = display.visibleSize ?? display.size;
    final workOrigin = display.visiblePosition ?? Offset.zero;

    final size = workSize.height * AppConstants.windowSizeRatio;
    return OverlayWindowGeometry(
      size: size,
      position: Offset(
        workOrigin.dx + workSize.width - size - screenMargin,
        workOrigin.dy + workSize.height - size - screenMargin,
      ),
    );
  }

  @override
  Future<void> hide() async {
    await _manager.hide();
  }

  @override
  Future<void> showAndFocus() async {
    if (await _manager.isMinimized()) {
      await _manager.restore();
    }
    await _manager.show();
    await _manager.focus();
  }

  @override
  Future<void> toggleVisibility() async {
    if (await isVisible()) {
      await hide();
    } else {
      await showAndFocus();
    }
  }

  @override
  Future<bool> isVisible() async {
    if (await _manager.isMinimized()) return false;
    return _manager.isVisible();
  }

  @override
  Future<void> startDragging() => _manager.startDragging();

  @override
  Future<void> enterPanelMode() async {
    if (_panelMode || _overlayGeometry == null) return;

    final display = await screenRetriever.getPrimaryDisplay();
    final workSize = display.visibleSize ?? display.size;
    final workOrigin = display.visiblePosition ?? Offset.zero;

    final width = min(panelMaxWidth, workSize.width * panelWidthRatio);
    final height = min(panelMaxHeight, workSize.height * panelHeightRatio);
    final bottom = workOrigin.dy + workSize.height - height - screenMargin;

    // 保持右下角对齐，避免窗口在切换时「跳走」
    await _manager.setPosition(
      Offset(
        workOrigin.dx + workSize.width - width - screenMargin,
        max(workOrigin.dy, bottom),
      ),
    );
    await _manager.setSize(Size(width, height));
    _panelMode = true;
  }

  @override
  Future<void> exitPanelMode() async {
    if (!_panelMode) return;
    final geometry = _overlayGeometry;
    if (geometry != null) {
      await _manager.setSize(geometry.asSize);
      await _manager.setPosition(geometry.position);
    }
    _panelMode = false;
  }
}

/// Windows：单实例交给 `windows_single_instance`（命名管道 + 消息唤醒）
class WindowsDesktopWindowService extends WindowManagerDesktopService {
  WindowsDesktopWindowService({super.logger});

  /// 命名管道的唯一标识，改动会让新旧版本互相视作不同应用
  static const String _pipeName = 'desktop_open';

  @override
  Future<void> ensureSingleInstance(List<String> args) async {
    await WindowsSingleInstance.ensureSingleInstance(
      args,
      _pipeName,
      onSecondWindow: (args) async {
        await showAndFocus();
      },
    );
  }

  @override
  Future<void> applyPlatformOverlayStyle() async {
    // Windows 侧 window_manager 已覆盖全部需求（无边框 / 透明 / 置顶 / 隐藏任务栏图标）
  }

  @override
  String get platformSlug => 'windows';

  @override
  String get osVersionLabel => Platform.operatingSystemVersion;
}

/// macOS：单实例、隐藏 Dock 图标、悬浮层级等由原生 Swift 代码完成，
/// 见 `macos/Runner/AppDelegate.swift` 与 `macos/Runner/NativeBridge.swift`
class MacosDesktopWindowService extends WindowManagerDesktopService {
  MacosDesktopWindowService({super.logger});

  static const MethodChannel _channel = MethodChannel(MacosNative.methodChannel);

  /// 原生侧在检测到「应用被重复启动」时回调，让 Flutter 层把窗口顶到最前
  void attachActivationHandler(Future<void> Function() onActivate) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == MacosNative.onActivateRequested) {
        await onActivate();
      }
      return null;
    });
  }

  @override
  Future<void> ensureSingleInstance(List<String> args) async {
    attachActivationHandler(showAndFocus);

    final isPrimary =
        await _channel.invokeMethod<bool>(MacosNative.isPrimaryInstance) ?? true;
    if (!isPrimary) {
      logger.i('检测到已有实例，请求其前置后退出当前进程');
      await _channel.invokeMethod<void>(MacosNative.activateExistingInstance);
      exit(0);
    }
  }

  @override
  Future<void> applyPlatformOverlayStyle() async {
    await _channel.invokeMethod<void>(MacosNative.configureOverlayWindow);
  }

  @override
  String get platformSlug => 'macos';

  @override
  String get osVersionLabel => Platform.operatingSystemVersion;

  @override
  Future<void> hide() async {
    await super.hide();
  }
}

/// 其他平台（Linux / 未来的 Web）：只保证能编译与降级运行
class UnsupportedDesktopWindowService extends WindowManagerDesktopService {
  UnsupportedDesktopWindowService({super.logger});

  @override
  Future<void> ensureSingleInstance(List<String> args) async {
    logger.w('当前平台未实现单实例保护');
  }

  @override
  Future<void> applyPlatformOverlayStyle() async {
    logger.w('当前平台未实现悬浮窗口样式');
  }

  @override
  String get platformSlug => 'other';

  @override
  String get osVersionLabel => Platform.operatingSystemVersion;
}

/// macOS 原生通道的方法名约定。
///
/// Dart 与 Swift 两侧共用这组常量，改动时必须同步
/// `macos/Runner/NativeBridge.swift`。
class MacosNative {
  const MacosNative._();

  static const String methodChannel = 'cc.iqg.prue_widgets/native';

  /// Dart -> Swift
  static const String isPrimaryInstance = 'isPrimaryInstance';
  static const String activateExistingInstance = 'activateExistingInstance';
  static const String configureOverlayWindow = 'configureOverlayWindow';
  static const String setDockIconVisible = 'setDockIconVisible';

  /// Swift -> Dart
  static const String onActivateRequested = 'onActivateRequested';
}