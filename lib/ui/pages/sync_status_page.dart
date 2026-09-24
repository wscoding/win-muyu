import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_config.dart';
import '../../state/providers.dart';
import '../widgets/panel_scaffold.dart';

/// 上报状态页。
///
/// 存在的理由很实际：敲击是 fire-and-forget，界面上**看不出**数据有没有
/// 真的发到服务端。用户发现网页看板不动时，第一个问题永远是「我的数据
/// 上去没有」，而此前没有任何地方能回答这个问题。
///
/// 这里把三件事摊开：本机设备标识、最近一次上报的结果、全网当前数字。
/// 后两项与网页看板同源，可以直接对照着看。
class SyncStatusPage extends ConsumerStatefulWidget {
  const SyncStatusPage({super.key});

  @override
  ConsumerState<SyncStatusPage> createState() => _SyncStatusPageState();
}

class _SyncStatusPageState extends ConsumerState<SyncStatusPage> {
  bool _loading = false;
  Map<String, dynamic>? _overview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final overview = await ref.read(telemetryServiceProvider).fetchOverview();
    if (!mounted) return;
    setState(() {
      _overview = overview;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final telemetry = ref.read(telemetryServiceProvider);
    final settings = ref.watch(settingsProvider);
    final deviceId = telemetry.identity.deviceId;

    final summary = _overview?['summary'];
    final today = summary is Map ? summary['today'] : null;
    final globalTaps = summary is Map ? summary['taps'] : null;
    final todayTaps = today is Map ? today['taps'] : null;
    final online = summary is Map ? summary['online'] : null;

    return PanelScaffold(
      title: '上报状态',
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: '刷新',
          onPressed: _loading ? null : _load,
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const PanelSectionHeader('本机'),
          _StatusRow(
            label: '设备标识',
            value: '${deviceId.substring(0, 8)}…',
            trailing: IconButton(
              icon: const Icon(Icons.content_copy, size: 18),
              tooltip: '复制完整标识',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: deviceId));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('设备标识已复制'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ),
          _StatusRow(
            label: '启用状态',
            value: settings.telemetryEnabled ? '已开启' : '已关闭',
            valueColor: settings.telemetryEnabled
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
          _StatusRow(
            label: '最近上报',
            value: _lastReportText(telemetry),
            valueColor: telemetry.lastReportOk == false ? scheme.error : null,
          ),
          _StatusRow(
            label: '服务端记录',
            value: '${telemetry.serverTaps} 次',
          ),

          const PanelSectionHeader('全网（与看板同源）'),
          if (_overview == null && !_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('暂时取不到全网数据。'),
            ),
          if (_overview != null) ...<Widget>[
            _StatusRow(label: '累计敲击', value: _fmt(globalTaps)),
            _StatusRow(label: '今日敲击', value: _fmt(todayTaps)),
            _StatusRow(label: '当前在线', value: _fmt(online)),
          ],

          const PanelSectionHeader('说明'),
          const PanelHint(
            '设备标识是本机随机生成并持久化的匿名串，不是硬件指纹，'
            '服务端无法据此回溯到具体的人。上报内容只有敲击累计数与平台版本，'
            '不含任何个人信息，也不记录每一次敲击的时间。',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.cloud_sync_outlined),
                  label: const Text('拉取全网数据'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openDashboard(),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('打开看板'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              '${AppConfig.siteUrl}/dashboard',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _lastReportText(dynamic telemetry) {
    final ok = telemetry.lastReportOk as bool?;
    if (ok == null) return '等待首次上报';
    if (!ok) return '失败（会自动重试）';
    final at = telemetry.lastReportAt as DateTime?;
    if (at == null) return '已成功';
    final seconds = DateTime.now().difference(at).inSeconds;
    return seconds < 60 ? '已成功 · 刚刚' : '已成功 · $seconds 秒前';
  }

  static String _fmt(Object? value) {
    if (value is num) return value.toInt().toString();
    return '—';
  }

  Future<void> _openDashboard() async {
    await Clipboard.setData(
      ClipboardData(text: '${AppConfig.siteUrl}/dashboard'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('看板地址已复制，粘贴到浏览器打开'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      title: Text(label),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: valueColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: trailing,
    );
  }
}
