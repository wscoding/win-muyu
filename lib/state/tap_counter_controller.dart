import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../services/settings_repository.dart';
import '../utils/async_utils.dart';
import 'providers.dart';

/// 敲击次数。
///
/// v2 的问题：`TapCounter.getTapCount()` 每次被读取都顺手写一次
/// SharedPreferences，而 UI 每帧都可能读它；`TapCounter.initialize()`
/// 又是异步的，未完成时读取会直接抛 `LateInitializationError`。
///
/// 现在改为内存为准 + 定时落盘：
/// - 计数变更后最多每 [AppConstants.tapCountFlushInterval] 写一次盘；
/// - 状态销毁（退出应用）时补一次同步落盘，避免丢数据。
class TapCounterController extends Notifier<int> {
  TapCounterController({int initial = 0}) : _initial = initial < 0 ? 0 : initial;

  final int _initial;

  Timer? _flushTimer;
  int _pendingValue = 0;
  bool _hasPendingWrite = false;

  /// 在 build 阶段缓存依赖。
  ///
  /// 不能在 [_flushOnDispose] 里 `ref.read`：Riverpod 禁止在生命周期回调中
  /// 使用 Ref（会抛 `Cannot use Ref or modify other providers inside
  /// life-cycles`），那样退出时的最后一次落盘必然失败、计数直接丢失。
  SettingsRepository? _repository;

  @override
  int build() {
    _repository = ref.read(settingsRepositoryProvider);
    _pendingValue = _initial;
    ref.onDispose(_flushOnDispose);
    return _initial;
  }

  void increment() {
    state = state + 1;
    _scheduleFlush();
  }

  void decrement() {
    if (state <= 0) return;
    state = state - 1;
    _scheduleFlush();
  }

  void add(int delta) {
    final next = state + delta;
    state = next < 0 ? 0 : next;
    _scheduleFlush();
  }

  /// 重置为 0 并立即落盘（托盘菜单 / 统计页使用）
  Future<void> reset() async {
    state = 0;
    // 必须显式标记待写入：flush 只在「有待写入内容」时才写盘，
    // 否则 reset 会变成一个只改内存、不落盘的空操作。
    _pendingValue = 0;
    _hasPendingWrite = true;
    await flush();
  }

  /// 立即把当前计数写入 SharedPreferences
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (!_hasPendingWrite) return;
    _hasPendingWrite = false;
    await ref.read(settingsRepositoryProvider).saveTapCount(state);
  }

  /// 放弃未落盘的计数并清零。
  ///
  /// 供「清空本地数据」使用：清空 SharedPreferences 之后，退出流程里的
  /// [flush] 仍可能把待写入的旧计数写回去，等于清不干净。
  /// 先调用本方法清掉待写入标记，清空才是真的清空。
  void discardPendingWrites() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _hasPendingWrite = false;
    _pendingValue = 0;
    state = 0;
  }

  void _scheduleFlush() {
    _pendingValue = state;
    _hasPendingWrite = true;
    _flushTimer ??= Timer(AppConstants.tapCountFlushInterval, () {
      _flushTimer = null;
      unawaited(flush());
    });
  }

  void _flushOnDispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (!_hasPendingWrite) return;
    // 退出阶段无法 await，这里直接发出写入请求，
    // SharedPreferences 的写入会由平台侧完成。
    unawaitedSafely(_repository!.saveTapCount(_pendingValue));
    _hasPendingWrite = false;
  }
}