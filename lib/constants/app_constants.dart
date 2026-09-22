import 'package:flutter/material.dart';

/// 尺寸、时长、默认值等全局常量。
class AppConstants {
  const AppConstants._();

  /// ScreenUtil 的设计稿尺寸（原 v2 保持 300x300）
  static const Size designSize = Size(300, 300);

  /// 窗口边长占屏幕高度的比例
  static const double windowSizeRatio = 0.15;

  /// 木鱼图案占窗口短边的比例
  static const double fishSizeRatio = 0.6;

  /// 敲击动画时长
  static const Duration tapAnimationDuration = Duration(milliseconds: 100);

  /// 敲击动画缩放区间
  static const double tapAnimationBegin = 1.0;
  static const double tapAnimationEnd = 0.9;

  /// 功德提示的显示节奏
  static const Duration toastFadeIn = Duration(milliseconds: 100);
  static const Duration toastHold = Duration(milliseconds: 300);
  static const Duration toastFadeOut = Duration(milliseconds: 500);

  /// 统计次数落盘的最小间隔，避免高频敲击时反复写 SharedPreferences
  static const Duration tapCountFlushInterval = Duration(seconds: 2);

  /// 敲击音效同时播放的通道数。
  /// 单通道在高频敲击时会互相打断，改用多通道轮询后连击不再卡顿。
  static const int audioChannelCount = 4;

  /// 默认自动敲击间隔
  static const int defaultAutoTapIntervalMs = 1000;

  /// 自动敲击间隔的可调范围
  static const int minAutoTapIntervalMs = 150;
  static const int maxAutoTapIntervalMs = 5000;

  /// 敲击播放速率的可调范围
  static const double minSpeedMultiplier = 0.5;
  static const double maxSpeedMultiplier = 2.0;

  /// 默认黑/白主题：false = 白色木鱼（深色底不适用），true = 黑色木鱼
  static const bool defaultIsLight = false;

  /// 默认功德文案
  static const String defaultMeritPrefix = '功德';
  static const String defaultMeritSubtitle = '平安';

  /// 免登录默认图片
  static const String defaultImageName = 'muyu';

  /// 每累计 N 次敲击，文案从「前缀+次数」切换为「平安+功德数」
  static const int meritStep = 100;

  /// 全局快捷键默认值（⌥⌘M）
  static const String toggleVisibilityHotkeyLabel = '⌥⌘M';
}