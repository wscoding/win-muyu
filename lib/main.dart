
import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:wooden_fish_for_windows/config.dart';
import 'package:wooden_fish_for_windows/muyu.dart';
import 'RePo.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.initWindow(args);
   TapCounter.initialize(); // 初始化 SharedPreferences 实例

  runApp(const MyApp());

try {
  //http.Response response = await 
  Getadd.sendRequest();
  //print(response.body);
} catch (e) {
 // print('请求失败：$e');
}
}


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(300, 300),
      builder: (context, Widget? child) => const MaterialApp(
        title: 'AutoWoodenFish for Windows',
        debugShowCheckedModeBanner: false,
        home: MyHomePage(),
        
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: Colors.transparent, body: WoodenFish());
  }
}
