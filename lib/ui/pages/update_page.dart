import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_config.dart';
import '../../models/app_settings.dart';
import '../../models/version_info.dart';
import '../../state/providers.dart';
import '../widgets/panel_scaffold.dart';

/// 版本更新页。
///
/// 后端（[AppConfig] 里的旧接口）目前是关停状态，网络请求必然失败，
/// 所以加载顺序是「先读本地缓存 → 再尝试网络覆盖」：
/// 页面任何时候都不会是空的，失败也只在状态行上说明原因。
class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({super.key});

  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage> {
  VersionInfo _info = VersionInfo.empty;
  String _status = '正在读取本地缓存…';
  bool _statusIsError = false;

  /// 初值就是 true：首帧直接显示加载中，省掉 initState 里的 setState
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// 缓存优先、网络其次。任何失败都只体现在 [_status] 上，不向外抛。
  Future<void> _load() async {
    final repository = ref.read(settingsRepositoryProvider);
    final telemetry = ref.read(telemetryServiceProvider);

    // 首次加载由字段初值负责；这里只为「刷新」按钮重置状态
    if (!_loading) {
      setState(() {
        _loading = true;
        _status = '正在读取本地缓存…';
        _statusIsError = false;
      });
    }

    final cached = await repository.loadCachedVersionInfo();
    if (!mounted) return;
    if (cached != null) {
      setState(() => _info = cached);
    }

    final settings = ref.read(settingsProvider);
    try {
      final remote = await telemetry.fetchVersionInfo(settings);
      await repository.saveVersionInfo(remote);
      if (!mounted) return;
      setState(() {
        _info = remote;
        _loading = false;
        _status = '已从服务器更新（${_timestamp()}）';
        _statusIsError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = _describeFailure(settings);
        _statusIsError = true;
      });
    }
  }

  /// fetchVersionInfo 在「后端开关关闭」与「网络失败」时抛出不同的异常，
  /// 但异常类型是私有的，这里按它的判定条件还原提示文案。
  static String _describeFailure(AppSettings settings) {
    if (!AppConfig.backendEnabled || !settings.telemetryEnabled) {
      return '后端未启用：当前展示的是本地缓存';
    }
    return '网络不可用：当前展示的是本地缓存';
  }

  static String _timestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  Future<void> _changeChannel(bool release) async {
    await ref.read(settingsProvider.notifier).patch(releaseChannel: release);
    if (!mounted) return;
    await _load();
  }

  bool get _canOpenDownload {
    final uri = Uri.tryParse(_info.downloadUrl);
    if (uri == null) return false;
    return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  Future<void> _openDownload() async {
    final uri = Uri.tryParse(_info.downloadUrl);
    if (uri == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        messenger.showSnackBar(_cannotOpen());
      }
    } catch (_) {
      // 后端关停时下载地址本身也可能不可达，这里只提示，不抛给上层
      messenger.showSnackBar(_cannotOpen());
    }
  }

  static SnackBar _cannotOpen() => const SnackBar(
    content: Text('打不开下载页，请稍后再试'),
    duration: Duration(seconds: 2),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    return PanelScaffold(
      title: '检查更新',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const PanelSectionHeader('渠道'),
          // RadioGroup 是 Flutter 3.32 之后推荐的写法，
          // Radio 自身的 groupValue / onChanged 已废弃
          RadioGroup<bool>(
            groupValue: settings.releaseChannel,
            onChanged: (value) {
              if (value == null) return;
              unawaited(_changeChannel(value));
            },
            child: const Column(
              children: [
                RadioListTile<bool>(
                  value: true,
                  title: Text('稳定版'),
                  subtitle: Text('release 渠道'),
                  dense: true,
                ),
                RadioListTile<bool>(
                  value: false,
                  title: Text('测试版'),
                  subtitle: Text('beta 渠道'),
                  dense: true,
                ),
              ],
            ),
          ),

          const PanelSectionHeader('状态'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (_loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    _statusIsError ? Icons.cloud_off : Icons.cloud_done,
                    size: 16,
                    color: _statusIsError
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _statusIsError
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _loading ? null : () => unawaited(_load()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _canOpenDownload
                        ? () => unawaited(_openDownload())
                        : null,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('打开下载页'),
                  ),
                ),
              ],
            ),
          ),
          PanelHint(
            _canOpenDownload
                ? '下载地址：${_info.downloadHost}'
                : '当前没有可用的下载地址（多为后端未启用导致）',
          ),

          const PanelSectionHeader('版本信息'),
          ..._infoRows(_info),
          PanelHint('本机客户端版本：${AppConfig.clientVersion}'),
        ],
      ),
    );
  }

  static List<Widget> _infoRows(VersionInfo info) => <Widget>[
    _InfoRow(label: '应用名称', value: info.appName),
    _InfoRow(label: '版本号', value: info.version),
    _InfoRow(label: '包名', value: info.packageName),
    _InfoRow(label: '构建号', value: info.buildNumber),
    _InfoRow(label: '构建签名', value: info.buildSignature),
    _InfoRow(label: '安装包来源', value: info.installerStore),
    _InfoRow(label: '构建日期', value: info.buildDate),
    _InfoRow(label: '更新日志', value: info.changeLog),
  ];
}

/// 「标签 + 值」的一行；值为空时显示占位符，避免整行空白看不出字段
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = value.trim().isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isEmpty ? '—' : value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isEmpty ? theme.colorScheme.outline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}