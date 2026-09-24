import 'package:flutter/foundation.dart';

/// 敲击音效的来源类型。
///
/// 对应 v2 的 `selectedOption`，沿用其字符串取值以免老数据失效。
enum AudioSourceType {
  /// 内置音效
  builtin('demusic'),

  /// 本地文件
  local('localmusic'),

  /// 网络直链
  remote('urlmusic');

  const AudioSourceType(this.storageValue);

  /// 持久化到 SharedPreferences 时使用的字符串
  final String storageValue;

  static AudioSourceType fromStorage(String? value) {
    return AudioSourceType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => AudioSourceType.builtin,
    );
  }

  String get label => switch (this) {
    AudioSourceType.builtin => '内置',
    AudioSourceType.local => '本地',
    AudioSourceType.remote => 'URL',
  };
}

/// 全部应用设置。
///
/// 设计为不可变对象：所有修改都通过 [copyWith] 产生新实例，
/// 这样 Riverpod 能可靠地判断状态是否变化，也便于单元测试。
@immutable
class AppSettings {
  const AppSettings({
    this.isLight = false,
    this.imageName = 'muyu',
    this.audioSourceType = AudioSourceType.builtin,
    this.builtinAudioAsset = 'audio/muyu.mp3',
    this.localAudioPath = '',
    this.remoteAudioUrl = '',
    this.soundEnabled = true,
    this.speedMultiplier = 1.0,
    this.autoTapEnabled = false,
    this.autoTapIntervalMs = 1000,
    this.meritPrefix = '功德',
    this.meritSubtitle = '平安',
    this.meritPrefixPool = const <String>[],
    this.telemetryEnabled = true,
    this.releaseChannel = false,
  });

  /// 木鱼图案颜色：true = 黑色，false = 白色
  final bool isLight;

  /// 当前皮肤图片名（不含目录与扩展名）
  final String imageName;

  final AudioSourceType audioSourceType;

  /// 内置音效资源路径，如 `audio/muyu.mp3`
  final String builtinAudioAsset;

  /// 本地音效文件绝对路径
  final String localAudioPath;

  /// 网络音效直链
  final String remoteAudioUrl;

  final bool soundEnabled;

  /// 播放速率倍率
  final double speedMultiplier;

  /// 是否自动敲击
  final bool autoTapEnabled;

  /// 自动敲击间隔（毫秒）
  final int autoTapIntervalMs;

  /// 功德文案前缀，用于敲击次数 < 100 时展示
  final String meritPrefix;

  /// 累计满 100 次后展示的文案
  final String meritSubtitle;

  /// 用户自定义的文案池，展示时随机取一条
  final List<String> meritPrefixPool;

  /// 是否允许匿名统计上报。
  ///
  /// 默认**开启**：这是全网数据看板（`https://wid.chr.cc/dashboard`）唯一的
  /// 数据来源，关掉就没有人能看到敲击数字了。上报内容只有匿名设备标识与
  /// 敲击累计数，**不含任何个人信息**（设备标识是本地随机生成并持久化的，
  /// 不是硬件指纹），用户可随时在这里关掉。
  final bool telemetryEnabled;

  /// 更新渠道：true = release，false = beta
  final bool releaseChannel;

  AppSettings copyWith({
    bool? isLight,
    String? imageName,
    AudioSourceType? audioSourceType,
    String? builtinAudioAsset,
    String? localAudioPath,
    String? remoteAudioUrl,
    bool? soundEnabled,
    double? speedMultiplier,
    bool? autoTapEnabled,
    int? autoTapIntervalMs,
    String? meritPrefix,
    String? meritSubtitle,
    List<String>? meritPrefixPool,
    bool? telemetryEnabled,
    bool? releaseChannel,
  }) {
    return AppSettings(
      isLight: isLight ?? this.isLight,
      imageName: imageName ?? this.imageName,
      audioSourceType: audioSourceType ?? this.audioSourceType,
      builtinAudioAsset: builtinAudioAsset ?? this.builtinAudioAsset,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      remoteAudioUrl: remoteAudioUrl ?? this.remoteAudioUrl,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
      autoTapEnabled: autoTapEnabled ?? this.autoTapEnabled,
      autoTapIntervalMs: autoTapIntervalMs ?? this.autoTapIntervalMs,
      meritPrefix: meritPrefix ?? this.meritPrefix,
      meritSubtitle: meritSubtitle ?? this.meritSubtitle,
      meritPrefixPool: meritPrefixPool ?? this.meritPrefixPool,
      telemetryEnabled: telemetryEnabled ?? this.telemetryEnabled,
      releaseChannel: releaseChannel ?? this.releaseChannel,
    );
  }

  /// 当前生效的音效来源；不可用时返回 `null`，调用方据此静默跳过播放
  ({AudioSourceType type, String value})? get activeAudioSource {
    switch (audioSourceType) {
      case AudioSourceType.builtin:
        return (type: audioSourceType, value: builtinAudioAsset);
      case AudioSourceType.local:
        if (localAudioPath.isEmpty) return null;
        return (type: audioSourceType, value: localAudioPath);
      case AudioSourceType.remote:
        if (remoteAudioUrl.isEmpty) return null;
        return (type: audioSourceType, value: remoteAudioUrl);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.isLight == isLight &&
        other.imageName == imageName &&
        other.audioSourceType == audioSourceType &&
        other.builtinAudioAsset == builtinAudioAsset &&
        other.localAudioPath == localAudioPath &&
        other.remoteAudioUrl == remoteAudioUrl &&
        other.soundEnabled == soundEnabled &&
        other.speedMultiplier == speedMultiplier &&
        other.autoTapEnabled == autoTapEnabled &&
        other.autoTapIntervalMs == autoTapIntervalMs &&
        other.meritPrefix == meritPrefix &&
        other.meritSubtitle == meritSubtitle &&
        listEquals(other.meritPrefixPool, meritPrefixPool) &&
        other.telemetryEnabled == telemetryEnabled &&
        other.releaseChannel == releaseChannel;
  }

  @override
  int get hashCode => Object.hash(
    isLight,
    imageName,
    audioSourceType,
    builtinAudioAsset,
    localAudioPath,
    remoteAudioUrl,
    soundEnabled,
    speedMultiplier,
    autoTapEnabled,
    autoTapIntervalMs,
    meritPrefix,
    meritSubtitle,
    Object.hashAll(meritPrefixPool),
    telemetryEnabled,
    releaseChannel,
  );
}