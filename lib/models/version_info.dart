import 'dart:convert';

/// 后端返回的版本信息。
///
/// 字段名沿用 v2 `version.json` 的结构，便于后续后端重写时保持兼容。
/// 约定见 `docs/backend-api.md`。
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

  static const VersionInfo empty = VersionInfo();

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    String read(String key) => json[key]?.toString() ?? '';
    return VersionInfo(
      appName: read('appName'),
      version: read('version'),
      packageName: read('packageName'),
      buildNumber: read('buildNumber'),
      buildSignature: read('buildSignature'),
      installerStore: read('installerStore'),
      buildDate: read('appbuild'),
      changeLog: read('newlog'),
      downloadUrl: read('download'),
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
    'version': version,
    'packageName': packageName,
    'buildNumber': buildNumber,
    'buildSignature': buildSignature,
    'installerStore': installerStore,
    'appbuild': buildDate,
    'newlog': changeLog,
    'download': downloadUrl,
  };

  /// 下载链接的域名，用于在界面上展示来源站点
  String get downloadHost {
    final uri = Uri.tryParse(downloadUrl);
    return uri?.host ?? '';
  }

  bool get isEmpty => version.isEmpty && downloadUrl.isEmpty && appName.isEmpty;
}