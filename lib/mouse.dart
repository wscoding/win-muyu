import 'package:flutter/material.dart';
 
//2023.6.3 自己看的 @uwhsu 
//鼠标自定义本地图片问题待解决
  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click, // 手指光标      
          onEnter: (event) {
            print("鼠标进入区域");
          },
          onExit: (event) {
            print("鼠标离开区域");
          },
          onHover: (event) {
            print("鼠标区域内移动 (${event.position.dx}, ${event.position.dy}).");
          },
        )
      ],
    );
  }
