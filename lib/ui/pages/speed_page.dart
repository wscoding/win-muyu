import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../state/providers.dart';
import '../../utils/async_utils.dart';
import '../widgets/panel_scaffold.dart';

/// 播放速度设置。
///
/// 拖动即刻落盘，没有单独的「保存」步骤。页面里另存一份 [_value]，
/// 是为了让滑块和数字跟手：落盘是异步的，直接读设置回显会慢半拍。
class SpeedPage extends ConsumerStatefulWidget {
  const SpeedPage({super.key});

  @override
  ConsumerState<SpeedPage> createState() => _SpeedPageState();
}

class _SpeedPageState extends ConsumerState<SpeedPage> {
  /// 快捷倍率，都落在滑块的档位上（0.5 ~ 2.0，共 6 档，每档 0.25）
  static const List<double> _presets = <double>[0.5, 1.0, 1.5, 2.0];

  late double _value;

  @override
  void initState() {
    super.initState();
    // 读取时已由 repository 夹到合法区间，这里不必再兜底
    _value = ref.read(settingsProvider).speedMultiplier;
  }

  void _apply(double value) {
    if (value == _value) return;
    setState(() => _value = value);
    unawaitedSafely(
      ref.read(settingsProvider.notifier).patch(speedMultiplier: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PanelScaffold(
      title: '播放速度',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const PanelSectionHeader('速度倍率'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text('当前速度', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(
                  '${_value.toStringAsFixed(2)}x',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Slider(
            value: _value,
            min: AppConstants.minSpeedMultiplier,
            max: AppConstants.maxSpeedMultiplier,
            divisions: 6,
            label: '${_value.toStringAsFixed(2)}x',
            onChanged: _apply,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  ChoiceChip(
                    label: Text('${preset.toStringAsFixed(1)}x'),
                    selected: (preset - _value).abs() < 0.001,
                    onSelected: (_) => _apply(preset),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const PanelHint('修改立即生效，从下一次敲击开始使用新速度；已经在播的尾音不受影响。'),
        ],
      ),
    );
  }
}
