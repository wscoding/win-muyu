
import 'dart:async';
import 'dart:convert';


import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prue_widgets/config.dart';
import 'package:prue_widgets/toast.dart';
import 'package:window_manager/window_manager.dart';
import 'package:audioplayers/audioplayers.dart';
import '/RePo.dart';
import 'models/autos.dart';

import 'view.dart';
//import 'auto/autoswich.dart';

  final player = AudioPlayer();
late SharedPreferences _prefs;
  String? selectedImageName;
 String? _musicPath;
 String? _musicurl;
 String   _urlmusic = "http://wen.iqg.cc/ss.mp3";

 double _speedMultiplier = 1.0;
 //String ?  _selectedOption ;
 String _autofile = "";
  class WoodenFish extends StatefulWidget {
  const WoodenFish({super.key});
  @override
  State<WoodenFish> createState() => _WoodenFishState();
}
//次数
//text more
Future<void> printListFromPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = prefs.getString('list');
  if (jsonString != null) {
    final list = json.decode(jsonString) as List<dynamic>;
    final stringList = list.cast<String>();
    print(stringList);
  } else {
    print('List not found in SharedPreferences.');
  }
}
//final randomString =  getRandomStringFromPrefs();
//print test



class TapCounter {
 // String uiyi = "--";
  static int _tapCount = 0;
  static late SharedPreferences _prefs;
  Timer? autotimer;

  
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    _tapCount = _prefs.getInt('tapCount') ?? 0;
  }

  static void increment() {
    _tapCount++;
    _prefs.setInt('tapCount', _tapCount);
  }

  static int getTapCount() {
    _prefs.setInt('tapCount', _tapCount);
    //未知
    return _tapCount;
  }
}


class _WoodenFishState extends State<WoodenFish> 
with SingleTickerProviderStateMixin {

    TimerExecutor _executor = TimerExecutor();

//加载动画
  late AnimationController animationController;
  late Animation<double> muyuAnimation;
  Size size = Size(Config.relHeight * 0.6, Config.relHeight * 0.6);
bool isLight = true;
  @override
  void initState() {
    super.initState();
_loadSelectedImageName();
     getSelectedImageName().then((value) {
      setState(() {
        selectedImageName = value;
        
      });
    });
    
    animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    muyuAnimation = CurvedAnimation(parent: animationController, curve: Curves.elasticInOut, reverseCurve: Curves.easeOut);
    muyuAnimation.addListener(() {
      setState(() {});
    });

    muyuAnimation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        animationController.reverse();
      }
    });
    muyuAnimation = Tween(begin: 1.0, end: 0.9).animate(animationController);
   TapCounter.initialize(); // 初始化 SharedPreferences 实例
  }


  _loadSelectedImageName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

        double speedMultiplier = prefs.getDouble('speedMultiplier') ?? 1.0;
 //  String selectedOption = prefs.getString('selectedOption') ?? "demusic";
        bool isHelpme = prefs.getBool('isHelpme') ?? false;
bool isLight = prefs.getBool('isLight') ?? false;
    String? imageName = prefs.getString('selectedImageName');
   
 setState(() {
String selectedOption = prefs.getString('selectedOption') ?? "demusic";
         _speedMultiplier = speedMultiplier;
      _musicPath = prefs.getString('musicPath') ?? '';
   String _autofile = prefs.getString('autofile') ?? 'audio/muyu.mp3';
        //musicurl   网络链接
    String   _urlmusic = prefs.getString('urlmusic') ?? '';
    });

    if (imageName != null) {
      setState(() {
        selectedImageName = imageName;
       
      });
    }
  }



Future<void> qiaoji(BuildContext context, AudioPlayer 
player, AnimationController animationController, bool isLight) async {
   SharedPreferences prefs = await SharedPreferences.getInstance();

  setState(() {
   String selectedOption = prefs.getString('selectedOption') ?? "demusic";
String      _musicurl = prefs.getString('musicurl') ?? 'http://wen.iqg.cc/ss.mp3';
      _musicPath = prefs.getString('musicPath') ?? '';
   String _autofile = prefs.getString('selectmusic') ?? 'audio/muyu.mp3';
        //musicurl   网络链接
    String   _urlmusic = prefs.getString('urlmusic') ?? '';
// prefs.clear();

    TapCounter.increment();
   //print(_selectedOption);
      // print(_musicurl);
      // print(_musicPath);
    
    if (player !=null) { player.stop(); }
    player.setPlaybackRate(_speedMultiplier); 
  //  player.play(AssetSource("audio/muyu.mp3"));
//player.play(AssetSource(_autofile));

    String ss = selectedOption;

if (ss == "demusic") {
player.play(AssetSource(_autofile));
print(_autofile);
  print(selectedOption);
} else if (ss == "urlmusic") {

player.play(UrlSource(_musicurl!));

 print(_musicurl);
  print(selectedOption);
} else if (ss == "localmusic") {

player.play(DeviceFileSource(_musicPath!));
print(_musicPath);
  print(selectedOption);
} else if (ss == null) {
   print("未知的值");
  print(selectedOption);
} else {
  // 如果 ss 不是 a、b、c、d 中的任意一个值，则执行这里的代码
  print("失败");
  print(selectedOption);
}

    animationController.forward();
    addOverLay(context);
    try {
      var content = '${TapCounter.getTapCount()}';
      var renpin = TapCounter.getTapCount() < 100 ? '${TapCounter.getTapCount()}' : '${TapCounter.getTapCount()~/100}';
      var colorss = isLight ? Colors.white.toString() : Colors.black.toString();
      Masterpost.sendRequest(content,renpin,colorss).then((response) {
        GetOnline.sendRequest();
      });
    } catch(e) {
      // 处理异常
    }
  });
}

  @override
  void dispose() {
    _executor.stop();
    super.dispose();
  }

void _onTap() {
  setState(() {
    qiaoji(context, player, animationController, isLight);
  });

  // 设置播放速度
  //double desiredSpeed = 0.5; // 设置为半速
  // double desiredSpeed = 4.0; // 设置为4倍速

  // 更新播放速度
  //player.setPlaybackRate(playbackRate: desiredSpeed);


  if (!_executor.isRunning()) {
    _executor.start(() {
      setState(() {
        qiaoji(context, player, animationController, isLight);
      });
    });
  }
}

// void _onTap() {
//   setState(() {
//     qiaoji(context, player, animationController, isLight);
//   });
//   // 设置动画速度
//   double desiredSpeed = 8; // 设置为半速
//   // double desiredSpeed = 4.0; // 设置为4倍速
//   if (animationController.duration != null) {
//     // 计算新的持续时间
//     Duration newDuration = Duration(milliseconds: 
//(animationController.duration?.inMilliseconds ?? 0 / desiredSpeed).round());
//     // 更新动画持续时间
//     animationController.duration = newDuration;
//   }
//   if (!_executor.isRunning()) {
//     _executor.start(() {
//       setState(() {
//         qiaoji(context, player, animationController, isLight);
//       });
//     });
//   }
// }




///1.  setState   直接从sp库获取数据 
//    _musicurl = prefs.getString('musicurl') ?? '';
///2.  异步从sp里面获取数据
// bool isLight = prefs.getBool('isLight') ?? false;

   _navigateToSelectImageScreen() async* {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WoodenFish()),
    ).then((value) {
      if (value != null) {
      
        setState(() {
            isLight = !isLight;  
    //  print(isLight);
        });
      }
    });
  }

  
  @override
  Widget build(BuildContext context) {
 return SizedBox(
      width: double.infinity,
      height: double.infinity,

      // decoration: BoxDecoration(border: Border.all(color: Colors.red)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [

          Align(
            alignment: const Alignment(0, 0.5),
                        child: GestureDetector(    
                onTap: () {
            // _onTap();
            final prefs = SharedPreferences.getInstance();
            prefs.then((prefs) {
              bool isHelpme = prefs.getBool('isHelpme') ?? true;
              if (isHelpme) {
                _onTap();
              } else {
                setState(() {
                //  _count++;
                _executor.stop();
                 qiaoji(context, player, animationController, isLight);

                
                });
              }
            });
                },
                onSecondaryTap: () {
                         try{
                    
                 GetOnline.sendRequest();
                 print("成功");
                   }catch(e){ 
                  print('请求失败：$e');
                   }
     Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MenuPage()),
            );
   //MyPopupMenu.show(context);
  //isLight = !isLight;  
    //获取右键事件结束
                },

//                        isLight = !isLight;  
//  
                onLongPress: ()  async{
 SharedPreferences prefs = await SharedPreferences.getInstance();
   // bool isLight = prefs.getBool('isLight') ?? true;
   
    await prefs.setBool('isLight', !isLight);
    setState(() {
      isLight = !isLight;
     
    });

  
                },
                onPanStart: (e) {       
                 
                  windowManager.startDragging();
                },
                //窗口拖动
      child: AnimatedBuilder(
                  animation: muyuAnimation,
                  builder: (context, _) => Container(
                    width: size.width * muyuAnimation.value,
                    height: size.height * muyuAnimation.value,
                    // clipBehavior: Clip.antiAliasWithSaveLayer,
                    alignment: Alignment.center,
                    child:  
selectedImageName != null
            ? Image.asset(
                'assets/images/$selectedImageName.png',
                color: isLight ? Colors.black : Colors.white,
              )
            : const CircularProgressIndicator(),
                  ),
                )),
          ),
        ],
      ),
    );
    
  }
  void addOverLay(BuildContext ctx) async {
    Toast.toast(context, isLight ? Colors.black : Colors.white);

  }
}

 Future<String?> getSelectedImageName() async {
  
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? imageName = prefs.getString('selectedImageName');
//bool isColorBh = prefs.getBool('_isColorBh') ?? true;

    imageName ??= 'muyu';
    return imageName;
  }
