import 'dart:convert';

/// 版本发布信息。
///
/// 同时兼容两种字段风格：
/// - v3 接口 `GET /api/v1/version` 返回的 `latest` 对象（snake_case）；
/// - 本地缓存（本类的 [toJson] 写入，同样落 snake_case）。
///
/// 这样 v2 时代缓存下来的数据也能正常读出，不会因为字段改名而白屏
/// （旧字段名 `appbuild`/`newlog`/`download` 仍在读取列表中）。
///
/// 接口约定见 `docs/api-v3.md`。
class VersionInfo {
  const VersionInfo({
    this.appName = '',
    this.version = '',
    this.packageName = '',
    this.buildNumber = '',
    this.buildSignature = '',
    this.installerStore = '',
    this.buildDate = '',
    this.changeLog = '',
    this.downloadUrl = '',
    this.platform = '',
    this.channel = '',
    this.fileSize = 0,
    this.fileHash = '',
    this.publishedAt = '',
  });

  final String appName;
  final String version;
  final String packageName;
  final String buildNumber;
  final String buildSignature;
  final String installerStore;
  final String buildDate;
  final String changeLog;
  final String downloadUrl;

  /// 平台标识（windows / macos / android / ios），v2 的接口没有这个字段
  final String platform;

  /// 渠道：release / beta
  final String channel;

  /// 安装包体积（字节），未知为 0
  final int fileSize;

  /// 安装包哈希（`sha256:...`），未提供为空串
  final String fileHash;

  /// 发布时间
  final String publishedAt;

  static const VersionInfo empty = VersionInfo();

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    // 一个字段可能有多种写法，按优先级依次尝试
    String read(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().isNotEmpty) {
          return value.toString();
        }
      }
      return '';
    }

    return VersionInfo(
      appName: read(<String>['appName', 'app_name']),
      version: read(<String>['version']),
      packageName: read(<String>['packageName', 'package_name']),
      buildNumber: read(<String>['build_number', 'buildNumber']),
      buildSignature: read(<String>['build_signature', 'buildSignature']),
      installerStore: read(<String>['installer_store', 'installerStore']),
      buildDate: read(<String>['appbuild', 'build_date']),
      changeLog: read(<String>['newlog', 'change_log']),
      downloadUrl: read(<String>['download_url', 'download']),
      platform: read(<String>['platform']),
      channel: read(<String>['channel']),
      fileSize: int.tryParse(read(<String>['file_size'])) ?? 0,
      fileHash: read(<String>['file_hash']),
      publishedAt: read(<String>['published_at']),
    );
  }

  factory VersionInfo.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('版本信息不是合法的 JSON 对象');
    }
    return VersionInfo.fromJson(decoded);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'appName': appName,
    'packageName': packageName,
    'version': version,
    'build_number': buildNumber,
    'build_signature': buildSignature,
    'installer_store': installerStore,
    'appbuild': buildDate,
    'newlog': changeLog,
    'download_url': downloadUrl,
    'platform': platform,
    'channel': channel,
    'file_size': fileSize,
    'file_hash': fileHash,
    'published_at': publishedAt,
  };

  /// 下载链接的域名，用于在界面上展示来源站点
  String get downloadHost {
    final uri = Uri.tryParse(downloadUrl);
    return uri?.host ?? '';
  }

  /// 体积的可读形式（未知返回空串，界面据此隐藏该行）
  String get fileSizeLabel {
    if (fileSize <= 0) return '';
    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = fileSize.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return '${index == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)}'
        ' ${units[index]}';
  }

  bool get isEmpty => version.isEmpty && downloadUrl.isEmpty && appName.isEmpty;
}
