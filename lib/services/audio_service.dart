import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';

import '../constants/app_constants.dart';
import '../models/app_settings.dart';

/// 已加载的音源，用于避免每次敲击都重新设置 source。
class _LoadedSource {
  const _LoadedSource(this.type, this.value);

  final AudioSourceType type;
  final String value;

  @override
  bool operator ==(Object other) =>
      other is _LoadedSource && other.type == type && other.value == value;

  @override
  int get hashCode => Object.hash(type, value);
}

/// 敲击音效播放。
///
/// 与 v2 的区别：
/// - v2 只有一个全局 [AudioPlayer]，每次敲击都 `stop()` 再 `play()`，
///   高频连击时后一次会打断前一次，听起来就是「卡顿 / 丢音」。
///   这里改为 [AppConstants.audioChannelCount] 个播放器轮询，允许声音叠加。
/// - 音源只在变化时 `setSource` 一次，避免每次敲击都走一遍加载流程。
/// - 使用 [PlayerMode.lowLatency] 降低触发延迟。
/// - 播放失败只记日志，绝不向上抛异常——声音出问题不应该让敲击失效。
class AudioService {
  AudioService({
    int channelCount = AppConstants.audioChannelCount,
    Logger? logger,
  }) : _channelCount = channelCount,
       _logger = logger ?? Logger();

  final int _channelCount;
  final Logger _logger;

  final List<AudioPlayer> _pool = <AudioPlayer>[];
  int _roundRobin = 0;
  _LoadedSource? _loaded;
  bool _initialized = false;
  bool _disposed = false;

  bool get isInitialized => _initialized && !_disposed;

  Future<void> ensureInitialized() async {
    if (_initialized || _disposed) return;
    for (var i = 0; i < _channelCount; i++) {
      final player = AudioPlayer();
      try {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setPlayerMode(PlayerMode.lowLatency);
      } catch (error) {
        _logger.w('音频通道 $i 初始化失败：$error');
      }
      _pool.add(player);
    }
    _initialized = true;
  }

  /// 预加载音源。设置变化后应调用一次，避免首次敲击有明显延迟。
  Future<void> prepare(AppSettings settings) async {
    if (_disposed) return;
    await ensureInitialized();

    final source = settings.activeAudioSource;
    if (source == null) {
      _loaded = null;
      return;
    }

    final target = _LoadedSource(source.type, source.value);
    if (_loaded == target) return;

    final failed = <int>[];
    for (var i = 0; i < _pool.length; i++) {
      try {
        await _pool[i].setSource(_sourceFor(source.type, source.value));
      } catch (error) {
        failed.add(i);
        _logger.w('音频通道 $i 加载 ${source.value} 失败：$error');
      }
    }
    // 只要还有一个通道可用就算加载成功
    _loaded = failed.length == _pool.length ? null : target;
  }

  /// 敲击时播放一次。默认按 [settings.soundEnabled] 决定是否真的出声。
  Future<void> playTap(AppSettings settings) async {
    if (_disposed || !settings.soundEnabled) return;
    await prepare(settings);

    final loaded = _loaded;
    if (loaded == null) return;

    final player = _pool[_roundRobin % _pool.length];
    _roundRobin = (_roundRobin + 1) % _pool.length;

    try {
      await player.setPlaybackRate(settings.speedMultiplier);
      await player.stop();
      await player.resume();
    } catch (error) {
      _logger.w('播放敲击音效失败：$error');
    }
  }

  /// 在音效选择页试听，无视 [AppSettings.soundEnabled]
  Future<void> preview(AudioSourceType type, String value) async {
    if (_disposed || value.isEmpty) return;
    await ensureInitialized();

    final player = _pool[_roundRobin % _pool.length];
    _roundRobin = (_roundRobin + 1) % _pool.length;

    try {
      await player.stop();
      await player.play(_sourceFor(type, value));
    } catch (error) {
      _logger.w('试听 $value 失败：$error');
    }
  }

  Future<void> stopAll() async {
    for (final player in _pool) {
      try {
        await player.stop();
      } catch (_) {
        // 停止失败无需处理
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _loaded = null;
    for (final player in _pool) {
      try {
        await player.dispose();
      } catch (_) {
        // 释放失败无需处理
      }
    }
    _pool.clear();
    _initialized = false;
  }

  static Source _sourceFor(AudioSourceType type, String value) {
    return switch (type) {
      AudioSourceType.builtin => AssetSource(value),
      AudioSourceType.local => DeviceFileSource(value),
      AudioSourceType.remote => UrlSource(value),
    };
  }
}