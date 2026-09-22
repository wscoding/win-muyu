import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prue_widgets/constants/asset_catalog.dart';

void main() {
  group('AssetCatalog.audioAssetPath', () {
    test('三种历史写法都归一到 audio/<name>.mp3', () {
      for (final input in <String>[
        'muyu',
        'audio/muyu.mp3',
        'assets/audio/muyu.mp3',
      ]) {
        expect(
          AssetCatalog.audioAssetPath(input),
          'audio/muyu.mp3',
          reason: '输入 $input 未正确归一',
        );
      }
    });

    test('不带 assets/ 前缀', () {
      // audioplayers 的 AudioCache 默认 prefix 就是 'assets/'，
      // 若这里再带上就会拼成 assets/assets/audio/... 而加载失败
      expect(AssetCatalog.audioAssetPath('muyu').startsWith('assets/'), isFalse);
    });

    test('soundNameFromAsset 能从各种写法反解文件名', () {
      expect(AssetCatalog.soundNameFromAsset('audio/qingcui.mp3'), 'qingcui');
      expect(AssetCatalog.soundNameFromAsset('assets/audio/dong.mp3'), 'dong');
      expect(AssetCatalog.soundNameFromAsset('dong'), 'dong');
    });

    test('audioFilePath 指向工程内的真实文件', () {
      expect(AssetCatalog.audioFilePath('muyu'), 'assets/audio/muyu.mp3');
    });

    test('defaultAudioAsset 可直接交给 AssetSource', () {
      expect(AssetCatalog.defaultAudioAsset, 'audio/muyu.mp3');
    });
  });

  group('AssetCatalog.imagePath', () {
    test('返回 Image.asset 需要的完整 asset key', () {
      expect(AssetCatalog.imagePath('muyu'), 'assets/images/muyu.png');
    });
  });

  // 清单里的资源一旦缺失，运行时会直接抛异常（v2 就是这样白屏的），
  // 所以用测试在构建期兜住。
  group('资源完整性', () {
    test('imageNames 无重复', () {
      expect(
        AssetCatalog.imageNames.toSet().length,
        AssetCatalog.imageNames.length,
        reason: '图片清单存在重复项',
      );
    });

    test('imageNames 里的每张图片都真实存在', () {
      for (final name in AssetCatalog.imageNames) {
        final path = AssetCatalog.imagePath(name);
        expect(File(path).existsSync(), isTrue, reason: '缺少图片资源：$path');
      }
    });

    test('builtinSounds 里的每个音频都真实存在', () {
      for (final name in AssetCatalog.builtinSounds.keys) {
        final path = AssetCatalog.audioFilePath(name);
        expect(File(path).existsSync(), isTrue, reason: '缺少音频资源：$path');
      }
    });

    test('默认图片与默认音效都在清单内', () {
      expect(AssetCatalog.imageNames, contains('muyu'));
      expect(
        AssetCatalog.builtinSounds.containsKey(AssetCatalog.defaultSound),
        isTrue,
      );
    });

    test('托盘图标存在（Windows 必须用 .ico，macOS 用 png）', () {
      expect(File('assets/tray/tray_icon.ico').existsSync(), isTrue);
      expect(File('assets/tray/tray_icon.png').existsSync(), isTrue);
    });
  });
}