import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../state/providers.dart';
import '../widgets/panel_scaffold.dart';

/// 网络音效设置。
///
/// 只接受 http / https 直链：v2 不校验任何格式，用户把网页地址或
/// 没带协议头的链接填进去，敲击时只会静默失败。这里在试听和保存前
/// 都先检查一次，并把失败原因弹出来。
class RemoteSoundPage extends ConsumerStatefulWidget {
  const RemoteSoundPage({super.key});

  @override
  ConsumerState<RemoteSoundPage> createState() => _RemoteSoundPageState();
}

class _RemoteSoundPageState extends ConsumerState<RemoteSoundPage> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: ref.read(settingsProvider).remoteAudioUrl,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    final messenger = ScaffoldMessenger.of(context);
    final url = _urlController.text.trim();

    final error = _validate(url);
    if (error != null) {
      _showMessage(messenger, error);
      return;
    }
    await ref.read(audioServiceProvider).preview(AudioSourceType.remote, url);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final url = _urlController.text.trim();

    final error = _validate(url);
    if (error != null) {
      _showMessage(messenger, error);
      return;
    }
    await ref.read(settingsProvider.notifier).patch(remoteAudioUrl: url);
    _showMessage(messenger, '已保存');
  }

  /// 只放行能直接播放的 http(s) 直链
  static String? _validate(String url) {
    if (url.isEmpty) return '请先填写音频直链';
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return '只支持 http 或 https 开头的地址';
    }
    if (uri.host.isEmpty) return '地址缺少域名';
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
      title: '网络音频直链',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const PanelSectionHeader('音频地址'),
          const PanelHint(
            '网络音频要先缓冲，第一次敲击会有明显延迟，断网时也会没声音；'
            '只支持能直接播放的音频直链（http / https），网页播放页的地址无效。',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextFormField(
              controller: _urlController,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: '音频直链',
                hintText: '例如 https://example.com/muyu.mp3',
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
