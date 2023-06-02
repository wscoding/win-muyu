import 'dart:io';


import 'package:flutter/material.dart';

import 'package:wooden_fish_for_windows/config.dart';
import 'package:wooden_fish_for_windows/toast.dart';
import 'package:window_manager/window_manager.dart';
import 'package:audioplayers/audioplayers.dart';

  final player = AudioPlayer();

class WoodenFish extends StatefulWidget {
  const WoodenFish({super.key});

  @override
  State<WoodenFish> createState() => _WoodenFishState();
}

class _WoodenFishState extends State<WoodenFish> with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> muyuAnimation;
  Size size = Size(Config.relHeight * 0.6, Config.relHeight * 0.6);

  bool isLight = false;


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

      
    return Container(
      width: double.infinity,
      height: double.infinity,


      // decoration: BoxDecoration(border: Border.all(color: Colors.red)),
      child: Stack(

        
        clipBehavior: Clip.none,
        children: [


             MouseRegion(
          cursor: SystemMouseCursors.click, // 手指光标      
          onEnter: (event) {
               
               
        // 加载鼠标图片

      SystemMouseCursors.click;
           // print("鼠标进入区域");
          },
          onExit: (event) {
            SystemMouseCursors.click;
           // print("鼠标离开区域");
          },
          onHover: (event) {
            //print("鼠标区域内移动 (${event.position.dx}, ${event.position.dy}).");
          SystemMouseCursors.click;
          
          },
        ),
          Align(
            alignment: const Alignment(0, 0.5),
            
            child: GestureDetector(            
                onTap: () {
// 加载音频文件 audio/muyu.mp3
  // 点击时播放背景音乐
if (player != null) { player.stop();}
                  player.play(AssetSource("audio/muyu.mp3")
                  
                  );
                  animationController.forward();
                  addOverLay(context);
                  
                },
                onSecondaryTap: () {
                  setState(() {
                    isLight = !isLight;
                  });
                },
                onLongPress: () {
                  exit(0);
                },
                onPanStart: (e) {
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

