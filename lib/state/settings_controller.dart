import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import 'providers.dart';

/// 应用设置的唯一修改入口。
///
/// v2 里设置散落在 `muyu.dart` 的字段、全局变量、以及各个页面的
/// `_saveSettings()` 中，读写大量错位（例如把用户输入写进 `autofile`
/// 却从 `selectmusic` 读取）。现在改为：
/// - 状态集中在这里，UI 只读 [state]；
/// - 任何修改都通过 [update]，改完立即落盘；
/// - 初始值由启动流程注入，避免首帧闪一下默认外观。
class SettingsController extends Notifier<AppSettings> {
  SettingsController({AppSettings? initial})
    : _initial = initial ?? const AppSettings();

  final AppSettings _initial;

  @override
  AppSettings build() => _initial;

  /// 以函数式方式更新设置；值没有实际变化时不会写盘
  Future<void> update(AppSettings Function(AppSettings current) mutate) async {
    final next = mutate(state);
    if (next == state) return;
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
  }

  /// 只改动单个字段的便捷写法
  Future<void> patch({
    bool? isLight,
    String? imageName,
    AudioSourceType? audioSourceType,
    String? builtinAudioAsset,
    String? localAudioPath,
    String? remoteAudioUrl,
    bool? soundEnabled,
    double? speedMultiplier,
    bool? autoTapEnabled,
    int? autoTapIntervalMs,
    String? meritPrefix,
    String? meritSubtitle,
    List<String>? meritPrefixPool,
    bool? telemetryEnabled,
    bool? releaseChannel,
  }) {
    return update(
      (current) => current.copyWith(
        isLight: isLight,
        imageName: imageName,
        audioSourceType: audioSourceType,
        builtinAudioAsset: builtinAudioAsset,
        localAudioPath: localAudioPath,
        remoteAudioUrl: remoteAudioUrl,
        soundEnabled: soundEnabled,
        speedMultiplier: speedMultiplier,
        autoTapEnabled: autoTapEnabled,
        autoTapIntervalMs: autoTapIntervalMs,
        meritPrefix: meritPrefix,
        meritSubtitle: meritSubtitle,
        meritPrefixPool: meritPrefixPool,
        telemetryEnabled: telemetryEnabled,
        releaseChannel: releaseChannel,
      ),
    );
  }

  Future<void> toggleIsLight() => patch(isLight: !state.isLight);
}