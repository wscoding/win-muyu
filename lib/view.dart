import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/beisu.dart';
import 'undeniable/filelocal.dart';
import 'pageview/viewdraw.dart';
import 'pageview/tongji.dart';
import 'pageview/moretext.dart';
import 'pageview/chmusic.dart';
import 'muyu.dart';
import 'pageview/morepage.dart';

class MenuPage extends StatefulWidget {

 
 // const MenuPage({super.key});
  @override
  _MenuPageState createState() => _MenuPageState();
}
class _MenuPageState extends State<MenuPage> {
   //final TextEditingController _controller = TextEditingController();

  bool _isSoundOno = true, isHelpme = false, isLight = false;
  //不建议使用_
  String _autoText = 'Bug', _isavedNumber = '', _aboutText = '',_iotText = '',_moretext = '';
   double speedMultiplier = 1.0;
 String  _selectedOption = "demusic";
  //double _iotText = ;
    double _timeText = 1.0;
    double popupMenuItemHeight = 40.0;   //父级菜单 高度
    double appBarHeight = 1.0;   //子级菜单高度
    double buttonHeight = 48.0;
//bool isLight = false;
  int _tapCount = 0;
       
  @override
  void initState() {
    super.initState();
    loadSettings();
  }

Future<void> clearSharedPreferences() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}


//Todo  读取sp
  void loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String selectedOption = prefs.getString('selectedOption') ?? "demusic";
    setState(() {
         

        speedMultiplier = prefs.getDouble('speedMultiplier') ?? 1.0;
        _moretext = prefs.getString('moretext') ?? "平安";
      _isSoundOno = prefs.getBool('_isSoundOno') ?? true;
     //  _autoText = prefs.getString('autoText') ?? '';//次数
         _timeText = prefs.getDouble('timeText') ?? 10;
     isHelpme = prefs.getBool('isHelpme') ?? true;
     isLight = prefs.getBool('isLight') ?? false;
    _aboutText = prefs.getString('aboutText') ?? '';
      _autoText = prefs.getString('autoText') ?? 'Bug';
       _isavedNumber = prefs.getString('isavedNumber') ?? '';
             _tapCount = prefs.getInt('tapCount') ?? 0;
    _selectedOption = selectedOption;
 //左边是vlue  右边带边从sp里面获取数据
   // _controller.text = _savedNumber;
    });
  }

   //更新  及写入  sp
  void _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

     await prefs.setDouble('speedMultiplier', speedMultiplier);

    await prefs.setBool('isLight', isLight);
       await prefs.setString('moretext', _moretext);//平安
    //_aboutText 是用户填写的值  aboutText是sp数据库的表
   await prefs.setBool('isHelpme', isHelpme);
   await prefs.setString('autoText', _autoText);
    await prefs.setBool('_isSoundOno', _isSoundOno);
  await prefs.setString('savenumber', _autoText);
  await prefs.setString('aboutText', _aboutText);//100
      ///将用户填写的值_aboutText 写入sp的aboutText表
      //左表(固定)看不见   右值(可读写)能看见
       //   await prefs.setInt('tapCount', _tapCount);

    await prefs.setString('isavedNumber', _isavedNumber);

     setState(() {
      speedMultiplier = speedMultiplier;



    });
  
  }

  //如何使用 
  /*
  SharedPreferences prefs = await SharedPreferences.getInstance();
String aboutText = prefs.getString('aboutText') ?? 'About this app';


bool isSoundOn = prefs.getBool('isSoundOn') ?? true; // default value is true
  */

  void navigateToSelectImageScreen() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WoodenFish()),
    ).then((value) {
      if (value != null) {
        setState(() {
          speedMultiplier = value;
        });
      }
    });
  }


  @override
  Widget build(BuildContext context) {


    return Scaffold(
      
      body: ListView(
     padding: EdgeInsets.symmetric(vertical: 1.0),
               //   padding: EdgeInsets.symmetric(vertical: 1.0),
        children: [
            
          SizedBox(
            
      height: popupMenuItemHeight, // 设置按钮高度为 50 像素
      child: ListTile(
           trailing: IconButton(
            icon: Icon(Icons.clear),
            onPressed: (){
exit(0);
            }
          ),
        title:  Text('< 返回'),
     
        onTap: () {
         //  clearSharedPreferences();
   Navigator.of(context).pop();   // 按钮点击事件处理
   
        },
      ),
    ),       
//文字
ExpansionTile( 
                 //trailing:Text("1023"),
                 subtitle:const Text("支持滑动下拉"),
            title:const Text('文字  +1' ,style: TextStyle(
              fontSize: 20.0,          
              height: 1,
            ),),
            children: [
   ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 5.0),

      title: const Text('   前100次'),
    trailing: Text(_autoText),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
 builder: (context) => textPage(
   initialValue: _autoText,
   onSave: (text) {
     setState(() {
       _autoText = text;
     });
     _saveSettings();
   },
 ),
                    ),
                  );
                },
              ),

              ListTile(
  title: Text ('$_autoText/100'),
    trailing: const Text('Json'),
  onTap: () {
   Navigator.push(
  context,
  MaterialPageRoute(      builder: (context) => MyTableLayoutPage(),),
);
  },
),
ListTile(
  title:const Text('停留'),
   trailing:const Text('开发中...'),
  onTap: () {

  },
),
      
              
            ],
          ),
    SizedBox(
      height: popupMenuItemHeight, // 设置按钮高度为 50 像素
      child: ListTile(
        title:const  Text('图片'),
trailing: FutureBuilder<String?>(
  future: SelectedImageName.init().then((_) => SelectedImageName.value),
  builder: (context, snapshot) {
    String data = snapshot.data ?? '';
    return Text(data);
  },
),
onTap: () async {
  String? selectedImageName = await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => MyImageSelectionPage()),
  );
    setState(() { 
    }); // 更新视图
},

      ),
    ),
     SizedBox(
      height: 40, // 设置 ListTile 的高度为 80 像素
      child: ListTile(
       subtitle :Text(isLight ? '挂载' : '保存'),
        title: Text('数据'),
          trailing: Switch(
              value: isLight,
              onChanged: (value) {
                setState(() {
             isLight =! value;
                 //  isLight = !isLight;      
                });
                _saveSettings();
             navigateToSelectImageScreen();
              },
            ),  
           // subtitle: Text(isLight ? '黑色' : '白色'),
      ),
    ),

                 ExpansionTile(
            title:const  Text('敲击声'),
            children: [          
     SizedBox(
  height:40, // 设置 ListTile 的高度为 30 像素
  child: ListTile(
    title:  Text(_isSoundOno ? '开' : '关'), // 左侧文本
    trailing: Switch(
      value: _isSoundOno,
        onChanged: null,
      // onChanged: (value) {
      //   setState(() {
      //     _isSoundOno = value;
      //   });
      //   _saveSettings();
      // },
    ), // 中间开关按钮
  //     subtitle: Text(_isSoundOno ? '开' : '关'),
  ),
),

const SizedBox(
height: 10,
),
    
              ListTile(
                title:const Text('音频'),
                trailing:Text(_selectedOption),
                onTap: () {
                    // 在 onTap 中打开 automusic.dart 页面
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => musicSubPage()),
                );
                },
              ),
              
                 ListTile(
      title:const Text('播放速度'),
        trailing: Text('$speedMultiplier x'),
                onTap: () {

   setState(() {
final speedMultiplier =  Navigator.push<double>(
  context,
  MaterialPageRoute(builder: (context) => SpeedSettingPage()),
);
if (speedMultiplier != null) {
  // 处理选中的速度值
  
}
        });

         
                },
              ),
            ],
          ),  
          //Todo
                      ExpansionTile(
            title:const Text('帮我敲'),
            children: [
              
     SizedBox(
  height:30, // 设置 ListTile 的高度为 30 像素
  child: ListTile(
    title:Text(isHelpme ? '开' : '关'), // 左侧文本
    trailing: Switch(
      value: isHelpme,
      onChanged: (value) {
        setState(() {
          isHelpme = value;
        });
        _saveSettings();
         // navigateToSelectImageScreen();
      },
    ), // 中间开关按钮
      // subtitle: Text(isHelpme ? '开' : '关'),
  ),
),




              ListTile(
  title:const Text('定时任务'),
  trailing:const Text('开发中...'),
  onTap: () {

  },
),
ListTile(
  title:const Text('跟随心跳'),
  trailing:const Text('开发中...'),
  onTap: () {

  },
),
  
        
              


       
            ],

          ),


            SizedBox(
     // height: 60, // 设置按钮高度为 50 像素
      child: ListTile(
        title:const  Text('*统计 beta'),
       // trailing:const  Text('*beta'),
      trailing  :Text(_tapCount.toString()+' 次'),
        onTap: () {
         Navigator.push(
  context,
  MaterialPageRoute(builder: (context) =>  TapCountPage()),
);
         //  clearSharedPreferences();

       //  Navigator.of(context).pop();   // 按钮点击事件处理
        },
      ),
    ),

          ListTile(
                title:const Text('更多'),
                trailing:Icon(Icons.commit),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MorePage(),
                    ),
                  );
                },
              ),



        ],
      ),
    );
  }
}






//文字
class textPage extends StatefulWidget {
 final String initialValue;
 final Function(String) onSave;

textPage({required this.initialValue, required this.onSave});

  @override
  _textPage createState() => _textPage();
}


class _textPage extends State<textPage> {
  late TextEditingController _controller;

@override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    
      body: Column(
        children: [
          TextField(
  controller: _controller,
   keyboardType: TextInputType.text,
  //inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
    inputFormatters: [
    LengthLimitingTextInputFormatter(20), // 限制输入文本的长度为20个字符
  FilteringTextInputFormatter.allow(RegExp(r'^[\u4e00-\u9fa5a-zA-Z, ]+$')), 
  // 只允许输入中文、英文、英文逗号和空格

  ],
  onChanged: (value) {
    widget.onSave(value);
  },
  decoration: InputDecoration(
    hintText: '最大:15 仅允许中英文',
    border:const OutlineInputBorder(),
    
    filled: true,
    fillColor: Colors.grey[200],
    contentPadding:const EdgeInsets.all(8.0),
  ),
),
   SizedBox(height: 10),
          ElevatedButton(
            child:
             Text('保存'),
            onPressed: () {
              widget.onSave(_controller.text);
              Navigator.pop(context);
            },
          ),

           Expanded(
      child: ListView(
        children: [
          Container(
            height: 20, // 设置第一个视图项的高度为 50 像素
            child:const ListTile(
              title: Text('英文逗号,隔开'),
            ),
          ),
          Container(
            height: 20, // 设置第一个视图项的高度为 50 像素
            child:const ListTile(
              title: Text('每个词语不超3字符'),
            ),
          ),
          Container(
            height: 20, // 设置第一个视图项的高度为 50 像素
            child:const ListTile( 
              title: Text('若异常,请恢复默认'),
            ),
          ),
          // 添加更多的视图项
        ],
      ),
    ),
        ],
      ),
      
    );
  }
}






