import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/app_lifecycle.dart';
import '../../state/providers.dart';
import '../widgets/panel_scaffold.dart';
import 'license_page.dart';
import 'sponsor_page.dart';
import 'update_page.dart';

/// 「更多」入口：更新、赞助、协议，以及退出与清空数据。
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PanelScaffold(
      title: '更多',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const PanelSectionHeader('关于'),
          ListTile(
            title: const Text('更新'),
            subtitle: const Text('检查版本、查看更新日志与下载页'),
            leading: const Icon(Icons.system_update_alt),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const UpdatePage()),
          ),
          ListTile(
            title: const Text('赞助'),
            subtitle: const Text('请作者喝杯茶'),
            leading: const Icon(Icons.favorite_border),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const SponsorPage()),
          ),
          ListTile(
            title: const Text('软件协议'),
            subtitle: const Text('MIT 许可、隐私政策与开源信息'),
            leading: const Icon(Icons.description_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const AppLicensePage()),
          ),

          const Divider(height: 24),
          const PanelSectionHeader('数据'),
          ListTile(
            title: const Text('清空本地数据'),
            subtitle: const Text('删除全部设置、计数与缓存，之后应用会退出'),
            leading: const Icon(Icons.delete_forever_outlined),
            onTap: () => _clearLocalData(context, ref),
          ),
          ListTile(
            title: const Text('退出 Prue Widgets'),
            leading: const Icon(Icons.power_settings_new),
            onTap: () => shutdownApp(ref),
          ),
        ],
      ),
    );
  }

  /// 清空后直接退出：设置已经被删掉，留在界面里没有意义
  static Future<void> _clearLocalData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空本地数据'),
        content: const Text(
          '将删除全部设置、敲击次数与版本缓存，且无法恢复。确定继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清空并退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // 先清掉「待写入」标记，再删数据：否则退出流程里的 flush 会把
    // 刚删掉的 tapCount 又写回 SharedPreferences，等于没清干净。
    ref.read(tapCounterProvider.notifier).discardPendingWrites();
    await ref.read(settingsRepositoryProvider).clearAll();
    await shutdownApp(ref);
  }

  static Future<void> _push(BuildContext context, Widget page) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }
}