import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../state/providers.dart';
import '../widgets/panel_scaffold.dart';
import 'builtin_sound_page.dart';
import 'local_sound_page.dart';
import 'remote_sound_page.dart';

/// 音源类型选择。
///
/// 选中某一类音源后立刻落盘并跳进对应的子页面（内置 / 本地 / URL）：
/// v2 选完只改了个全局变量，用户还得自己再找入口去配文件或链接，
/// 结果敲下去没声音还以为坏了。
class SoundSourcePage extends ConsumerWidget {
  const SoundSourcePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return PanelScaffold(
      title: '音源',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const PanelSectionHeader('音源类型'),
          // RadioListTile 的 groupValue / onChanged 已废弃，
          // 选中状态与回调统一交给 RadioGroup 托管
          RadioGroup<AudioSourceType>(
            groupValue: settings.audioSourceType,
            onChanged: (type) => _select(context, ref, type),
            child: const Column(
              children: [
                RadioListTile<AudioSourceType>(
                  value: AudioSourceType.builtin,
                  title: Text('内置音效'),
                  subtitle: Text('开箱即用，不需要额外配置'),
                  secondary: Icon(Icons.graphic_eq),
                ),
                RadioListTile<AudioSourceType>(
                  value: AudioSourceType.local,
                  title: Text('本地文件'),
                  subtitle: Text('播放电脑上已有的音频文件'),
                  secondary: Icon(Icons.folder_open_outlined),
                ),
                RadioListTile<AudioSourceType>(
                  value: AudioSourceType.remote,
                  title: Text('网络直链'),
                  subtitle: Text('播放 http(s) 音频直链'),
                  secondary: Icon(Icons.link),
                ),
              ],
            ),
          ),
          const PanelHint(
            '本地文件和网络直链都需要额外设置：本地要先选好音频文件，'
            '网络直链要填可访问的 http(s) 地址，否则敲击时不会有声音。',
          ),
        ],
      ),
    );
  }

  static Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    AudioSourceType? type,
  ) async {
    if (type == null) return;

    // await 之后不能再碰 context，先把 Navigator 取出来
    final navigator = Navigator.of(context);
    await ref.read(settingsProvider.notifier).patch(audioSourceType: type);
    if (!navigator.mounted) return;
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => _subPageFor(type)),
    );
  }

  static Widget _subPageFor(AudioSourceType type) => switch (type) {
    AudioSourceType.builtin => const BuiltinSoundPage(),
    AudioSourceType.local => const LocalSoundPage(),
    AudioSourceType.remote => const RemoteSoundPage(),
  };
}
