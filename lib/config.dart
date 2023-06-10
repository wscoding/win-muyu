import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

class Config {
  static double relHeight = 300;
  
  static Future initWindow(List<String> args, {Size? screenSize}) async {
    
    // 获取屏幕真实大小
    Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
    relHeight = primaryDisplay.size.height * 0.15;
    double relWidth = relHeight;
    final displaySize = Size(relWidth, relHeight);
    await setSingleInstance(args);
    WindowManager w = WindowManager.instance;
    await w.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
        size: displaySize,
        minimumSize: displaySize,
        alwaysOnTop: true, // 设置置顶
        titleBarStyle: TitleBarStyle.hidden, // 去除窗口标题栏
        skipTaskbar: true // 去除状态栏图标
        );
    w.waitUntilReadyToShow(windowOptions, () async {
      double w1 = primaryDisplay.size.width - 100;
      await w.setBackgroundColor(Colors.transparent);
      await w.setPosition(Offset(w1 - relWidth, primaryDisplay.size.height - relHeight - 100)); // 位置居中
      await w.show();
      await w.focus();
      await w.setAsFrameless();
    });
  }

  /// windows设置单实例启动
  static setSingleInstance(List<String> args) async {
    await WindowsSingleInstance.ensureSingleInstance(args, "desktop_open", onSecondWindow: (args) async {
      // 唤起并聚焦
      if (await windowManager.isMinimized()) await windowManager.restore();
      windowManager.focus();
    });
  }
}

class mytextClass {
  String autoText = ''; // 将_autoText变量定义为公共变量

  static final mytextClass _singleton = mytextClass._internal();

  factory mytextClass() {
    return _singleton;
  }

  mytextClass._internal();

  Future<void> fetchAutoText() async {
    final prefs = await SharedPreferences.getInstance();
    autoText = prefs.getString('autoText') ?? ''; // 访问公共的autoText变量
  }

  Future<String?> getRandomStringFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('list');
    if (jsonString != null) {
      final list = json.decode(jsonString) as List<dynamic>;
      final stringList = list.cast<String>();
      if (stringList.isNotEmpty) {
        final random = Random();
        final index = random.nextInt(stringList.length);
        return stringList[index];
      }
    }
    return null;
  }

  String getTextValue(String snapshotData) {
    return '$autoText $snapshotData'; // 访问公共的autoText变量
  }
}



class MyTimer {
  late Timer? _timer;
  final Function() _onTick;

  MyTimer(this._onTick);

  void start() {
    // Create a timer to execute the specified function every 1 second
    _timer = Timer.periodic(Duration(seconds: 1), (_) => _onTick());
  }

  void stop() {
    // Stop the timer if it is running
    if (_timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }
}