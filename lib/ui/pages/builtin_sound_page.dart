import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/asset_catalog.dart';
import '../../models/app_settings.dart';
import '../../state/providers.dart';
import '../../utils/async_utils.dart';
import '../widgets/panel_scaffold.dart';

/// 内置音效选择。
///
/// 点一条就同时做两件事：写入 `builtinAudioAsset` 并立刻试听。
/// 旧版必须先保存再去主界面敲一下才知道是什么声音，逐个试听非常费劲。
class BuiltinSoundPage extends ConsumerWidget {
  const BuiltinSoundPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;
    // 存档里是 `audio/xxx.mp3`，这里反解出文件名才能和清单的键比较
    final current = AssetCatalog.soundNameFromAsset(settings.builtinAudioAsset);

    return PanelScaffold(
      title: '内置音效',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const PanelHint('点击任意一条即可试听，并设为当前音效。'),
          // 保持 Map 的声明顺序：常用的低沉 / 清脆排在最前面
          for (final entry in AssetCatalog.builtinSounds.entries)
            ListTile(
              title: Text(entry.value),
              subtitle: Text(entry.key),
              leading: Icon(
                entry.key == current ? Icons.check_circle : Icons.graphic_eq,
                color: entry.key == current ? scheme.primary : null,
              ),
              selected: entry.key == current,
              onTap: () => _select(ref, entry.key),
            ),
        ],
      ),
    );
  }

  /// 先落盘再试听：试听走独立通道，不受「敲击声」开关影响，
  /// 关掉音效的用户也能靠试听挑音源。
  static void _select(WidgetRef ref, String fileName) {
    final assetPath = AssetCatalog.audioAssetPath(fileName);
    unawaitedSafely(
      ref.read(settingsProvider.notifier).patch(builtinAudioAsset: assetPath),
    );
    unawaitedSafely(
      ref
          .read(audioServiceProvider)
          .preview(AudioSourceType.builtin, assetPath),
    );
  }
}
