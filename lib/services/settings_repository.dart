import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../constants/asset_catalog.dart';
import '../constants/pref_keys.dart';
import '../models/app_settings.dart';
import '../models/version_info.dart';

/// 设置与本地数据的读写入口。
///
/// v2 里每个页面各自 `SharedPreferences.getInstance()` 并散落读取逻辑，
/// 且存在「读一个键、写另一个键」的错位（如 `musicurl` / `urlmusic` 混用、
/// `autofile` 与 `selectmusic` 混用）。这里统一收口，并在 [load] 时做一次性迁移。
class SettingsRepository {
  SettingsRepository({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<AppSettings> load() async {
    final prefs = await _prefs;

    await _migrateLegacyKeys(prefs);

    final pool = _readStringList(prefs, PrefKeys.meritPrefixList);

    return AppSettings(
      isLight: prefs.getBool(PrefKeys.isLight) ?? AppConstants.defaultIsLight,
      imageName:
          _nonEmpty(prefs.getString(PrefKeys.imageName)) ??
          AppConstants.defaultImageName,
      audioSourceType: AudioSourceType.fromStorage(
        prefs.getString(PrefKeys.audioSource),
      ),
      builtinAudioAsset: AssetCatalog.audioAssetPath(
        _nonEmpty(prefs.getString(PrefKeys.builtinAudioAsset)) ??
            AssetCatalog.defaultSound,
      ),
      localAudioPath: prefs.getString(PrefKeys.localAudioPath) ?? '',
      remoteAudioUrl: prefs.getString(PrefKeys.remoteAudioUrl) ?? '',
      soundEnabled: prefs.getBool(PrefKeys.soundEnabled) ?? true,
      speedMultiplier: _clampDouble(
        prefs.getDouble(PrefKeys.speedMultiplier) ?? 1.0,
        AppConstants.minSpeedMultiplier,
        AppConstants.maxSpeedMultiplier,
      ),
      autoTapEnabled: prefs.getBool(PrefKeys.autoTapEnabled) ?? false,
      autoTapIntervalMs: _clampInt(
        prefs.getInt(PrefKeys.autoTapIntervalMs) ??
            AppConstants.defaultAutoTapIntervalMs,
        AppConstants.minAutoTapIntervalMs,
        AppConstants.maxAutoTapIntervalMs,
      ),
      meritPrefix:
          _nonEmpty(prefs.getString(PrefKeys.meritPrefix)) ??
          AppConstants.defaultMeritPrefix,
      meritSubtitle:
          _nonEmpty(prefs.getString(PrefKeys.meritSubtitle)) ??
          AppConstants.defaultMeritSubtitle,
      meritPrefixPool: pool,
      // 后端已下线，默认不上报；老用户此前是被强制上报的，这里同样默认为关闭
      telemetryEnabled: prefs.getBool(PrefKeys.telemetryEnabled) ?? false,
      releaseChannel: prefs.getBool(PrefKeys.releaseChannel) ?? false,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await _prefs;
    await Future.wait<void>(<Future<void>>[
      prefs.setBool(PrefKeys.isLight, settings.isLight),
      prefs.setString(PrefKeys.imageName, settings.imageName),
      prefs.setString(PrefKeys.audioSource, settings.audioSourceType.storageValue),
      prefs.setString(PrefKeys.builtinAudioAsset, settings.builtinAudioAsset),
      prefs.setString(PrefKeys.localAudioPath, settings.localAudioPath),
      prefs.setString(PrefKeys.remoteAudioUrl, settings.remoteAudioUrl),
      prefs.setBool(PrefKeys.soundEnabled, settings.soundEnabled),
      prefs.setDouble(PrefKeys.speedMultiplier, settings.speedMultiplier),
      prefs.setBool(PrefKeys.autoTapEnabled, settings.autoTapEnabled),
      prefs.setInt(PrefKeys.autoTapIntervalMs, settings.autoTapIntervalMs),
      prefs.setString(PrefKeys.meritPrefix, settings.meritPrefix),
      prefs.setString(PrefKeys.meritSubtitle, settings.meritSubtitle),
      prefs.setString(
        PrefKeys.meritPrefixList,
        jsonEncode(settings.meritPrefixPool),
      ),
      prefs.setBool(PrefKeys.telemetryEnabled, settings.telemetryEnabled),
      prefs.setBool(PrefKeys.releaseChannel, settings.releaseChannel),
    ]);
  }

  // ---- 敲击次数 ----

  Future<int> loadTapCount() async {
    final prefs = await _prefs;
    return prefs.getInt(PrefKeys.tapCount) ?? 0;
  }

  Future<void> saveTapCount(int count) async {
    final prefs = await _prefs;
    await prefs.setInt(PrefKeys.tapCount, count);
  }

  // ---- 版本信息缓存 ----

  Future<VersionInfo?> loadCachedVersionInfo() async {
    final prefs = await _prefs;
    final raw = prefs.getString(PrefKeys.cachedVersionInfo);
    if (raw == null || raw.isEmpty) return null;
    try {
      return VersionInfo.fromJsonString(raw);
    } catch (error) {
      _logger.w('缓存的版本信息已损坏，忽略：$error');
      await prefs.remove(PrefKeys.cachedVersionInfo);
      return null;
    }
  }

  Future<void> saveVersionInfo(VersionInfo info) async {
    final prefs = await _prefs;
    await prefs.setString(
      PrefKeys.cachedVersionInfo,
      jsonEncode(info.toJson()),
    );
  }

  // ---- 清空 ----

  Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.clear();
  }

  // ---- 迁移 ----

  /// 把 v2 遗留的键迁移到 v3 的规范键上。
  ///
  /// 迁移是幂等的：只有旧键存在、新键为空时才写入。
  Future<void> _migrateLegacyKeys(SharedPreferences prefs) async {
    // musicurl -> urlmusic（v2 两个键混用，urlmusic 才是读取侧）
    final legacyUrl = _nonEmpty(prefs.getString(PrefKeys.legacyRemoteAudioUrl));
    if (legacyUrl != null &&
        _nonEmpty(prefs.getString(PrefKeys.remoteAudioUrl)) == null) {
      await prefs.setString(PrefKeys.remoteAudioUrl, legacyUrl);
      _logger.i('已迁移遗留键 ${PrefKeys.legacyRemoteAudioUrl} -> '
          '${PrefKeys.remoteAudioUrl}');
    }

    // timeText（秒，double）-> autoTapIntervalMs（毫秒，int）
    if (!prefs.containsKey(PrefKeys.autoTapIntervalMs)) {
      final seconds = prefs.getDouble(PrefKeys.legacyAutoTapSeconds);
      if (seconds != null && seconds > 0) {
        final ms = _clampInt(
          (seconds * 1000).round(),
          AppConstants.minAutoTapIntervalMs,
          AppConstants.maxAutoTapIntervalMs,
        );
        await prefs.setInt(PrefKeys.autoTapIntervalMs, ms);
        _logger.i('已迁移遗留键 ${PrefKeys.legacyAutoTapSeconds} -> '
            '${PrefKeys.autoTapIntervalMs}（$ms ms）');
      }
    }

    // 内置音效：v2 存过空串，会导致播放失败
    final asset = _nonEmpty(prefs.getString(PrefKeys.builtinAudioAsset));
    if (asset == null) {
      await prefs.setString(
        PrefKeys.builtinAudioAsset,
        AssetCatalog.defaultAudioAsset,
      );
    }
  }

  // ---- 小工具 ----

  static String? _nonEmpty(String? value) =>
      (value == null || value.trim().isEmpty) ? null : value;

  static List<String> _readStringList(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return decoded
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  static double _clampDouble(double value, double min, double max) =>
      value.clamp(min, max);

  static int _clampInt(int value, int min, int max) => value.clamp(min, max);
}