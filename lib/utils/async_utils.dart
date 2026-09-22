import 'package:flutter/foundation.dart';

/// 触发一个 Future 但不等待它，并且吞掉异常。
///
/// 用于上报、刷新托盘菜单、落盘这类「失败也不该影响主流程」的调用。
void unawaitedSafely(Future<void> future) {
  future.catchError((Object error, StackTrace stack) {
    if (!kReleaseMode) {
      debugPrint('忽略的后台任务异常：$error');
    }
  });
}