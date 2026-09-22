import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../state/providers.dart';
import '../widgets/panel_scaffold.dart';

/// 功德文字前缀设置。
///
/// 只影响不足 [AppConstants.meritStep] 次敲击时的文案（如 `功德+57`）；
/// 满 100 次之后改用祝福语池，见 `MeritPoolPage`。
class MeritPrefixPage extends ConsumerStatefulWidget {
  const MeritPrefixPage({super.key});

  @override
  ConsumerState<MeritPrefixPage> createState() => _MeritPrefixPageState();
}

class _MeritPrefixPageState extends ConsumerState<MeritPrefixPage> {
  /// 仅供校验表单使用；真正的落盘只在点击「保存」时发生
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(settingsProvider).meritPrefix,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 预览用文案：次数固定成 57，让用户直观看到敲击时会出现什么
  String get _preview {
    final prefix = _controller.text.trim();
    return '${prefix.isEmpty ? AppConstants.defaultMeritPrefix : prefix}+57';
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // await 之后不能再碰 context，先取出导航与提示对象
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // v2 把保存直接写在 onChanged 里，每输入一个字就写一次盘；
    // 这里改为只在点击保存时提交一次。
    await ref
        .read(settingsProvider.notifier)
        .patch(meritPrefix: _controller.text.trim());

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('已保存'), duration: Duration(seconds: 1)),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PanelScaffold(
      title: '功德文字',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const PanelSectionHeader('前缀'),
          PanelHint(
            '不足 ${AppConstants.meritStep} 次敲击时展示「前缀+次数」；'
            '满 ${AppConstants.meritStep} 次后随机展示祝福语池里的条目。',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Form(
              key: _formKey,
              child: TextFormField(
                controller: _controller,
                autofocus: true,
                maxLength: 20,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^[\u4e00-\u9fa5a-zA-Z, ]+$'),
                  ),
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: const InputDecoration(
                  labelText: '前缀文字',
                  helperText: '仅支持中文、字母、空格与逗号，最多 20 字',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? '内容不能为空' : null,
                // 只刷新预览，不落盘
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const PanelSectionHeader('效果预览'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _preview,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}