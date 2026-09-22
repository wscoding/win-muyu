import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../models/merit_text.dart';
import '../../state/providers.dart';
import '../widgets/panel_scaffold.dart';

/// 敲击统计页。
///
/// 计数只经由 `TapCounterController` 读写：v2 在这一页直接操作
/// SharedPreferences（`_saveTapCount`），和主界面各写一份，容易互相覆盖。
class TapCountPage extends ConsumerWidget {
  const TapCountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tapCount = ref.watch(tapCounterProvider);
    final level = MeritText.levelForTapCount(tapCount);

    return PanelScaffold(
      title: '敲击统计',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const PanelSectionHeader('累计'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '$tapCount',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '当前水平：$level',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PanelHint(
            '手动增减的改动同样会写入本地；累计计数最多每 '
            '${AppConstants.tapCountFlushInterval.inSeconds} 秒落盘一次，避免连击时频繁写盘。',
          ),

          const PanelSectionHeader('调整'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () =>
                      ref.read(tapCounterProvider.notifier).increment(),
                  icon: const Icon(Icons.add),
                  label: const Text('+1'),
                ),
                FilledButton.tonalIcon(
                  // 计数已经是 0 时控制器会自行忽略，这里不额外禁用，
                  // 免得按钮状态和控制器逻辑两处不同步
                  onPressed: () =>
                      ref.read(tapCounterProvider.notifier).decrement(),
                  icon: const Icon(Icons.remove),
                  label: const Text('-1'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _reset(context, ref),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('重置'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copy(context, ref),
                  icon: const Icon(Icons.content_copy),
                  label: const Text('复制统计'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 重置需要二次确认：清掉的是长期累计的数据
  static Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final counter = ref.read(tapCounterProvider.notifier);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重置计数'),
        content: const Text('将把累计敲击次数清零，且无法恢复。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定重置'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await counter.reset();
    messenger.showSnackBar(
      const SnackBar(content: Text('已重置'), duration: Duration(seconds: 1)),
    );
  }

  static Future<void> _copy(BuildContext context, WidgetRef ref) async {
    final count = ref.read(tapCounterProvider);
    final text = '当前水平：${MeritText.levelForTapCount(count)}，敲击次数：$count';
    final messenger = ScaffoldMessenger.of(context);

    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(
      const SnackBar(content: Text('统计已复制'), duration: Duration(seconds: 1)),
    );
  }
}