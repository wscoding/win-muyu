import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prue_widgets/models/app_settings.dart';
import 'package:prue_widgets/services/settings_repository.dart';
import 'package:prue_widgets/state/providers.dart';
import 'package:prue_widgets/state/settings_controller.dart';
import 'package:prue_widgets/state/tap_counter_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  /// 注入真实的仓库（底层是 mock 过的 SharedPreferences），
  /// 这样「状态变更 -> 落盘」这条链路也会被真实覆盖到。
  ProviderContainer createContainer({
    AppSettings initialSettings = const AppSettings(),
    int initialTapCount = 0,
  }) {
    return ProviderContainer.test(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(SettingsRepository()),
        settingsProvider.overrideWith(
          () => SettingsController(initial: initialSettings),
        ),
        tapCounterProvider.overrideWith(
          () => TapCounterController(initial: initialTapCount),
        ),
      ],
    );
  }

  group('TapCounterController', () {
    test('使用注入的初始值', () {
      final container = createContainer(initialTapCount: 12);
      expect(container.read(tapCounterProvider), 12);
    });

    test('负数初始值被夹到 0', () {
      final container = createContainer(initialTapCount: -3);
      expect(container.read(tapCounterProvider), 0);
    });

    test('increment 累加', () {
      final container = createContainer();
      final counter = container.read(tapCounterProvider.notifier);

      counter.increment();
      counter.increment();

      expect(container.read(tapCounterProvider), 2);
    });

    test('decrement 不会低于 0', () {
      final container = createContainer();
      final counter = container.read(tapCounterProvider.notifier);

      counter.decrement();

      expect(container.read(tapCounterProvider), 0);
    });

    test('add 支持负增量且不会低于 0', () {
      final container = createContainer(initialTapCount: 5);
      final counter = container.read(tapCounterProvider.notifier);

      counter.add(3);
      expect(container.read(tapCounterProvider), 8);

      counter.add(-100);
      expect(container.read(tapCounterProvider), 0);
    });

    // v2 每读一次计数就写一次盘，这里改成只在 flush 时写
    test('increment 不会立刻写盘', () async {
      final container = createContainer();
      container.read(tapCounterProvider.notifier).increment();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('tapCount'), isNull);
    });

    test('flush 把待写入的计数落盘', () async {
      final container = createContainer();
      final counter = container.read(tapCounterProvider.notifier);

      counter.increment();
      await counter.flush();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('tapCount'), 1);
    });

    test('没有待写入内容时 flush 不写盘', () async {
      final container = createContainer(initialTapCount: 9);
      await container.read(tapCounterProvider.notifier).flush();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('tapCount'), isNull);
    });

    test('reset 清零并立即落盘', () async {
      final container = createContainer(initialTapCount: 30);
      final counter = container.read(tapCounterProvider.notifier);

      await counter.reset();

      expect(container.read(tapCounterProvider), 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('tapCount'), 0);
    });

    test('discardPendingWrites 清零且不会把旧值写回', () async {
      final container = createContainer(initialTapCount: 30);
      final counter = container.read(tapCounterProvider.notifier);

      counter.increment();
      counter.discardPendingWrites();

      expect(container.read(tapCounterProvider), 0);

      // 这是「清空本地数据」依赖的行为：清空后再 flush 不能复活旧计数
      await counter.flush();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('tapCount'), isNull);
    });
  });

  group('SettingsController', () {
    test('使用注入的初始设置', () {
      final container = createContainer(
        initialSettings: const AppSettings(imageName: 'bug'),
      );
      expect(container.read(settingsProvider).imageName, 'bug');
    });

    test('patch 修改单个字段并落盘', () async {
      final container = createContainer();

      await container.read(settingsProvider.notifier).patch(soundEnabled: false);

      expect(container.read(settingsProvider).soundEnabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('_isSoundOno'), isFalse);
    });

    test('update 可以基于当前值做组合修改', () async {
      final container = createContainer(
        initialSettings: const AppSettings(speedMultiplier: 1.0),
      );

      await container.read(settingsProvider.notifier).update(
        (current) => current.copyWith(speedMultiplier: current.speedMultiplier * 2),
      );

      expect(container.read(settingsProvider).speedMultiplier, 2.0);
    });

    test('值没有变化时不写盘', () async {
      final container = createContainer(
        initialSettings: const AppSettings(soundEnabled: true),
      );

      await container.read(settingsProvider.notifier).patch(soundEnabled: true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('_isSoundOno'), isNull);
    });

    test('toggleIsLight 翻转并落盘', () async {
      final container = createContainer(
        initialSettings: const AppSettings(isLight: false),
      );

      await container.read(settingsProvider.notifier).toggleIsLight();

      expect(container.read(settingsProvider).isLight, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isLight'), isTrue);
    });
  });
}