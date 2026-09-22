import 'package:flutter/material.dart';

import '../../constants/asset_catalog.dart';
import '../widgets/panel_scaffold.dart';

/// 赞助页。
///
/// 收款的二维码是打包进 assets 的本地图片（见 [AssetCatalog.imageDir]），
/// 只有官网二维码来自网络，因此单独做了加载失败的占位，
/// 免得离线机器上出现红叉图标。
class SponsorPage extends StatelessWidget {
  const SponsorPage({super.key});

  static const String _siteQrUrl = 'http://file.iqg.cc/0l9rfsPI';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PanelScaffold(
      title: '赞助',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const PanelHint('如果这个小木鱼给你带来了一点点快乐，欢迎扫码支持作者。'),

          const _QrImage(
            asset: '${AssetCatalog.imageDir}/wx.png',
            caption: '微信扫一扫',
          ),
          const _QrImage(
            asset: '${AssetCatalog.imageDir}/alipay.png',
            caption: '支付宝扫一扫',
          ),

          const PanelSectionHeader('官网二维码'),
          Image.network(
            _siteQrUrl,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            errorBuilder: (context, error, stackTrace) => Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '官网二维码加载失败\n（需要联网查看）',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '开发不易，多多支持。谢谢阅读！',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// 本地二维码 + 说明文字
class _QrImage extends StatelessWidget {
  const _QrImage({required this.asset, required this.caption});

  final String asset;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Image.asset(asset, width: double.infinity, fit: BoxFit.fitWidth),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}