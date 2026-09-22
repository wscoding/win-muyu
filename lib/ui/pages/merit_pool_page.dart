import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../state/providers.dart';
import '../../utils/async_utils.dart';
import '../widgets/panel_scaffold.dart';

/// 祝福语池管理。
///
/// 累计敲击超过 [AppConstants.meritStep] 次后，功德提示会从
/// 「前缀+次数」切换成「随机祝福语+功德数」，随机源就是这个列表。
/// v2 把列表存在 `list` 键里，并且和其它设置混用同一份 prefs 读写；
/// 现在统一走 `settings.meritPrefixPool`。
class MeritPoolPage extends ConsumerStatefulWidget {
  const MeritPoolPage({super.key});

  @override
  ConsumerState<MeritPoolPage> createState() => _MeritPoolPageState();
}

class _MeritPoolPageState extends ConsumerState<MeritPoolPage> {
  /// 底部表单与页面共用同一个输入控制器，必须在页面里持有并释放
  final TextEditingController _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  List<String> get _pool => ref.read(settingsProvider).meritPrefixPool;

  Future<void> _addItem() async {
    final value = await _showEditor(title: '新增祝福语');
    if (value == null) return;

    final pool = _pool;
    if (pool.contains(value)) {
      _toast('「$value」已存在');
      return;
    }
    await ref
        .read(settingsProvider.notifier)
        .patch(meritPrefixPool: <String>[...pool, value]);
  }

  Future<void> _editItem(int index) async {
    final before = _pool;
    if (index < 0 || index >= before.length) return;

    final value = await _showEditor(title: '编辑祝福语', initial: before[index]);
    if (value == null) return;

    // 弹窗期间列表可能已经变化，这里重新取一次再做边界检查
    final pool = _pool;
    if (index >= pool.length) return;
    final next = <String>[...pool];
    next[index] = value;
    await ref.read(settingsProvider.notifier).patch(meritPrefixPool: next);
  }

  /// 侧滑删除：先确认再改状态，避免误删
  Future<bool> _confirmRemove(String item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除祝福语'),
        content: Text('确定删除「$item」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _removeAt(int index) {
    final pool = _pool;
    if (index < 0 || index >= pool.length) return;
    final next = <String>[...pool]..removeAt(index);
    // patch 会先同步更新状态再落盘，界面立即刷新
    unawaitedSafely(
      ref.read(settingsProvider.notifier).patch(meritPrefixPool: next),
    );
  }

  Future<void> _copyJson() async {
    final pool = _pool;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: jsonEncode(pool)));
    messenger.showSnackBar(
      SnackBar(
        content: Text('已复制 ${pool.length} 条祝福语'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _importJson() async {
    final messenger = ScaffoldMessenger.of(context);

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim() ?? '';
    if (raw.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('剪贴板是空的'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    List<String> imported;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('不是 JSON 数组');
      }
      imported = decoded
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('剪贴板内容不是合法的 JSON 字符串数组'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (imported.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('没有可导入的内容'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    final pool = _pool;
    final merged = <String>[...pool];
    for (final item in imported) {
      if (!merged.contains(item)) merged.add(item);
    }
    await ref
        .read(settingsProvider.notifier)
        .patch(meritPrefixPool: merged);

    messenger.showSnackBar(
      SnackBar(
        content: Text('已导入 ${merged.length - pool.length} 条，当前共 ${merged.length} 条'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 新增 / 编辑共用的底部表单，返回 null 表示放弃
  Future<String?> _showEditor({required String title, String? initial}) {
    final formKey = GlobalKey<FormState>();
    _inputController.text = initial ?? '';

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        // 键盘弹出时把表单顶上去
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _inputController,
                  autofocus: true,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[\u4e00-\u9fa5a-zA-Z]'),
                    ),
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: const InputDecoration(
                    labelText: '祝福语',
                    helperText: '1-3 个中文或字母',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return '请输入内容';
                    if (text.length > 3) return '请输入 1-3 个字符';
                    if (!RegExp(r'^[\u4e00-\u9fa5a-zA-Z]+$').hasMatch(text)) {
                      return '请输入中英文字符';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    Navigator.of(sheetContext).pop(_inputController.text.trim());
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // watch 之后列表变化会自动重建，Dismissible 才能正确移除条目
    final pool = ref.watch(settingsProvider).meritPrefixPool;

    return PanelScaffold(
      title: '祝福语池',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const PanelSectionHeader('说明'),
          PanelHint(
            '累计敲击满 ${AppConstants.meritStep} 次后，每次敲击会从下面的列表里随机挑一条展示，'
            '例如「平安+3」。列表为空时使用内置文案「${AppConstants.defaultMeritSubtitle}」。',
          ),

          const PanelSectionHeader('操作'),
          ListTile(
            title: const Text('新增祝福语'),
            subtitle: const Text('1-3 个中文字符或字母'),
            leading: const Icon(Icons.add_circle_outline),
            onTap: _addItem,
          ),
          ListTile(
            title: const Text('复制 JSON'),
            subtitle: const Text('导出当前列表，便于备份或分享'),
            leading: const Icon(Icons.copy_all_outlined),
            onTap: _copyJson,
          ),
          ListTile(
            title: const Text('从剪贴板导入 JSON'),
            subtitle: const Text('与已有内容合并并自动去重'),
            leading: const Icon(Icons.content_paste_outlined),
            onTap: _importJson,
          ),

          const Divider(height: 24),
          PanelSectionHeader('列表（${pool.length} 条）'),
          if (pool.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(child: Text('还没有祝福语，点上面的「新增祝福语」添加')),
            )
          else
            for (final (index, item) in pool.indexed)
              Dismissible(
                // 内容可能重复，把下标一起放进 key，避免 key 冲突
                key: ValueKey<String>('$index-$item'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmRemove(item),
                onDismissed: (_) => _removeAt(index),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: scheme.errorContainer,
                  child: Icon(
                    Icons.delete_outline,
                    color: scheme.onErrorContainer,
                  ),
                ),
                child: ListTile(
                  title: Text(item),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => _editItem(index),
                ),
              ),
        ],
      ),
    );
  }
}