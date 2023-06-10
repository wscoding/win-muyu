import 'package:shared_preferences/shared_preferences.dart';

class TapCounterHelper {
 late SharedPreferences prefs;

 TapCounterHelper() {
  
    _initSharedPreferences();
  }

  // 初始化 SharedPreferences
  Future<void> _initSharedPreferences() async {
    prefs = await SharedPreferences.getInstance();
  }

  // 获取“摸鱼”数量
  Future<int> getFishCount() async {
    return prefs.getInt('fishCount') ?? 0;
  }

  // 获取“平安”数量
  Future<int> getPeaceCount() async {
    return prefs.getInt('peaceCount') ?? 0;
  }

  // 更新“摸鱼”和“平安”数量
  Future<void> updateCounts(int tapCount) async {
    int fishCount = await getFishCount();
    int peaceCount = await getPeaceCount();

    fishCount += tapCount;
    peaceCount += (tapCount ~/ 100);

    await prefs.setInt('fishCount', fishCount);
    await prefs.setInt('peaceCount', peaceCount);
  }

  // 根据当前点击次数返回相应的字符串
  Future<String> getCountString(int tapCount) async {
    int fishCount = await getFishCount();
    int peaceCount = await getPeaceCount();

    if (tapCount < 100) {
      return '$tapCount ${fishCount + tapCount}';
    } else {
      int newPeaceCount = peaceCount + (tapCount ~/ 100);
      return '${tapCount ~/ 100} ${newPeaceCount}';
      //
    }
  }
}