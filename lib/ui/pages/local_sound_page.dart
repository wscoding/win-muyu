import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../state/providers.dart';
import '../widgets/panel_scaffold.dart';

/// 本地音效设置。
///
/// 路径既能用「选择文件」挑，也能直接手输：v2 只支持手输，用户得自己
/// 去文件夹里复制完整路径，非常劝退。保存前会校验文件是否真的存在，
/// 免得配置完敲下去一点声音都没有还找不到原因。
class LocalSoundPage extends ConsumerStatefulWidget {
  const LocalSoundPage({super.key});

  @override
  ConsumerState<LocalSoundPage> createState() => _LocalSoundPageState();
}

class _LocalSoundPageState extends ConsumerState<LocalSoundPage> {
  late final TextEditingController _pathController;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController(
      text: ref.read(settingsProvider).localAudioPath,
    );
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final messenger = ScaffoldMessenger.of(context);
    // 13.x 的 pickFiles 直接返回文件列表（不再是 FilePickerResult），取消时为空列表
    final files = await FilePicker.pickFiles(type: FileType.audio);
    if (files.isEmpty) return;

    // 系统文件对话框打开期间用户可能已经返回上一页，
    // 此时 _pathController 已被 dispose，继续赋值会抛
    // "A TextEditingController was used after being disposed"。
    if (!mounted) return;

    // 桌面端能拿到绝对路径，其它平台可能为 null
    final path = files.first.path;
    if (path == null) {
      _showMessage(messenger, '无法获取该文件的路径');
      return;
    }
    // 只填进输入框，等用户点「保存」才真正生效
    _pathController.text = path;
  }

  Future<void> _preview() async {
    final messenger = ScaffoldMessenger.of(context);
    final path = _pathController.text.trim();

    final error = _validate(path);
    if (error != null) {
      _showMessage(messenger, error);
      return;
    }
    await ref.read(audioServiceProvider).preview(AudioSourceType.local, path);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final path = _pathController.text.trim();

    final error = _validate(path);
    if (error != null) {
      _showMessage(messenger, error);
      return;
    }
    await ref.read(settingsProvider.notifier).patch(localAudioPath: path);
    _showMessage(messenger, '已保存');
  }

  /// 空路径和「文件已被删除 / 移动」都要拦下来，
  /// 否则播放时会静默失败，用户只感觉到没声音。
  static String? _validate(String path) {
    if (path.isEmpty) return '请先选择音频文件';
    if (!File(path).existsSync()) return '文件不存在：$path';
    return null;
  }

  static void _showMessage(ScaffoldMessengerState messenger, String text) {
    messenger.showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PanelScaffold(
      title: '本地音频文件',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const PanelSectionHeader('文件路径'),
          PanelHint('支持 mp3 / wav 等常见格式；文件被移动或删除后会恢复静音，需要重新选择。'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextFormField(
              controller: _pathController,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: '音频文件路径',
                hintText: '例如 /Users/me/Music/muyu.mp3',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('选择文件'),
                ),
                OutlinedButton.icon(
                  onPressed: _preview,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('试听'),
                ),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
