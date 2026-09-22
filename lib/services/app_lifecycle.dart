import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// 统一的退出流程。
///
/// v2 在多个页面直接调用 `exit(0)`（菜单的关闭按钮、右键菜单的「清空退出」），
/// 未落盘的敲击次数会直接丢失。这里先把状态写入再退出。
Future<void> shutdownApp(WidgetRef ref) async {
  await ref.read(tapCounterProvider.notifier).flush();
  await ref.read(trayServiceProvider).dispose();
  await ref.read(hotkeyServiceProvider).dispose();
  await ref.read(audioServiceProvider).dispose();
  await ref.read(windowServiceProvider).hide();
  exit(0);
}