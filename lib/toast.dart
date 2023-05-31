import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:wooden_fish_for_windows/config.dart';

class Toast {
  static void toast(BuildContext context, Color textColor) async {
    OverlayEntry _overlayEntry; //toast靠它加到屏幕上
    int _showing = 0; //toast是否正在showing
    DateTime _startedTime; //开启一个新toast的当前时间，用于对比是否已经展示了足够时间
    _startedTime = DateTime.now();
    //获取OverlayState
    OverlayState? overlayState = Overlay.of(context);
    _overlayEntry = OverlayEntry(
        builder: (BuildContext context) => AnimatedPositioned(
              duration: const Duration(milliseconds: 100),
              top: _showing == 0
                  ? 40.h
                  : _showing == 1
                      ? 20.h
                      : 0.h,
              left: Config.relHeight - 120.w,
              child: AnimatedOpacity(
                opacity: _showing == 0
                    ? 0.0
                    : _showing == 1
                        ? 1.0
                        : 0.0, //目标透明度
                duration: const Duration(milliseconds: 100),
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    "功德+1",
                    style: TextStyle(color: textColor, fontSize: 32.sp),
                  ),
                ),
              ),
            ));
    overlayState?.insert(_overlayEntry);
    await Future.delayed(const Duration(milliseconds: 200));
    _showing = 1;
    _overlayEntry.markNeedsBuild();
    await Future.delayed(const Duration(milliseconds: 300));

    if (DateTime.now().difference(_startedTime).inMilliseconds >= 500) {
      _showing = 2;
      _overlayEntry.markNeedsBuild();
      Future.delayed(const Duration(milliseconds: 500)).then((_) {
        _overlayEntry.remove();
      });
    }
  }
}
