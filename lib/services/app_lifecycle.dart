import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// 统一的退出流程。
///
/// v2 在多个页面直接调用 `exit(0)`（菜单的关闭按钮、右键菜单的「清空退出」），
/// 未落盘的敲击次数会直接丢失。这里先把状态写入再退出。
Future<void> shutdownApp(WidgetRef ref) async {
  await ref.read(tapCounterProvider.notifier).flush();

  // 退出前把攒着的敲击一次性发出去，并主动下线。
  // 全部失败也不影响正确性：敲击是累计值语义，下次启动会自动补上差额；
  // 在线状态则由心跳超时（120 秒）兜底，不依赖这次调用成功。
  final telemetry = ref.read(telemetryServiceProvider);
  await telemetry.reportOffline();
  telemetry.dispose();

  await ref.read(trayServiceProvider).dispose();
  await ref.read(hotkeyServiceProvider).dispose();
  await ref.read(audioServiceProvider).dispose();
  await ref.read(windowServiceProvider).hide();
  exit(0);
}