import 'dart:async';
import 'package:flutter/material.dart';


TimerExecutor _executor = TimerExecutor();
class TimerExecutor {
  Timer? autotimer;

  void start(Function callback) {
    if (autotimer == null) {
      autotimer = Timer.periodic(Duration(seconds: 1), (_) {
        callback();
      });
    }
  }

  void stop() {
    autotimer?.cancel();
    autotimer = null;
  }

  bool isRunning() {
    return autotimer != null;
  }
}



