import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../constants/asset_catalog.dart';
import '../models/app_settings.dart';
import '../services/app_lifecycle.dart';
import '../state/providers.dart';
import 'pages/builtin_sound_page.dart';
import 'pages/image_picker_page.dart';
import 'pages/leaderboard_page.dart';
import 'pages/license_page.dart';
import 'pages/local_sound_page.dart';
import 'pages/merit_pool_page.dart';
import 'pages/merit_prefix_page.dart';
import 'pages/more_page.dart';
import 'pages/sync_status_page.dart';
import 'pages/remote_sound_page.dart';
import 'pages/sound_source_page.dart';
import 'pages/speed_page.dart';
import 'pages/tap_count_page.dart';
import 'widgets/panel_scaffold.dart';

/// 设置菜单。
///
/// 由悬浮窗口右键打开。打开时窗口会被撑到面板尺寸（见
/// `DesktopWindowService.enterPanelMode`），关闭后自动还原。
class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final tapCount = ref.watch(tapCounterProvider);

    return PanelScaffold(
      title: 'Prue Widgets 设置',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          // 每日一签：服务端已就绪（/blessing），这里只是把展示补上。
          // 放在最顶部当作"仪式感"入口，拉不到就整块不显示，不打扰。
          if (settings.telemetryEnabled) const _BlessingCard(),
          const PanelSectionHeader('外观'),
          ListTile(
            title: const Text('木鱼图案'),
            subtitle: Text(settings.imageName),
            leading: const Icon(Icons.image_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const ImagePickerPage()),
          ),
          SwitchListTile(
            title: const Text('黑色图案'),
            subtitle: const Text('关闭则为白色，长按木鱼也能切换'),
            secondary: const Icon(Icons.invert_colors),
            value: settings.isLight,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).patch(isLight: value),
          ),

          const PanelSectionHeader('音效'),
          SwitchListTile(
            title: const Text('敲击声'),
            secondary: const Icon(Icons.volume_up_outlined),
            value: settings.soundEnabled,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).patch(soundEnabled: value),
          ),
          ListTile(
            title: const Text('音源'),
            subtitle: Text(_audioSourceSummary(settings)),
            leading: const Icon(Icons.library_music_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const SoundSourcePage()),
          ),
          ListTile(
            title: const Text('内置音效'),
            subtitle: Text(_builtinSoundLabel(settings)),
            leading: const Icon(Icons.graphic_eq),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const BuiltinSoundPage()),
          ),
          if (settings.audioSourceType == AudioSourceType.local)
            ListTile(
              title: const Text('本地音频文件'),
              subtitle: Text(
                settings.localAudioPath.isEmpty ? '未选择' : settings.localAudioPath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              leading: const Icon(Icons.folder_open_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _push(context, const LocalSoundPage()),
            ),
          if (settings.audioSourceType == AudioSourceType.remote)
            ListTile(
              title: const Text('网络音频直链'),
              subtitle: Text(
                settings.remoteAudioUrl.isEmpty ? '未设置' : settings.remoteAudioUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              leading: const Icon(Icons.link),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _push(context, const RemoteSoundPage()),
            ),
          ListTile(
            title: const Text('播放速度'),
            subtitle: Text('${settings.speedMultiplier.toStringAsFixed(1)}x'),
            leading: const Icon(Icons.speed),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const SpeedPage()),
          ),

          const PanelSectionHeader('敲击'),
          SwitchListTile(
            title: const Text('帮我敲'),
            subtitle: const Text('开启后自动持续敲击'),
            secondary: const Icon(Icons.auto_mode),
            value: settings.autoTapEnabled,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).patch(autoTapEnabled: value),
          ),
          _AutoTapIntervalTile(settings: settings),
          ListTile(
            title: const Text('功德文字'),
            subtitle: Text('当前：${settings.meritPrefix}'),
            leading: const Icon(Icons.text_fields),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const MeritPrefixPage()),
          ),
          ListTile(
            title: const Text('祝福语池'),
            subtitle: Text('${settings.meritPrefixPool.length} 条，满 100 次后随机展示'),
            leading: const Icon(Icons.format_list_bulleted),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const MeritPoolPage()),
          ),

          const PanelSectionHeader('数据'),
          ListTile(
            title: const Text('敲击统计'),
            subtitle: Text('$tapCount 次'),
            leading: const Icon(Icons.bar_chart),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const TapCountPage()),
          ),
          SwitchListTile(
            title: const Text('匿名统计上报'),
            subtitle: const Text('只看得见敲击数，不含任何个人信息，可随时关闭'),
            secondary: const Icon(Icons.cloud_upload_outlined),
            value: settings.telemetryEnabled,
            onChanged: (value) => ref
                .read(settingsProvider.notifier)
                .patch(telemetryEnabled: value),
          ),
          if (settings.telemetryEnabled) ...<Widget>[
            ListTile(
              title: const Text('功德榜'),
              subtitle: const Text('参与全网排行，昵称打码'),
              leading: const Icon(Icons.leaderboard_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _push(context, const LeaderboardPage()),
            ),
            ListTile(
              title: const Text('上报状态'),
              subtitle: Text(_telemetrySummary(ref)),
              leading: const Icon(Icons.sync_alt),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _push(context, const SyncStatusPage()),
            ),
          ],

          const PanelSectionHeader('关于'),
          ListTile(
            title: const Text('更多'),
            subtitle: const Text('更新、协议、赞助'),
            leading: const Icon(Icons.more_horiz),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const MorePage()),
          ),
          ListTile(
            title: const Text('软件协议'),
            leading: const Icon(Icons.description_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const AppLicensePage()),
          ),
          const Divider(height: 24),
          ListTile(
            title: const Text('退出 Prue Widgets'),
            leading: const Icon(Icons.power_settings_new),
            onTap: () => shutdownApp(ref),
          ),
        ],
      ),
    );
  }

  /// 菜单里那一行「上报状态」的副标题：一句话说清数据上去没有
  static String _telemetrySummary(WidgetRef ref) {
    final telemetry = ref.read(telemetryServiceProvider);
    final ok = telemetry.lastReportOk;
    if (ok == null) return '等待首次上报';
    if (!ok) return '最近一次上报失败，将自动重试';
    final at = telemetry.lastReportAt;
    if (at == null) return '已上报';
    final seconds = DateTime.now().difference(at).inSeconds;
    final when = seconds < 60 ? '刚刚' : '$seconds 秒前';
    return '已上报 · $when · 全网 ${telemetry.globalTaps}';
  }

  static Future<void> _push(BuildContext context, Widget page) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  static String _audioSourceSummary(AppSettings settings) {
    return switch (settings.audioSourceType) {
      AudioSourceType.builtin => '内置音效',
      AudioSourceType.local => '本地文件',
      AudioSourceType.remote => '网络直链',
    };
  }

  static String _builtinSoundLabel(AppSettings settings) {
    final name = AssetCatalog.soundNameFromAsset(settings.builtinAudioAsset);
    return AssetCatalog.builtinSounds[name] ?? name;
  }
}

/// 每日一签。
///
/// 服务端同一天返回同一条、次日自动轮换。拉不到就整块不渲染 ——
/// 这是个锦上添花的东西，不该在离线时占一块位置显示「加载失败」。
class _BlessingCard extends ConsumerStatefulWidget {
  const _BlessingCard();

  @override
  ConsumerState<_BlessingCard> createState() => _BlessingCardState();
}

class _BlessingCardState extends ConsumerState<_BlessingCard> {
  String? _blessing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final settings = ref.read(settingsProvider);
    final text = await ref
        .read(telemetryServiceProvider)
        .fetchBlessing(settings);
    if (!mounted || text == null || text.isEmpty) return;
    setState(() => _blessing = text);
  }

  @override
  Widget build(BuildContext context) {
    final blessing = _blessing;
    if (blessing == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                blessing,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 自动敲击间隔：直接在菜单里调节，避免再进一层页面
class _AutoTapIntervalTile extends ConsumerWidget {
  const _AutoTapIntervalTile({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interval = settings.autoTapIntervalMs;
    final enabled = settings.autoTapEnabled;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 18),
              const SizedBox(width: 8),
              const Text('敲击间隔'),
              const Spacer(),
              Text(
                '${(1000 / interval).toStringAsFixed(1)} 次/秒',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          Slider(
            value: interval.toDouble(),
            min: AppConstants.minAutoTapIntervalMs.toDouble(),
            max: AppConstants.maxAutoTapIntervalMs.toDouble(),
            divisions:
                (AppConstants.maxAutoTapIntervalMs -
                    AppConstants.minAutoTapIntervalMs) ~/
                50,
            label: '${interval}ms',
            onChanged: enabled
                ? (value) => ref
                      .read(settingsProvider.notifier)
                      .patch(autoTapIntervalMs: value.round())
                : null,
          ),
        ],
      ),
    );
  }
}