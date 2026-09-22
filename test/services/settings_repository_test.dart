import 'package:flutter_test/flutter_test.dart';
import 'package:prue_widgets/models/app_settings.dart';
import 'package:prue_widgets/models/version_info.dart';
import 'package:prue_widgets/services/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = SettingsRepository();
  });

  group('默认值', () {
    test('首次启动使用合理的默认设置', () async {
      final settings = await repository.load();

      expect(settings.imageName, 'muyu');
      expect(settings.isLight, isFalse);
      expect(settings.audioSourceType, AudioSourceType.builtin);
      expect(settings.builtinAudioAsset, 'audio/muyu.mp3');
      expect(settings.soundEnabled, isTrue);
      expect(settings.speedMultiplier, 1.0);
      expect(settings.autoTapEnabled, isFalse);
      expect(settings.autoTapIntervalMs, 1000);
      expect(settings.meritPrefix, '功德');
      expect(settings.meritSubtitle, '平安');
      expect(settings.meritPrefixPool, isEmpty);
      // 后端已下线，默认不上报
      expect(settings.telemetryEnabled, isFalse);
    });
  });

  group('读写往返', () {
    test('save 之后 load 得到同样的内容', () async {
      const saved = AppSettings(
        isLight: true,
        imageName: 'bug',
        audioSourceType: AudioSourceType.remote,
        builtinAudioAsset: 'audio/qingcui.mp3',
        localAudioPath: '/tmp/a.mp3',
        remoteAudioUrl: 'https://example.com/a.mp3',
        soundEnabled: false,
        speedMultiplier: 1.5,
        autoTapEnabled: true,
        autoTapIntervalMs: 400,
        meritPrefix: '摸鱼',
        meritSubtitle: '喜乐',
        meritPrefixPool: <String>['平安', '顺遂'],
        telemetryEnabled: true,
        releaseChannel: true,
      );

      await repository.save(saved);
      final loaded = await repository.load();

      expect(loaded, equals(saved));
    });

    test('tapCount 读写', () async {
      expect(await repository.loadTapCount(), 0);
      await repository.saveTapCount(42);
      expect(await repository.loadTapCount(), 42);
    });
  });

  // v2 的键名与写入位置有错位，用户升级后设置不能丢
  group('v2 -> v3 键迁移', () {
    test('musicurl 迁移到 urlmusic', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'musicurl': 'https://example.com/legacy.mp3',
      });

      final settings = await repository.load();

      expect(settings.remoteAudioUrl, 'https://example.com/legacy.mp3');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('urlmusic'), 'https://example.com/legacy.mp3');
    });

    test('已有 urlmusic 时不会被 legacy 覆盖', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'musicurl': 'https://legacy',
        'urlmusic': 'https://current',
      });

      expect((await repository.load()).remoteAudioUrl, 'https://current');
    });

    test('timeText（秒）迁移成 autoTapIntervalMs（毫秒）', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'timeText': 1.5});

      expect((await repository.load()).autoTapIntervalMs, 1500);
    });

    test('迁移结果被夹紧到合法区间', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'timeText': 99.0});

      // 99 秒远超上限，应落到 maxAutoTapIntervalMs
      expect((await repository.load()).autoTapIntervalMs, 5000);
    });

    test('selectmusic 为空串时回落到默认音效', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'selectmusic': ''});

      expect((await repository.load()).builtinAudioAsset, 'audio/muyu.mp3');
    });

    test('v2 存的 audio/xxx.mp3 写法可以直接使用', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'selectmusic': 'audio/qingcui.mp3',
      });

      expect((await repository.load()).builtinAudioAsset, 'audio/qingcui.mp3');
    });
  });

  group('脏数据容错', () {
    test('祝福语池不是合法 JSON 时不抛异常', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'list': 'not-json'});

      expect((await repository.load()).meritPrefixPool, isEmpty);
    });

    test('祝福语池是 JSON 但不是数组时不抛异常', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'list': '{"a":1}'});

      expect((await repository.load()).meritPrefixPool, isEmpty);
    });

    test('越快越界的播放速度会被夹紧', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'speedMultiplier': 99.0,
      });

      expect((await repository.load()).speedMultiplier, 2.0);
    });

    test('版本信息缓存损坏时返回 null 并清理', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'data': '{{{'});

      expect(await repository.loadCachedVersionInfo(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('data'), isNull);
    });

    test('版本信息往返', () async {
      const info = VersionInfo(
        appName: 'Prue Widgets',
        version: '3.0.0',
        downloadUrl: 'https://example.com/download',
      );
      await repository.saveVersionInfo(info);

      final loaded = await repository.loadCachedVersionInfo();
      expect(loaded, isNotNull);
      expect(loaded!.appName, 'Prue Widgets');
      expect(loaded.version, '3.0.0');
      expect(loaded.downloadUrl, 'https://example.com/download');
      expect(loaded.downloadHost, 'example.com');
    });
  });

  test('clearAll 清空全部本地数据', () async {
    await repository.saveTapCount(7);
    await repository.clearAll();

    expect(await repository.loadTapCount(), 0);
  });
}