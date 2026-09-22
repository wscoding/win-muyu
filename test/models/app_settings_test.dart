import 'package:flutter_test/flutter_test.dart';
import 'package:prue_widgets/models/app_settings.dart';

void main() {
  group('AppSettings.activeAudioSource', () {
    test('内置音效始终可用', () {
      const settings = AppSettings();
      expect(
        settings.activeAudioSource,
        (type: AudioSourceType.builtin, value: 'audio/muyu.mp3'),
      );
    });

    test('本地音源未填路径时返回 null', () {
      const settings = AppSettings(audioSourceType: AudioSourceType.local);
      expect(settings.activeAudioSource, isNull);
    });

    test('本地音源填了路径就可用', () {
      const settings = AppSettings(
        audioSourceType: AudioSourceType.local,
        localAudioPath: '/tmp/a.mp3',
      );
      expect(
        settings.activeAudioSource,
        (type: AudioSourceType.local, value: '/tmp/a.mp3'),
      );
    });

    test('网络音源未填 URL 时返回 null', () {
      const settings = AppSettings(audioSourceType: AudioSourceType.remote);
      expect(settings.activeAudioSource, isNull);
    });
  });

  group('AudioSourceType', () {
    test('storageValue 与 v2 的 selectedOption 取值一致', () {
      expect(AudioSourceType.builtin.storageValue, 'demusic');
      expect(AudioSourceType.local.storageValue, 'localmusic');
      expect(AudioSourceType.remote.storageValue, 'urlmusic');
    });

    test('未知 / 空字符串回落到内置音效', () {
      expect(AudioSourceType.fromStorage(null), AudioSourceType.builtin);
      expect(AudioSourceType.fromStorage(''), AudioSourceType.builtin);
      expect(AudioSourceType.fromStorage('乱填的'), AudioSourceType.builtin);
    });

    test('能解析历史值', () {
      expect(AudioSourceType.fromStorage('urlmusic'), AudioSourceType.remote);
    });
  });

  group('AppSettings.copyWith', () {
    test('只改动指定字段', () {
      const original = AppSettings(
        imageName: 'moyu',
        speedMultiplier: 1.5,
        meritPrefix: '摸鱼',
      );
      final changed = original.copyWith(imageName: 'bug');

      expect(changed.imageName, 'bug');
      expect(changed.speedMultiplier, 1.5);
      expect(changed.meritPrefix, '摸鱼');
    });

    test('显式传 false / 0 不会被当作「未传」', () {
      const original = AppSettings(soundEnabled: true, autoTapEnabled: true);
      final changed = original.copyWith(
        soundEnabled: false,
        autoTapEnabled: false,
      );
      expect(changed.soundEnabled, isFalse);
      expect(changed.autoTapEnabled, isFalse);
    });
  });

  group('AppSettings 相等性', () {
    test('内容相同即相等，可被 Riverpod 用于跳过无意义的重建', () {
      const a = AppSettings(imageName: 'muyu', meritPrefixPool: <String>['平安']);
      const b = AppSettings(imageName: 'muyu', meritPrefixPool: <String>['平安']);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('仅祝福语池不同也不相等', () {
      const a = AppSettings(meritPrefixPool: <String>['平安']);
      const b = AppSettings(meritPrefixPool: <String>['喜乐']);
      expect(a, isNot(equals(b)));
    });
  });
}