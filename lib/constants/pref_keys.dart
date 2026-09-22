/// SharedPreferences 的键名集中定义。
///
/// 历史键名（如 `isHelpme`、`_isSoundOno`、`selectmusic`）刻意保留原样，
/// 这样 v2.x 老用户升级到 v3 后设置不会丢失。新增键统一使用 lowerCamelCase。
class PrefKeys {
  const PrefKeys._();

  // ---- 敲击统计 ----
  static const String tapCount = 'tapCount';

  // ---- 外观 ----
  static const String isLight = 'isLight';
  static const String imageName = 'selectedImageName';

  // ---- 音源 ----
  /// 音源类型：`demusic` / `localmusic` / `urlmusic`
  static const String audioSource = 'selectedOption';

  /// 内置音效的资源路径，形如 `audio/muyu.mp3`
  static const String builtinAudioAsset = 'selectmusic';

  static const String localAudioPath = 'musicPath';
  static const String remoteAudioUrl = 'urlmusic';

  /// v2 早期版本曾用 `musicurl` 写入与 `urlmusic` 含义相同的值，
  /// 读取时做一次性迁移（见 [SettingsRepository]）。
  static const String legacyRemoteAudioUrl = 'musicurl';

  static const String soundEnabled = '_isSoundOno';
  static const String speedMultiplier = 'speedMultiplier';

  // ---- 自动敲击 ----
  static const String autoTapEnabled = 'isHelpme';

  /// v3 新增：自动敲击间隔（毫秒）
  static const String autoTapIntervalMs = 'autoTapIntervalMs';

  /// v2 用「秒」为单位的浮点数表示间隔，仅用于迁移
  static const String legacyAutoTapSeconds = 'timeText';

  // ---- 功德文案 ----
  static const String meritPrefix = 'autoText';
  static const String meritPrefixList = 'list';
  static const String meritSubtitle = 'moretext';

  // ---- 其它 ----
  /// v3 新增：是否允许匿名统计上报
  static const String telemetryEnabled = 'telemetryEnabled';

  /// 更新渠道：true = release，false = beta
  static const String releaseChannel = 'switchValue';

  static const String cachedVersionInfo = 'data';
  static const String aboutText = 'aboutText';
}