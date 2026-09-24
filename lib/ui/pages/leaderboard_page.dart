import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_config.dart';
import '../../state/providers.dart';
import '../widgets/panel_scaffold.dart';

/// 功德榜。
///
/// 服务端早就就绪（`/leaderboard`、`/profile`、`/profile/opt-in`），
/// 这里只是把界面补上。两点必须遵守的产品约束：
/// - **默认不参与**：必须用户显式开启并设置昵称才上榜；
/// - **昵称打码**：打码在服务端完成，端上原样展示即可，不需要再处理。
class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> {
  static const List<(String, String)> _ranges = <(String, String)>[
    ('week', '本周'),
    ('month', '本月'),
    ('all', '总榜'),
  ];

  String _range = 'week';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];
  Map<String, dynamic>? _profile;
  final TextEditingController _nickname = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nickname.text = '施主';
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final telemetry = ref.read(telemetryServiceProvider);
    final items = await telemetry.fetchLeaderboard(range: _range, limit: 20);
    final profile = await telemetry.fetchProfile();

    if (!mounted) return;
    setState(() {
      _items = items;
      _profile = profile;
      _loading = false;
      // 两个都没拿到才算失败：榜单本来就可能为空
      _error = (items.isEmpty && profile == null) ? '暂时取不到榜单数据' : null;
    });
  }

  Future<void> _setOptIn(bool enabled) async {
    final settings = ref.read(settingsProvider);
    final nickname = _nickname.text.trim();
    if (enabled && nickname.isEmpty) {
      setState(() => _error = '上榜需要先填一个昵称');
      return;
    }

    final result = await ref
        .read(telemetryServiceProvider)
        .setLeaderboardOptIn(
          settings: settings,
          enabled: enabled,
          nickname: nickname,
        );
    if (!mounted) return;
    if (result == null) {
      setState(() => _error = '设置失败，请检查网络后重试');
      return;
    }
    final profile = result['profile'];
    setState(() {
      _profile = profile is Map ? profile.cast<String, dynamic>() : _profile;
      _error = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final optedIn = _profile?['rank_opt_in'] == true;

    return PanelScaffold(
      title: '功德榜',
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: '刷新',
          onPressed: _load,
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const PanelSectionHeader('我的状态'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _ProfileCard(profile: _profile, loading: _loading),
          ),
          const PanelSectionHeader('上榜设置'),
          SwitchListTile(
            title: const Text('参与功德榜'),
            subtitle: const Text('关闭后立即从榜单移除，昵称已打码'),
            secondary: const Icon(Icons.visibility_outlined),
            value: optedIn,
            onChanged: (value) => _setOptIn(value),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nickname,
                    decoration: const InputDecoration(
                      labelText: '昵称',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 16,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => _setOptIn(optedIn),
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
          const PanelSectionHeader('榜单'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<String>(
              segments: _ranges
                  .map(
                    (range) => ButtonSegment<String>(
                      value: range.$1,
                      label: Text(range.$2),
                    ),
                  )
                  .toList(growable: false),
              selected: <String>{_range},
              onSelectionChanged: (selection) {
                setState(() => _range = selection.first);
                _load();
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          if (_items.isEmpty && _error == null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('还没有人上榜。打开上面的开关就能出现在榜上。'),
            ),
          ..._items.map((item) => _BoardRow(item: item)),
          PanelHint('数据与网页看板同源：${AppConfig.siteUrl}/dashboard'),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.loading});

  final Map<String, dynamic>? profile;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final title = profile?['title']?.toString() ?? '—';
    final taps = profile?['taps_total'] ?? 0;
    final rank = profile?['rank'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loading ? '读取中…' : title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '服务端记录 ${_fmt(taps)} 次敲击'
            '${rank == null ? '' : ' · 第 $rank 名'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(Object? value) {
    if (value is num) return value.toInt().toString();
    return '0';
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rank = item['rank']?.toString() ?? '-';
    final nickname = item['nickname']?.toString() ?? '匿名施主';
    final taps = item['taps'] is num ? (item['taps'] as num).toInt() : 0;

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: rank == '1'
            ? const Color(0xFFD9A441)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(rank, style: const TextStyle(fontSize: 12)),
      ),
      title: Text(nickname),
      trailing: Text(
        '$taps',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
