import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_config.dart';
import '../constants/pref_keys.dart';

/// 服务端下发的运行时配置。
///
/// 存在的意义：**改行为不用发版**。心跳间隔、攒报大小、功德文案池、
/// 功能开关都放在服务端 `app_config` 表里，客户端冷启动时随 `/launch`
/// 一起拿到，本地缓存一份，离线也能用上次的配置。
///
/// 读取顺序：服务端下发的值 > [AppConfig] 里的本地默认值。
/// 任何一个键缺失都不影响运行。
class RemoteConfig {
  RemoteConfig._(this._values);

  Map<String, dynamic> _values;

  /// 空白配置（全部走本地默认值）
  factory RemoteConfig.empty() => RemoteConfig._(<String, dynamic>{});

  static Future<RemoteConfig> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(PrefKeys.remoteConfig);
      if (raw == null || raw.isEmpty) {
        return RemoteConfig.empty();
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return RemoteConfig._(decoded);
      }
    } catch (_) {
      // 缓存损坏时退回默认值，不影响启动
    }
    return RemoteConfig.empty();
  }

  /// 用服务端返回的配置覆盖本地缓存，并落盘
  Future<void> apply(Map<String, dynamic>? raw) async {
    if (raw == null || raw.isEmpty) {
      return;
    }
    _values = <String, dynamic>{..._values, ...raw};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefKeys.remoteConfig, jsonEncode(_values));
    } catch (_) {
      // 落盘失败只影响下次启动的默认值，不影响本次运行
    }
  }

  int _int(String key, int fallback) {
    final value = _values[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  double _double(String key, double fallback) {
    final value = _values[key];
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  bool _bool(String key, bool fallback) {
    final value = _values[key];
    if (value is bool) return value;
    if (value == null) return fallback;
    return '$value' == '1' || '$value'.toLowerCase() == 'true';
  }

  // ---- 上报节奏（做上下界保护，避免服务端配错值把客户端拖垮）----

  int get heartbeatSeconds =>
      _int('heartbeatInterval', AppConfig.heartbeatInterval.inSeconds).clamp(20, 1800);

  int get tapBatchSize => _int('tapBatchSize', AppConfig.tapBatchSize).clamp(1, 500);

  int get tapBatchIntervalMs =>
      _int('tapBatchIntervalMs', AppConfig.tapBatchInterval.inMilliseconds).clamp(500, 120000);

  /// 两次上报之间的最小间隔（毫秒）。
  ///
  /// 配合「空闲后首次敲击立即上报」使用，避免自动敲击把 QPS 顶上去。
  int get tapMinIntervalMs =>
      _int('tapMinIntervalMs', AppConfig.tapMinInterval.inMilliseconds).clamp(300, 60000);

  int get autoTapMinIntervalMs => _int('autoTapMinIntervalMs', 150).clamp(80, 5000);

  int get meritPerTap => _int('meritPerTap', AppConfig.meritPerTap).clamp(1, 100000);

  // ---- 功能开关 ----

  bool get leaderboardEnabled => _bool('enableLeaderboard', true);

  bool get blessingEnabled => _bool('enableBlessing', true);

  bool get feedbackEnabled => _bool('enableFeedback', true);

  /// 自动检查更新的间隔（小时），0 表示不自动检查
  int get updateCheckIntervalHours => _int('updateCheckIntervalH', 12).clamp(0, 720);

  // ---- 展示相关 ----

  double get defaultVolume => _double('defaultVolume', 0.8).clamp(0.0, 1.0);

  String get defaultSoundPack => '${_values['defaultSoundPack'] ?? 'muyu'}';

  String get defaultSkin => '${_values['defaultSkin'] ?? 'classic'}';

  /// 功德提示浮层的文案池；为空时由界面自行回退
  List<String> get tipTemplates {
    final value = _values['tipTemplates'];
    if (value is List) {
      return value.map((item) => '$item').where((item) => item.isNotEmpty).toList(growable: false);
    }
    return const <String>[];
  }

  Map<String, dynamic> get raw => Map<String, dynamic>.unmodifiable(_values);

  bool get isEmpty => _values.isEmpty;
}
