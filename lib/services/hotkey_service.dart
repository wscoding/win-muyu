import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:logger/logger.dart';

import '../constants/app_constants.dart';

/// 全局快捷键。
///
/// 使用 [HotKeyScope.system]，应用失去焦点时依然生效，
/// 这样木鱼被其他窗口盖住时也能用快捷键唤起 / 收起。
class HotkeyService {
  HotkeyService({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  HotKey? _toggleVisibilityHotkey;
  bool _registered = false;

  /// 当前生效的快捷键，供设置页展示
  HotKey? get toggleVisibilityHotkey => _toggleVisibilityHotkey;

  String get toggleVisibilityLabel =>
      _toggleVisibilityHotkey == null
          ? AppConstants.toggleVisibilityHotkeyLabel
          : _describe(_toggleVisibilityHotkey!);

  /// 注册默认快捷键：⌥⌘M 显示 / 隐藏木鱼
  Future<void> registerDefaults({
    required Future<void> Function() onToggleVisibility,
  }) {
    return registerToggleVisibility(
      HotKey(
        key: PhysicalKeyboardKey.keyM,
        modifiers: const <HotKeyModifier>[
          HotKeyModifier.alt,
          HotKeyModifier.meta,
        ],
        scope: HotKeyScope.system,
      ),
      onToggleVisibility: onToggleVisibility,
    );
  }

  Future<void> registerToggleVisibility(
    HotKey hotKey, {
    required Future<void> Function() onToggleVisibility,
  }) async {
    await unregisterToggleVisibility();
    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (_) => onToggleVisibility(),
      );
      _toggleVisibilityHotkey = hotKey;
      _registered = true;
      _logger.i('已注册全局快捷键 ${_describe(hotKey)}');
    } catch (error) {
      // 快捷键被其它应用占用时不应导致启动失败
      _logger.w('注册全局快捷键失败：$error');
      _registered = false;
    }
  }

  Future<void> unregisterToggleVisibility() async {
    final hotKey = _toggleVisibilityHotkey;
    if (hotKey == null || !_registered) return;
    try {
      await hotKeyManager.unregister(hotKey);
    } catch (error) {
      _logger.w('注销全局快捷键失败：$error');
    }
    _toggleVisibilityHotkey = null;
    _registered = false;
  }

  Future<void> dispose() async {
    await unregisterToggleVisibility();
    try {
      await hotKeyManager.unregisterAll();
    } catch (_) {
      // 退出阶段失败无需处理
    }
  }

  static String _describe(HotKey hotKey) {
    final parts = <String>[];
    for (final modifier in hotKey.modifiers ?? const <HotKeyModifier>[]) {
      parts.add(switch (modifier) {
        HotKeyModifier.alt => '⌥',
        HotKeyModifier.control => '⌃',
        HotKeyModifier.meta => '⌘',
        HotKeyModifier.shift => '⇧',
        HotKeyModifier.capsLock => '⇪',
        HotKeyModifier.fn => 'fn',
      });
    }
    parts.add(_keyLabel(hotKey));
    return parts.join();
  }

  /// 取按键的可读名称。
  ///
  /// `HotKey.key` 的静态类型是抽象的 `KeyboardKey`，它既没有 `keyLabel`
  /// 也没有 `debugName`；而 `PhysicalKeyboardKey.debugName` 在 release 下为 null。
  /// 因此统一走 [HotKey.logicalKey]（`LogicalKeyboardKey.keyLabel` 在所有构建模式下都可用）。
  static String _keyLabel(HotKey hotKey) {
    try {
      final label = hotKey.logicalKey.keyLabel;
      if (label.isNotEmpty) return label;
    } catch (_) {
      // 既不是物理键也不是逻辑键时落到默认值
    }
    return 'Key';
  }
}