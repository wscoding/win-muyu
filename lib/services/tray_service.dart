import 'dart:io';

import 'package:logger/logger.dart';
import 'package:tray_manager/tray_manager.dart';

/// 托盘 / 菜单栏图标。
///
/// - macOS 使用模板图（纯黑 + alpha），系统会跟随浅色 / 深色外观自动反色；
/// - Windows 托盘只接受 `.ico`（原生侧走 `LoadImage`，不认 png）。
class TrayService with TrayListener {
  TrayService({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  static const String _iconPng = 'assets/tray/tray_icon.png';
  static const String _iconIco = 'assets/tray/tray_icon.ico';

  static const String _keyToggle = 'toggle_visibility';
  static const String _keyReset = 'reset_count';
  static const String _keyQuit = 'quit';

  Future<void> Function()? _onToggleVisibility;
  Future<void> Function()? _onResetCount;
  Future<void> Function()? _onQuit;

  bool _initialized = false;

  /// 当前是否显示木鱼，仅用于生成菜单文案
  bool _windowVisible = true;

  Future<void> initialize({
    required Future<void> Function() onToggleVisibility,
    required Future<void> Function() onResetCount,
    required Future<void> Function() onQuit,
  }) async {
    if (_initialized) return;

    _onToggleVisibility = onToggleVisibility;
    _onResetCount = onResetCount;
    _onQuit = onQuit;

    try {
      if (Platform.isWindows) {
        await trayManager.setIcon(_iconIco);
      } else {
        await trayManager.setIcon(_iconPng, isTemplate: true, iconSize: 18);
      }
      await trayManager.setToolTip('Prue Widgets — 电子木鱼');
      trayManager.addListener(this);
      await _rebuildMenu();
      _initialized = true;
      _logger.i('托盘图标已就绪');
    } catch (error) {
      // 托盘失败不应该影响主功能
      _logger.w('托盘初始化失败：$error');
    }
  }

  /// 窗口显示状态变化后刷新菜单文案
  Future<void> updateWindowVisible(bool visible) async {
    if (!_initialized || _windowVisible == visible) return;
    _windowVisible = visible;
    await _rebuildMenu();
  }

  Future<void> _rebuildMenu() async {
    try {
      await trayManager.setContextMenu(
        Menu(
          items: <MenuItem>[
            MenuItem(
              key: _keyToggle,
              label: _windowVisible ? '隐藏木鱼' : '显示木鱼',
            ),
            MenuItem(key: _keyReset, label: '重置敲击次数'),
            MenuItem.separator(),
            MenuItem(key: _keyQuit, label: '退出'),
          ],
        ),
      );
    } catch (error) {
      _logger.w('刷新托盘菜单失败：$error');
    }
  }

  // ---- TrayListener ----

  @override
  void onTrayIconMouseDown() {
    // 左键单击直接切换显示，符合桌面小部件的直觉
    _onToggleVisibility?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _keyToggle:
        _onToggleVisibility?.call();
      case _keyReset:
        _onResetCount?.call();
      case _keyQuit:
        _onQuit?.call();
    }
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    trayManager.removeListener(this);
    try {
      await trayManager.destroy();
    } catch (_) {
      // 退出阶段销毁失败无需处理
    }
    _initialized = false;
  }
}