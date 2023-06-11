import 'dart:io';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class urlMusicPage extends StatefulWidget {
  const urlMusicPage({Key? key}) : super(key: key);

  @override
  _MyMusicPageState createState() => _MyMusicPageState();
}

class _MyMusicPageState extends State<urlMusicPage> {
  AudioPlayer? _audioPlayer;
  String? _musicurl;
  final TextEditingController _musicurlController = TextEditingController();
  final FocusNode _musicurlFocus = FocusNode();


  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _load_musicurl();
  }


  Future<void> _load_musicurl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _musicurl = prefs.getString('musicurl') ?? '';
      _musicurlController.text = _musicurl ?? '';
    });
  }

  Future<void> _savemusicurl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('musicurl', url);
  }

Future<bool> _checkmusicurl(String url) async {
  final file = File(url);
  if (await file.exists()) {
    
    _audioPlayer!.play(UrlSource(url));
    await Future.delayed(Duration(seconds: 1)); // 等待一段时间，让音频播放尝试完成
    await _audioPlayer!.stop();
    return true;
  }
  return false;
}
//网络
Future<bool> _checkAndPlayMusic(String url) async {
  
  try {
    final response = await http.head(Uri.parse(url));
    if (response.statusCode == 200) {
      final player = AudioPlayer();
      await player.play(UrlSource(url));
      return true;
    } else {
      return false;
    }
  } catch (e) {
    return false;
  }
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
   
      body: Column(
        children: <Widget>[

          ListTile(
        title:  Text('<返回'),
         trailing: const Text('*加载慢...'),
     //   trailing: IconButton( icon: Icon(Icons.exit_to_app), onPressed: (){   }),  
        onTap: () {
         //  clearSharedPreferences();
   Navigator.of(context).pop();   // 按钮点击事件处理
   
        },
      ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextFormField(
              decoration: const InputDecoration(
                hintText: '请输入网络音乐路径',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _musicurl = value;
                });
              },
              controller: _musicurlController,
              focusNode: _musicurlFocus,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
           
         
              ElevatedButton(
                onPressed: () async {
                  if (_musicurl != null && await _checkAndPlayMusic(_musicurl!)) {
                    await _savemusicurl(_musicurl!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已保存音乐路径。'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('无法保存此音乐路径。'),
                      ),
                    );
                  }
                },
                child: const Text('保存'),
              ),
     const SizedBox(width: 20.0),
                 ElevatedButton(
                onPressed: () async {
                  if (_musicurl != null && await _checkAndPlayMusic(_musicurl!)) {
                    await _audioPlayer!.play(UrlSource(_musicurl!));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('无法播放此音乐文件。'),
                      ),
                    );
                  }
                },
                child: const Text('播放'),
              ),
               const SizedBox(height: 20.0),
            ],
          ),



        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer!.dispose();
    _musicurlController.dispose();
    _musicurlFocus.dispose();
    super.dispose();
  }
}