import 'version_info.dart';

/// 更新日志的一条记录（对应服务端 `changelog_entries`）。
class ChangelogEntry {
  const ChangelogEntry({
    this.version = '',
    this.platform = 'all',
    this.kind = 'feature',
    this.title = '',
    this.body = '',
    this.releasedAt = '',
  });

  final String version;
  final String platform;

  /// feature / fix / improve / notice / breaking
  final String kind;
  final String title;
  final String body;
  final String releasedAt;

  static const Map<String, String> kindLabels = <String, String>{
    'feature': '功能',
    'fix': '修复',
    'improve': '优化',
    'notice': '公告',
    'breaking': '破坏性变更',
  };

  String get kindLabel => kindLabels[kind] ?? '更新';

  factory ChangelogEntry.fromJson(Map<String, dynamic> json) {
    String read(String key) => json[key]?.toString() ?? '';
    return ChangelogEntry(
      version: read('version'),
      platform: read('platform'),
      kind: read('kind'),
      title: read('title'),
      body: read('body'),
      releasedAt: read('released_at'),
    );
  }

  /// 把多行说明转成列表，便于界面用项目符号展示
  List<String> get bulletPoints => body
      .split(RegExp(r'\r?\n'))
      .map((line) => line.replaceFirst(RegExp(r'^[-*•]\s*'), '').trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

/// `GET /api/v1/version` 的结果。
///
/// 服务端把「是否需要更新」「是否强制更新」的判定都做完了，
/// 客户端只需要读这几个布尔值——这样运营策略（强制升级、下架旧版本）
/// 不需要发版就能生效。
class UpdateCheckResult {
  const UpdateCheckResult({
    this.latest = VersionInfo.empty,
    this.current = '',
    this.hasUpdate = false,
    this.forceUpgrade = false,
    this.updateType = 'none',
    this.reason = '',
    this.tip = '',
    this.changelog = const <ChangelogEntry>[],
  });

  /// 服务端上的最新版本；为 null（用 [hasRelease] 判断）表示该平台还没有发布记录
  final VersionInfo latest;

  final String current;
  final bool hasUpdate;

  /// 强制更新：由服务端 `force_upgrade` 或「当前版本低于最低支持版本」触发
  final bool forceUpgrade;

  /// none / patch / minor / major / unknown
  final String updateType;

  /// 强制更新的原因：force_upgrade / below_min_supported
  final String reason;

  /// 服务端给的一句提示语，可直接展示
  final String tip;

  final List<ChangelogEntry> changelog;

  bool get hasRelease => latest.version.isNotEmpty || latest.downloadUrl.isNotEmpty;

  /// 更新幅度的中文说明
  String get updateTypeLabel {
    switch (updateType) {
      case 'major':
        return '大版本更新';
      case 'minor':
        return '功能更新';
      case 'patch':
        return '修复更新';
      case 'unknown':
        return '新版本';
      default:
        return '已是最新';
    }
  }

  factory UpdateCheckResult.fromJson(Map<String, dynamic> json) {
    final latestRaw = json['latest'];
    final entries = json['changelog'];
    return UpdateCheckResult(
      latest: latestRaw is Map<String, dynamic>
          ? VersionInfo.fromJson(latestRaw)
          : VersionInfo.empty,
      current: json['current']?.toString() ?? '',
      hasUpdate: json['has_update'] == true,
      forceUpgrade: json['force_upgrade'] == true,
      updateType: json['update_type']?.toString() ?? 'none',
      reason: json['reason']?.toString() ?? '',
      tip: json['upgrade_tip']?.toString() ?? '',
      changelog: entries is List
          ? entries
              .whereType<Map<String, dynamic>>()
              .map(ChangelogEntry.fromJson)
              .toList(growable: false)
          : const <ChangelogEntry>[],
    );
  }
}
