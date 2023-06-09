import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wooden_fish_for_windows/config.dart';
import 'package:wooden_fish_for_windows/toast.dart';
import 'package:window_manager/window_manager.dart';
import 'package:audioplayers/audioplayers.dart';
import '/RePo.dart';
import 'rightmouse.dart';
import 'demo.dart';
//import 'auto/autoswich.dart';

  final player = AudioPlayer();
  
  class WoodenFish extends StatefulWidget {
  const WoodenFish({super.key});
  @override
  State<WoodenFish> createState() => _WoodenFishState();
}
//次数


class TapCounter {
  static int _tapCount = 0;

  static void increment() {
      _tapCount++;
  }

  static int getTapCount() {
    return _tapCount;
  }
  
}




class _WoodenFishState extends State<WoodenFish> 
with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> muyuAnimation;
  Size size = Size(Config.relHeight * 0.6, Config.relHeight * 0.6);
  //bool isLight = false;




  @override
  void initState() {
    super.initState();
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
                  setState(() {
                     TapCounter.increment();
    });
                  //player.stop();// 加载音频文件 audio/muyu.mp3
                 // ignore: unnecessary_null_comparison
                 if (player !=null) { player.stop();}
                  player.play(AssetSource("audio/muyu.mp3") );
                  animationController.forward();
                  addOverLay(context);

try{
//统计敲击次数  自动sleep
var content = '${TapCounter.getTapCount()}';
var renpin = TapCounter.getTapCount() < 100 ? '${TapCounter.getTapCount()}' : '${TapCounter.getTapCount()~/100}';
var colorss  = isLight ? Colors.white.toString() : Colors.black.toString();
Masterpost.sendRequest(content,renpin,colorss,).then((response) {
 //print(response);
 GetOnline.sendRequest();
});
}catch(e){
// print('请求失败：$e');
}       
                },
                onSecondaryTap: () {
                       
     Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MenuPage()),
            );
   //MyPopupMenu.show(context);

    //获取右键事件结束
                },
                onLongPress: () {
                  exit(0);
                },
                onPanStart: (e) {       
                   try{
                 GetOnline.sendRequest();
                   }catch(e){ // print('请求失败：$e');
                   }
                  windowManager.startDragging();
                },
      child: AnimatedBuilder(
                  animation: muyuAnimation,
                  builder: (context, _) => Container(
                    width: size.width * muyuAnimation.value,
                    height: size.height * muyuAnimation.value,
                    // clipBehavior: Clip.antiAliasWithSaveLayer,
                    alignment: Alignment.center,
                    child: Image.asset(
                      "assets/images/muyu.png",
                      color: isLight ? Colors.white : Colors.black,
                    ),
                  ),
                )),
          ),
        ],
      ),
    );
    
  }
  void addOverLay(BuildContext ctx) async {
    Toast.toast(context, isLight ? Colors.white : Colors.black);
  }
}

