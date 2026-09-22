import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/asset_catalog.dart';
import '../../state/providers.dart';
import '../widgets/panel_scaffold.dart';

/// 木鱼图案选择。
///
/// 内置图案有 42 个，而面板只有 420x640：v2 用列表展示，一屏只放得下
/// 七八个，找图要滚很久。这里改成缩略图网格，一屏能看到十几个。
/// 清单统一取自 [AssetCatalog]，避免和 `assets/images` 目录对不上。
class ImagePickerPage extends ConsumerWidget {
  const ImagePickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return PanelScaffold(
      title: '木鱼图案',
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        // 用「单元最大宽度」而不是固定列数，面板尺寸微调时列数自适应
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 64,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: AssetCatalog.imageNames.length,
        itemBuilder: (context, index) {
          final name = AssetCatalog.imageNames[index];
          return _ImageOption(
            name: name,
            selected: name == settings.imageName,
            onTap: () =>
                ref.read(settingsProvider.notifier).patch(imageName: name),
          );
        },
      ),
    );
  }
}

/// 单个图案格子。
///
/// 图案本身是黑色 PNG，直接贴上去在浅色面板上就看得清，
/// 不需要像悬浮窗那样再按黑白主题重新着色。
class _ImageOption extends StatelessWidget {
  const _ImageOption({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            // withOpacity 已废弃，统一用 withValues
            color: selected
                ? scheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  AssetCatalog.imagePath(name),
                  fit: BoxFit.contain,
                  // 资源缺失时只让这一格显示占位图，不能整页崩掉
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.broken_image_outlined, color: scheme.outline),
                ),
              ),
              if (selected)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(
                    Icons.check_circle,
                    size: 14,
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
