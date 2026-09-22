import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prue_widgets/constants/app_constants.dart';
import 'package:prue_widgets/models/app_settings.dart';
import 'package:prue_widgets/models/merit_text.dart';

void main() {
  group('MeritText.forTapCount', () {
    const settings = AppSettings(meritPrefix: '功德', meritSubtitle: '平安');

    test('不足 100 次时展示「前缀+次数」', () {
      expect(MeritText.forTapCount(tapCount: 0, settings: settings), '功德+0');
      expect(MeritText.forTapCount(tapCount: 1, settings: settings), '功德+1');
      expect(MeritText.forTapCount(tapCount: 57, settings: settings), '功德+57');
      expect(MeritText.forTapCount(tapCount: 99, settings: settings), '功德+99');
    });

    test('达到阈值后展示「祝福语+功德数」', () {
      const step = AppConstants.meritStep;
      expect(
        MeritText.forTapCount(tapCount: step, settings: settings),
        '平安+1',
      );
      expect(
        MeritText.forTapCount(tapCount: step * 3 + 25, settings: settings),
        '平安+3',
      );
    });

    test('有祝福语池时从中随机取一条', () {
      const withPool = AppSettings(meritPrefixPool: <String>['平安', '喜乐', '顺遂']);
      const allowed = <String>{'平安', '喜乐', '顺遂'};
      final picked = <String>{};

      for (var seed = 0; seed < 200; seed++) {
        final text = MeritText.forTapCount(
          tapCount: 300,
          settings: withPool,
          random: Random(seed),
        );
        final subtitle = text.split('+').first;
        expect(allowed, contains(subtitle));
        expect(text.endsWith('+3'), isTrue);
        picked.add(subtitle);
      }

      expect(picked.length, greaterThan(1), reason: '随机源没有产生变化');
    });

    test('祝福语池里的空白项会被忽略', () {
      const withBlank = AppSettings(
        meritSubtitle: '平安',
        meritPrefixPool: <String>['  ', ''],
      );
      expect(
        MeritText.forTapCount(tapCount: 200, settings: withBlank),
        '平安+2',
      );
    });

    test('负数按 0 处理', () {
      expect(MeritText.forTapCount(tapCount: -5, settings: settings), '功德+0');
    });
  });

  group('MeritText.levelForTapCount', () {
    test('按区间返回等级描述', () {
      expect(MeritText.levelForTapCount(-1), '不行');
      expect(MeritText.levelForTapCount(0), '无');
      expect(MeritText.levelForTapCount(1), '可以');
      expect(MeritText.levelForTapCount(100), '可以');
      expect(MeritText.levelForTapCount(101), '厉害');
      expect(MeritText.levelForTapCount(1000), '厉害');
      expect(MeritText.levelForTapCount(1001), '大于1000');
      expect(MeritText.levelForTapCount(10000), '大于1000');
      expect(MeritText.levelForTapCount(10001), '无敌');
    });
  });
}