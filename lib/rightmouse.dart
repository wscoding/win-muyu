import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
//import 'sp.dart';
import 'auto/autoswich.dart';


bool isLight = false;


String _customValue = '';
String _gongdeValue = '功德';
String _pinganValue = '平安';
//double  _ontimeValue = 1.0;
String _onumberValue = "1"; // 初始值为 "1"

///  = 是赋值运算符，用于将一个值赋给一个变量
///  == 是比较运算符，用于比较两个值是否相等



   const double popupMenuItemHeight = 30.0;   //父级菜单 高度
   const double appBarHeight = 20.0;   //子级菜单高度
   const double buttonHeight = 48.0;



 //  static void handleSoundSetting(BuildContext context) {

class MyPopupMenu  {


 static  void show(BuildContext context) {

    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(0, 50, 0, 0),
      items: [
          const PopupMenuItem(
    //    value: 'onone',
        enabled:false,
          height: appBarHeight,            
          child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text('  设置'),
      Icon(Icons.settings,
  color: Colors.green,),Text(' '),
    ],
  ),
        ),
        const PopupMenuItem(
          value: 'sound',
          height: popupMenuItemHeight,
          child: Center(
          child:  Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Icon(Icons.surround_sound_rounded,
  color: Colors.green,),Text('声音    '),
    ],
  ),),
        ),
        const PopupMenuItem(
          value: 'text',
          height: popupMenuItemHeight,
          child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Icon(Icons.border_color,
  color: Colors.green,),      Text('文字    '),
    ],
  ),
        ),
        const PopupMenuItem(
          value: 'color',
          height: popupMenuItemHeight,
          child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Icon(Icons.mode_night,
  color: Colors.green,),  Text('黑/白  '),
    ],
  ),
        ),
        const PopupMenuItem(
          value: 'ranking',
          height: popupMenuItemHeight,
          child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Icon(Icons.hdr_auto,
  color: Colors.green,), Text('功德榜'),
    ],
  ),
        ),
         const PopupMenuItem(
          value: 'helpme',
          height: popupMenuItemHeight,
          child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Icon(Icons.info,
  color: Colors.green,), Text('帮我敲'),
    ],
  ),
        ),
       const PopupMenuItem(
          value: 'onone',
          height: popupMenuItemHeight,
          child:  Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Icon(Icons.help_center,
  color: Colors.green,),Text('关于    '),
    ],
  ),
        ),
            const PopupMenuItem(
          value: 'clear',
          height: appBarHeight,
          child: Text('-清空退出-'),
        ),
        

      ],
      elevation: 8.0,
    ).then((value) {
      if (value == 'sound') {
       // MyPopupMenu myWidget = MyPopupMenu();
         handleSoundSetting(context);
        
      } else if (value == 'color') {
 isLight = !isLight;  

      
    // 处理文字设置
  } 
      else if (value == 'text') {
    textSoundSetting(context);
    // 处理文字设置
  } 
  else if (value == 'helpme') {
  helpmeSetting(context);
    // 退出
  } 
      else if (value == 'clear') {
        exit(0);
    // 退出
  } 
    });
  }
   static void handleSoundSetting(context) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(0, 50, 0, 0),
      items: [
           PopupMenuItem(
        value: 'on',
        height: popupMenuItemHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('开'),   
          MySwitch(),
          ],
        ),  
        ),
    const     PopupMenuItem(
          value: 'off',
          height: popupMenuItemHeight,
          child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           Text('关'),
  
        ],
      ),  
        ),
        const PopupMenuItem(
          value: 'toggle',
          height: popupMenuItemHeight,
          child: Text('切换'),
        ),
        const PopupMenuItem(
          value: 'default',
          height: popupMenuItemHeight,
          child: Text('默认'),
        ),
      ],
      elevation: 8.0,
    ).then((value) {
      if (value == 'on') {
       // handleSoundSetting('on');
      } else if (value == 'off') {

      } else if (value == 'toggle') {
        handleToggle(context);
      } else if (value == 'default') {
        // 处理恢复默认设置的操作
      }
    });
  }

  static void handleToggle(BuildContext context) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(0, 75, 0, 0),
      items: [
        const PopupMenuItem(
          value: 'toggle1',
          height: popupMenuItemHeight,
          child: Text('深沉'),
        ),
        const PopupMenuItem(
          value: 'toggle2',
          height: appBarHeight,
          child: Text('起伏'),
        ),
        const PopupMenuItem(
          value: 'toggle3',
            child: Text('保存自定义',
    style: TextStyle(
      color: Colors.blue, // 设置字体颜色为蓝色
    ),),  
        ),

        PopupMenuItem(
  value: 'custom',
  height: 10,
  child: TextFormField(
    initialValue: _customValue,
    decoration: const InputDecoration(
      labelText: '路径 or URL',
    ),
    onChanged: (value) {
        _customValue = value;
    },
  ),
),
      ],
      elevation: 8.0,
    ).then((value) {
      // 处理切换子菜单中选项的操作
    });
  }


    static void helpmeSetting(BuildContext context) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(0, 75, 0, 0),
      items: [
         PopupMenuItem(
          value: 'ontime',
          height: appBarHeight,
            child: TextFormField(
              maxLength: 3,        
    initialValue: _onumberValue,
      inputFormatters: [ FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),],
    decoration: const InputDecoration(  
      labelText: '每秒敲多少次?', 
      
       hintText: '最小0.5 - 最大3.0',
    ),
    
    onChanged: (value) {
        _onumberValue = value;
    },
  ),
        ),
            const PopupMenuItem(
          value: 'onumb',
          height: popupMenuItemHeight,
          child: Text('保存',style: TextStyle(
      color: Colors.blue, // 设置字体颜色为蓝色
    ),  ),
        ),
      ],
      elevation: 8.0,
    ).then((value) {
      // 处理切换子菜单中选项的操作
        if (value == 'islight') {
        // 切换颜色
 isLight = !isLight;      
      }
    });
  }


      static void textSoundSetting(BuildContext context) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(0, 75, 0, 0),
      items: [
        const PopupMenuItem(
          value: 'deftext',
          height: popupMenuItemHeight,
          child: Text('默认方案'),
        ),
          const PopupMenuItem(
          value: 'diytext',
          height: popupMenuItemHeight,
          child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text('自定义'),
      Icon(Icons.personal_injury_outlined,
  color: Colors.green,),
    ],
  ),
        ),
      ],
      elevation: 8.0,
    ).then((value) {
      // 处理切换子菜单中选项的操作
        if (value == 'deftext') {
        // 切换颜色
 isLight = !isLight;      
      }
       else if (value == 'diytext') {
               diytext(context);
        // 处理关闭声音的操作
      } 
    });
  }


///   文字自定义
    static void diytext(BuildContext context) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(0, 75, 0, 0),
      items: [
                 const PopupMenuItem(
          value: 'toggle1',
          height: popupMenuItemHeight,
          child: Text('保存',
    style: TextStyle(
      color: Colors.blue, // 设置字体颜色为蓝色
    ),),     
        ),

  PopupMenuItem(
          value: 'pingandiytext',
          height: appBarHeight,
    
 child: TextFormField(
 
    initialValue: _pinganValue,
    decoration: const InputDecoration(
      labelText: '英文逗号,隔开',
    ),
    onChanged: (value) {
        _pinganValue = value;
    },
 
  ),
        ),
         PopupMenuItem(
          value: 'gongdediytext',
          height: appBarHeight,
          
          
//功德
 child: TextFormField(
    maxLength: 2,
    initialValue: _gongdeValue,
    decoration: const InputDecoration(
      labelText: '前100次',
    ),
    onChanged: (value) {
        _gongdeValue = value;
    },
  ),
    ),
    //平安
   
      ],
      elevation: 8.0,
    ).then((value) {
      // 处理切换子菜单中选项的操作
        if (value == 'islight') {
        // 切换颜色
 isLight = !isLight;      
      }
       else if (value == 'diytext') {
             //  diytext(context);
        // 处理关闭声音的操作
      } 
    });
  }
    
}