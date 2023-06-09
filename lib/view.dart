import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/automusic.dart';
import 'package:wooden_fish_for_windows/page/viewdraw.dart';
import 'page/tongji.dart';
import 'page/moretext.dart';
//import 'undeniable/views.dart';


class MenuPage extends StatefulWidget {

 
 // const MenuPage({super.key});
  @override
  _MenuPageState createState() => _MenuPageState();
}
class _MenuPageState extends State<MenuPage> {
   //final TextEditingController _controller = TextEditingController();

  bool _isSoundOno = true, _isHelpme = false, _isColorBh = true;

  String _autoText = '', _isavedNumber = '', _aboutText = '',_iotText = '',_moretext = '';
 
  //double _iotText = ;
    double _timeText = 1.0;
    double popupMenuItemHeight = 30.0;   //父级菜单 高度
    double appBarHeight = 1.0;   //子级菜单高度
    double buttonHeight = 48.0;
bool isLight = false;
  int _tapCount = 0;
       
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

Future<void> clearSharedPreferences() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}


//Todo 
  void _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
        _moretext = prefs.getString('moretext') ?? "平安";
      _isSoundOno = prefs.getBool('_isSoundOno') ?? true;
     //  _autoText = prefs.getString('autoText') ?? '';//次数
         _timeText = prefs.getDouble('timeText') ?? 10;
     _isHelpme = prefs.getBool('_isHelpme') ?? true;
     _isColorBh = prefs.getBool('_isColorBh') ?? true;
    _aboutText = prefs.getString('aboutText') ?? '';
      _autoText = prefs.getString('autoText') ?? '';
       _isavedNumber = prefs.getString('isavedNumber') ?? '';
             _tapCount = prefs.getInt('tapCount') ?? 0;

 //左边是vlue  右边带边从sp里面获取数据
   // _controller.text = _savedNumber;
    });
  }

   
  void _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setBool('_isColorBh', _isColorBh);
       await prefs.setString('moretext', _moretext);//平安

    //_aboutText 是用户填写的值  aboutText是sp数据库的表
   await prefs.setBool('_isHelpme', _isHelpme);
   await prefs.setString('autoText', _autoText);
    await prefs.setBool('_isSoundOno', _isSoundOno);
  await prefs.setString('savenumber', _autoText);
  await prefs.setString('aboutText', _aboutText);//100
      ///将用户填写的值_aboutText 写入sp的aboutText表
      //左表(固定)看不见   右值(可读写)能看见
          await prefs.setInt('tapCount', _tapCount);

    await prefs.setString('isavedNumber', _isavedNumber);
  }

  //如何使用 
  /*
  SharedPreferences prefs = await SharedPreferences.getInstance();
String aboutText = prefs.getString('aboutText') ?? 'About this app';


bool isSoundOn = prefs.getBool('isSoundOn') ?? true; // default value is true
  */

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
        title:  Text('< 返回'),
        trailing: IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: (){
exit(0);
            }
          ),
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
  title:const Text('分享'),
   trailing:const Text('开发中...'),
  onTap: () {

  },
),
              // ListTile(
              //   title:const Text('更多'),
              //   onTap: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (context) => MorePage(),
              //       ),
              //     );
              //   },
              // ),
              
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
       subtitle :Text(_isColorBh ? '已完成' : '点我'),
        title: Text('初始化'),
          trailing: Switch(
              value: _isColorBh,
              onChanged: (value) {
                setState(() {
                  _isColorBh = value;
                   isLight = !isLight;      
                });
                _saveSettings();
              },
            ),  
           // subtitle: Text(_isColorBh ? '黑色' : '白色'),
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
      onChanged: (value) {
        setState(() {
          _isSoundOno = value;
        });
        _saveSettings();
      },
    ), // 中间开关按钮
  //     subtitle: Text(_isSoundOno ? '开' : '关'),
  ),
),

              ListTile(
                title:const  Text('切换声音'),
                trailing:const  Text('路径'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AboutPage(
                        initialValue: _aboutText,
                        onSave: (text) {
                          setState(() {
                            _aboutText = text;
                          });
                          _saveSettings();
                        },
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                title:const Text('内置'),
                onTap: () {
                    // 在 onTap 中打开 automusic.dart 页面
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => automusicPage()),
                );
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
    title:Text(_isHelpme ? '开' : '关'), // 左侧文本
    trailing: Switch(
      value: _isHelpme,
      onChanged: (value) {
        setState(() {
          _isHelpme = value;
        });
        _saveSettings();
      },
    ), // 中间开关按钮
      // subtitle: Text(_isHelpme ? '开' : '关'),
  ),
),


   ListTile(
      title:const Text('速度'),
        trailing:const Text('开发中...'),
                onTap: () {
         
                },
              ),

              ListTile(
  title:const Text('定时任务'),
  trailing:const Text('开发中...'),
  onTap: () {

  },
),
ListTile(
  title:const Text('联网任务'),
  trailing:const Text('开发中...'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => helpmePage(
          initialValue: _iotText,
          onSave: (text) {
            setState(() {
              _iotText = text;
            });
            _saveSettings();
          },
        ),
      ),
    );
  },
),


              ListTile(
                title:const Text('更多'),
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

       SizedBox(
      height: popupMenuItemHeight, // 设置按钮高度为 50 像素
      child: ListTile(
        title:const  Text('排行榜'),
          trailing:const Text('开发中...'),
        onTap: () {


         //  clearSharedPreferences();
       //  Navigator.of(context).pop();   // 按钮点击事件处理
        },
      ),
    ),
       SizedBox(
      height: popupMenuItemHeight, // 设置按钮高度为 50 像素
      child: ListTile(
        title:const  Text('统计'),
        trailing:const  Text('*beta'),
      //  subtitle  :Text(_tapCount.toString()),
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

          ExpansionTile(
            title:const Text('更多'),
            children: [
              ListTile(
                title:const Text('关于'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AboutPage(
                        initialValue: _aboutText,
                        onSave: (text) {
                          setState(() {
                            _aboutText = text;
                          });
                          _saveSettings();
                        },
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                title:const Text('赞助'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MorePage(),
                    ),
                  );
                },
              ),
                     ListTile(
                title:const Text('更新  '),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MorePage(),
                    ),
                  );
                },
              ),
                     ListTile(
                title:const Text('统计'),
                  trailing:const Text('开发中...'),
                onTap: () {
               
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}




class AboutPage extends StatefulWidget {
  final String initialValue;
  final Function(String) onSave;

  AboutPage({required this.initialValue, required this.onSave});

  @override
  _AboutPageState createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
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
  onChanged: (value) {
    widget.onSave(value);
  },
  decoration: InputDecoration(
    hintText: '输入路径 or URL',
    border:const OutlineInputBorder(),
    filled: true,//填充
    fillColor: Colors.grey[200],
    contentPadding:const EdgeInsets.all(8.0),
  ),
),
const   SizedBox(height: 10),
          ElevatedButton(
            child:
          const   Text('保存'),
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
              title: Text('仅MP3格式文件'),
            ),
          ),
          Container(
            height: 20, // 设置第一个视图项的高度为 50 像素
            child:const ListTile(
              title: Text('若失效请使用默认设置'),
            ),
          ),
          Container(
            height: 20, // 设置第一个视图项的高度为 50 像素
            child:const ListTile(
              title: Text('时长建议 0.5-3 秒'),
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

//自动敲
class helpmePage extends StatefulWidget {
  final String initialValue;
  final Function(String) onSave;

  helpmePage({required this.initialValue, required this.onSave});

  @override
  _helpmePage createState() => _helpmePage();
}


class _helpmePage extends State<helpmePage> {
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
   keyboardType: TextInputType.number,
  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
  onChanged: (value) {
    widget.onSave(value);
  },
  decoration: InputDecoration(
    hintText: '输入路径 or URL',
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
              title: Text('仅支持音频格式的文件'),
            ),
          ),
          Container(
            height: 20, // 设置第一个视图项的高度为 50 像素
            child:const ListTile(
              title: Text('若失效请使用默认设置'),
            ),
          ),
          Container(
            height: 20, // 设置第一个视图项的高度为 50 像素
            child:const ListTile(
              title: Text('时长0.5-3.0 S'),
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



class MorePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
return Scaffold(

  body: Column(
    
    children: [
      Container(
         padding: EdgeInsets.fromLTRB(20.0, 0, 40.0, 1.0),
        height: 30,
        child: ListTile(
          title: Text('<返回'),
         // subtitle: Text('Subtitle 1'),
          //trailing: Icon(Icons.arrow_forward),
          onTap: () {
           Navigator.of(context).pop(); 
          },
        ),
      ),
      Container(
        height: 40,
        child: ListTile(
          title: Text('Card 2'),
          subtitle: Text('Subtitle 2'),
          trailing: Icon(Icons.arrow_forward),
          onTap: () {
            // TODO: 在这里添加 Card 2 的点击事件处理代码
          },
        ),
      ),
      Container(
        height: 40,
        child: ListTile(
          
          title: Text('Card 3'),
          subtitle: Text('Subtitle 3'),
          trailing: Icon(Icons.arrow_forward),
          onTap: () {
            // TODO: 在这里添加 Card 3 的点击事件处理代码
          },
        ),
      ),

      
    ],
  ),
);
  }
}

