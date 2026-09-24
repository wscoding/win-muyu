import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_config.dart';
import '../../models/app_settings.dart';
import '../../models/update_check_result.dart';
import '../../models/version_info.dart';
import '../../services/telemetry_service.dart';
import '../../state/providers.dart';
import '../widgets/panel_scaffold.dart';

/// 版本更新页。
///
/// 加载顺序是「先读本地缓存 → 再请求服务端覆盖」：
/// 页面任何时候都不会空白，失败也只在状态行上说明原因。
/// 是否更新、是否**强制**更新全部由服务端判定（见 [UpdateCheckResult]），
/// 所以在服务端勾一下「强制更新」就能生效，不需要发版。
class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({super.key});

  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage> {
  VersionInfo _info = VersionInfo.empty;

  /// 服务端的检测结果（含是否强制更新与更新日志）
  UpdateCheckResult? _check;

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
      final result = await telemetry.fetchVersionInfo(settings);
      await repository.saveVersionInfo(result.latest);
      if (!mounted) return;
      setState(() {
        _info = result.latest;
        _check = result;
        _loading = false;
        _statusIsError = false;
        _status = _describeSuccess(result);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = _describeFailure(settings, error);
        _statusIsError = true;
      });
    }
  }

  static String _describeSuccess(UpdateCheckResult result) {
    if (!result.hasRelease) {
      return '服务端暂无该平台的发布记录（${_timestamp()}）';
    }
    if (result.hasUpdate) {
      final prefix = result.forceUpgrade ? '需要立即更新' : '发现${result.updateTypeLabel}';
      return '$prefix：v${result.latest.version}（${_timestamp()}）';
    }
    return '已是最新版本（${_timestamp()}）';
  }

  /// 把「功能关闭」「网络失败」「服务端业务错误」分开提示，
  /// 避免用户看到「网络不可用」却其实是自己关掉了统计开关。
  static String _describeFailure(AppSettings settings, Object error) {
    if (error is TelemetrySkipped) {
      return '统计上报已关闭：当前展示的是本地缓存';
    }
    if (!AppConfig.backendEnabled || !settings.telemetryEnabled) {
      return '后端未启用：当前展示的是本地缓存';
    }
    if (error is TelemetryApiException) {
      return '服务端返回错误：${error.message}';
    }
    if (error is TelemetryHttpException) {
      return '服务端返回 HTTP ${error.statusCode}：当前展示的是本地缓存';
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
      // 下载地址可能暂不可达，这里只提示，不抛给上层
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
    final check = _check;

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
                : '当前没有可用的下载地址',
          ),

          // ---- 服务端判定的更新提示 ----
          if (check != null && check.hasRelease) ...[
            const PanelSectionHeader('更新提示'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _UpdateBanner(result: check),
            ),
            if (check.tip.isNotEmpty) PanelHint(check.tip),
          ],

          // ---- 更新日志（服务端 changelog_entries）----
          if (check != null && check.changelog.isNotEmpty) ...[
            const PanelSectionHeader('更新日志'),
            for (final entry in check.changelog) _ChangelogTile(entry: entry),
          ],

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
    _InfoRow(label: '构建号', value: info.buildNumber),
    _InfoRow(label: '构建签名', value: info.buildSignature),
    _InfoRow(label: '安装包来源', value: info.installerStore),
    _InfoRow(label: '构建日期', value: info.buildDate),
    _InfoRow(label: '安装包体积', value: info.fileSizeLabel),
    _InfoRow(label: '发布时间', value: info.publishedAt),
    _InfoRow(label: '更新说明', value: info.changeLog),
  ];
}

/// 更新提示条：是否需要更新、是否强制
class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.result});

  final UpdateCheckResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUpdate = result.hasUpdate;
    final forced = result.forceUpgrade;

    final color = forced
        ? theme.colorScheme.errorContainer
        : hasUpdate
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest;
    final onColor = forced
        ? theme.colorScheme.onErrorContainer
        : hasUpdate
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasUpdate ? Icons.system_update_alt : Icons.check_circle_outline,
                size: 16,
                color: onColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasUpdate
                      ? '${result.updateTypeLabel} v${result.latest.version}'
                      : '当前已是最新版本',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (forced)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '强制更新',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onError,
                    ),
                  ),
                ),
            ],
          ),
          if (hasUpdate) ...[
            const SizedBox(height: 4),
            Text(
              '当前 ${result.current.isEmpty ? AppConfig.clientVersion : result.current}'
              ' → 最新 ${result.latest.version}',
              style: theme.textTheme.bodySmall?.copyWith(color: onColor),
            ),
          ],
        ],
      ),
    );
  }
}

/// 一条更新日志
class _ChangelogTile extends StatelessWidget {
  const _ChangelogTile({required this.entry});

  final ChangelogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bullets = entry.bulletPoints;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (entry.version.isNotEmpty)
                Text(
                  'v${entry.version}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.kindLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              if (entry.releasedAt.isNotEmpty)
                Text(
                  entry.releasedAt,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(entry.title, style: theme.textTheme.bodyMedium),
          if (bullets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in bullets)
                    Text(
                      '· $line',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            )
          else if (entry.body.isNotEmpty)
            Text(
              entry.body,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
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
