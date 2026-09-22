import 'dart:math';

import '../constants/app_constants.dart';
import 'app_settings.dart';

/// 计算一次敲击要展示的功德文案。
///
/// 规则沿用 v2：
/// - 不足 [AppConstants.meritStep] 次时展示「前缀 + 当前次数」，如 `功德+57`；
/// - 达到阈值后展示「随机祝福语 + 累计功德数」，如 `平安+3`。
///
/// 抽成纯函数是为了能脱离 UI 做单元测试——v2 这段逻辑散布在
/// `toast.dart` 与 `muyu.dart` 两处，且随机源不可控。
class MeritText {
  const MeritText._();

  static String forTapCount({
    required int tapCount,
    required AppSettings settings,
    Random? random,
  }) {
    final count = tapCount < 0 ? 0 : tapCount;
    final step = AppConstants.meritStep;

    if (count < step) {
      return '${settings.meritPrefix}+$count';
    }

    final pool = settings.meritPrefixPool
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);

    final subtitle = pool.isEmpty
        ? settings.meritSubtitle
        : pool[(random ?? Random()).nextInt(pool.length)];

    return '$subtitle+${count ~/ step}';
  }

  /// 「统计」页展示的等级描述
  static String levelForTapCount(int tapCount) {
    if (tapCount < 0) return '不行';
    if (tapCount == 0) return '无';
    if (tapCount <= 100) return '可以';
    if (tapCount <= 1000) return '厉害';
    if (tapCount <= 10000) return '大于1000';
    return '无敌';
  }
}