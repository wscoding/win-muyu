import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';


class automusicPage extends StatefulWidget {
  const automusicPage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<automusicPage> {
final _audioPlayer = AudioPlayer();

  String _selectedMusic = 'audio/muyu.mp3'; // 存储所选音乐

  @override
  void initState() {
    super.initState();
    _loadSelectedMusic(); // 加载保存的音乐选项
      

  }


  @override
  void dispose() {
    super.dispose();
  
  }



  // 加载保存的音乐选项
  void _loadSelectedMusic() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedMusic = prefs.getString('selectmusic') ?? '';
    });
  }

  // 保存所选音乐
  void _saveSelectedMusic(String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('selectmusic', value);
  }

 //Todo



  @override
  Widget build(BuildContext context) {
    return Scaffold(
    
      body: 




      ListView(
        padding: const EdgeInsets.all(1.0),
        children: <Widget>[

          ListTile(
          title: Text('<返回'),
         // subtitle: Text('Subtitle 1'),
          //trailing: Icon(Icons.arrow_forward),
          onTap: () {
           Navigator.of(context).pop(); 
          },
        ),
         
          RadioListTile<String>(
            title: const Text('清脆'),
            value: 'audio/qingcui.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(()  {
                _selectedMusic = value!;
                _saveSelectedMusic(value);


              });  
                _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });

            },
            
          ),
          RadioListTile<String>(
            title: const Text('低沉(默认)'),
            value: 'audio/muyu.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),
          RadioListTile<String>(
            title: const Text('水滴'),
            value: 'audio/shuidi.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });

                       _audioPlayer.play(AssetSource("$value")).then((value) {

  });
            },
          ),

               RadioListTile<String>(
            title: const Text('okay'),
            value: 'audio/okay.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });

                          _audioPlayer.play(AssetSource("$value")).then((value) {

  });
            },
          ),


               RadioListTile<String>(
            title: const Text('~~叮~'),
            value: 'audio/ding.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
            },
          ),



               RadioListTile<String>(
            title: const Text('咚~'),
           value: 'audio/dong.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
            },
          ),

               RadioListTile<String>(
            title: const Text('你干嘛'),
            value: 'audio/ngm.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),


               RadioListTile<String>(
            title: const Text('卡带'),
            value: 'audio/error.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),




               RadioListTile<String>(
            title: const Text('飞盘'),
            value: 'audio/feipan.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),





               RadioListTile<String>(
            title: const Text('放屁'),
            value: 'audio/fenpi.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),




               RadioListTile<String>(
            title: const Text('只因'),
            value: 'audio/gee.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),




       


               RadioListTile<String>(
            title: const Text('娇喘'),
            value: 'audio/jiaochuan.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),


               RadioListTile<String>(
            title: const Text('喵~~'),
            value: 'audio/miao.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),

     RadioListTile<String>(
            title: const Text('哞~~'),
            value: 'audio/mou.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),


     RadioListTile<String>(
            title: const Text('气泡'),
            value: 'audio/qipao.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),



     RadioListTile<String>(
            title: const Text('水滴'),
            value: 'audio/shuidi.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),



     RadioListTile<String>(
            title: const Text('惊讶'),
            value: 'audio/jingya.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),


     RadioListTile<String>(
            title: const Text('解压'),
            value: 'audio/jieya.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),


     RadioListTile<String>(
            title: const Text('叮咚'),
            value: 'audio/dingdong.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),


        RadioListTile<String>(
            title: const Text('打鼾'),
            value: 'audio/hang.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),



     RadioListTile<String>(
            title: const Text('wow'),
            value: 'audio/wow.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),


     RadioListTile<String>(
            title: const Text('咩~~'),
            value: 'audio/yang.mp3',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
                 _audioPlayer.play(AssetSource("$value")).then((value) {
    // 播放完成后执行其他操作
    //print('音乐播放完毕');
  });
            },
          ),





        ],
      ),
    );
  }
}