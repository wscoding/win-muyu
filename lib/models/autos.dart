import 'dart:async';



class TimerExecutor {
  Timer? autotimer;

  void start(Function callback) {
    if (autotimer == null) {
      autotimer = Timer.periodic(const Duration(seconds: 1), (_) {
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



