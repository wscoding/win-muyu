

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:wooden_fish_for_windows/config.dart';
import 'package:wooden_fish_for_windows/muyu.dart';
import 'models/textplus.dart';


  final TapCounterHelper counterHelper = TapCounterHelper();

class Toast  {
  static void toast(BuildContext context, Color textColor) async {
  final mytextClass mtextclass = mytextClass();

    OverlayEntry overlayEntry; //toast靠它加到屏幕上
    int showing = 0; //toast是否正在showing
    DateTime startedTime; //开启一个新toast的当前时间，用于对比是否已经展示了足够时间
    startedTime = DateTime.now();

    //获取OverlayState
    OverlayState? overlayState = Overlay.of(context);
    overlayEntry = OverlayEntry(
        builder: (BuildContext context) => AnimatedPositioned(
              duration: const Duration(milliseconds: 100),
              top: showing == 0
                  ? 40.h
                  : showing == 1
                      ? 20.h
                      : 0.h,
              left: Config.relHeight - 150.w,
              child: AnimatedOpacity(
                opacity: showing == 0
                    ? 0.0
                    : showing == 1
                        ? 1.0
                        : 0.0, //目标透明度
                duration: const Duration(milliseconds: 100),
                child: Material(
                  color: Colors.transparent,
                  child:
 FutureBuilder<String?>(
          future: mtextclass.getRandomStringFromPrefs(),        
             
          builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
            
            if (snapshot.hasData && snapshot.data != null) {
      final textValue = mtextclass.getTextValue(snapshot.data!);
 mtextclass.fetchAutoText(); // 获取自动文本
final autoText = mtextclass.autoText; // 获取公共的autoText变量
              return Text(
                TapCounter.getTapCount() < 100
                    ? '$autoText+${TapCounter.getTapCount()}'
                    : '${snapshot.data!}+${TapCounter.getTapCount()~/100}',
                style: TextStyle(color: textColor, fontSize: 32.sp),
              );
            } else {
              return Text(
                TapCounter.getTapCount() < 100
                    ? 'error+${TapCounter.getTapCount()}'
                    : 'Bug+${TapCounter.getTapCount()~/100}',
                style: TextStyle(color: textColor, fontSize: 32.sp),
              );
            }
          },
        ),
      
//                   Text(
// TapCounter.getTapCount() < 100 ? '文字+${TapCounter.getTapCount()}' : '平安+${TapCounter.getTapCount()~/100}',
//                     style: TextStyle(color: textColor, fontSize: 32.sp,),
//                   ),
                ),

                 // "功德+${TapCounter.getTapCount()}",
//  child: FutureBuilder<String>(
  
//           future: counterHelper.getCountString(TapCounter.getTapCount()),
//           builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
//             if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
//               String countString = snapshot.data!;
//               int tapCount = TapCounter.getTapCount();
//                  String displayString = tapCount < 100 ? '摸鱼+$tapCount' : '平安+${tapCount ~/ 100}';
//              // String displayString = tapCount < 100 ? '摸鱼+$tapCount' : '平安+${tapCount ~/ 100}';
//               return Text(
                
//                 '$displayString',
//                 // '$displayString ($countString)',
//                 style: TextStyle(color: textColor, fontSize: 32.sp),
//               );

//             } else {
//               return Text(
//               TapCounter.getTapCount() < 100 ? '摸鱼+${TapCounter.getTapCount()}' : '平安+${TapCounter.getTapCount()~/100}',
//                 style: TextStyle(color: textColor, fontSize: 32.sp),
                
//               );
//             }
//           },
//         ),
      
              ),
            ));
    overlayState.insert(overlayEntry);
    await Future.delayed(const Duration(milliseconds: 200));
    showing = 1;
    overlayEntry.markNeedsBuild();
    await Future.delayed(const Duration(milliseconds: 300));

    if (DateTime.now().difference(startedTime).inMilliseconds >= 500) {
      showing = 2;
      overlayEntry.markNeedsBuild();
      Future.delayed(const Duration(milliseconds: 500)).then((_) {
        overlayEntry.remove();
        
      });
      
    }
  }
}
   