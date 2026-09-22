import 'package:flutter/material.dart';

import '../widgets/panel_scaffold.dart';

/// 软件协议页（静态文本）。
///
/// 类名刻意加了 `App` 前缀：Flutter Material 自带一个同名（`LicensePage`）的
/// 页面，若与之重名，忘记 import 本文件时会静默用到官方那个，行为不符。
/// 文案沿用作者原文（MIT，版权 2023.6 by 无书），只把技术栈一行
/// 更新为当前的 Flutter + Dart 3。
class AppLicensePage extends StatelessWidget {
  const AppLicensePage({super.key});

  static const String _mitParagraph1 =
      '特此授予任何获得本软件和相关文档文件（“软件”）副本的人员无限制地处理本软件的权利，'
      '包括但不限于使用、复制、修改、合并、出版、分发、再许可和/或销售本软件的副本，'
      '以及允许软件提供的人员这样做，但须符合以下条件：';

  static const String _mitParagraph2 = '本软件的所有副本或实质性部分必须包含上述版权声明、本条件声明和以下免责声明。';

  static const String _mitParagraph3 =
      '本软件按“原样”提供，不作任何明示或暗示的保证，包括但不限于适销性、特定用途的适用性和非侵权性的保证。'
      '在任何情况下，作者或版权持有人均不对任何索赔、损害赔偿或其他责任承担责任，'
      '无论是在合同、侵权行为或其他方面产生的，与本软件有关或与本软件的使用或其他交易有关。';

  static const String _privacy =
      '本软件保护用户隐私，不会收集用户的个人信息或隐私数据。本软件使用的第三方服务可能会收集一些匿名数据，'
      '用于改善软件的性能和用户体验。这些服务的隐私政策可能与本软件的隐私政策不同，'
      '请用户在使用本软件前仔细阅读相关服务的隐私政策。';

  static const String _opensource =
      '本软件基于 MIT 许可协议开源，任何人都可以自由使用、复制、修改、合并、出版、分发、再许可和/或销售本软件的副本。'
      '开源软件不提供任何担保或技术支持，开发者不承担因软件使用或修改而导致的任何责任。'
      '如有商业需求，请联系开发者获取商业授权。';

  static const String _contact =
      '开发者：\nLi Zhenyan\nQQ群号：574237747\n反馈电子邮箱：\n2821981550\n@qq.com\n软件技术：Flutter + Dart 3';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PanelScaffold(
      title: '软件协议',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Heading('MIT License', theme: theme),
            const SizedBox(height: 12),
            Text(
              '版权所有 (c)\n2023.6\nby 无书',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _Body(_mitParagraph1, theme: theme),
            const SizedBox(height: 8),
            _Body(_mitParagraph2, theme: theme),
            const SizedBox(height: 8),
            _Body(_mitParagraph3, theme: theme),

            const SizedBox(height: 24),
            _Heading('隐私政策', theme: theme),
            const SizedBox(height: 12),
            _Body(_privacy, theme: theme),

            const SizedBox(height: 24),
            _Heading('开源信息', theme: theme),
            const SizedBox(height: 12),
            _Body(_opensource, theme: theme),

            const SizedBox(height: 24),
            _Heading('联系我们', theme: theme),
            const SizedBox(height: 12),
            _Body(_contact, theme: theme),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text, {required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
    );
  }
}