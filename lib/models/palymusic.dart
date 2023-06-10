import 'dart:io';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

class MyMusicPage extends StatefulWidget {
  const MyMusicPage({Key? key}) : super(key: key);

  @override
  _MyMusicPageState createState() => _MyMusicPageState();
}

class _MyMusicPageState extends State<MyMusicPage> {
  AudioPlayer? _audioPlayer;
  String? _musicPath;
  final TextEditingController _musicPathController = TextEditingController();
  final FocusNode _musicPathFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadMusicPath();
  }



  Future<void> _loadMusicPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _musicPath = prefs.getString('musicPath') ?? '';
      _musicPathController.text = _musicPath ?? '';
    });
  }

  Future<void> _saveMusicPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('musicPath', path);
  }

Future<bool> _checkMusicPath(String path) async {
  final file = File(path);
  if (await file.exists()) {
    _audioPlayer!.play(DeviceFileSource(path));
    await Future.delayed(Duration(seconds: 1)); // 等待一段时间，让音频播放尝试完成
    await _audioPlayer!.stop();
    return true;
  }
  return false;
}

  Future<void> _pickMusic() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    if (result != null) {
      final path = result.files.single.path;
      setState(() {
        _musicPath = path;
      _musicPathController.text = path!;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
   
      body: Column(
       // mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: <Widget>[

          ListTile(
        title:  Text('<返回'),
         trailing: const Text('(录音开发中)'),
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
                hintText: '请输入本地音乐路径',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _musicPath = value;
                });
              },
              controller: _musicPathController,
              focusNode: _musicPathFocus,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
           
         
              ElevatedButton(
                onPressed: () async {
                  if (_musicPath != null && await _checkMusicPath(_musicPath!)) {
                    await _saveMusicPath(_musicPath!);
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
              //    ElevatedButton(
              //   onPressed: () async {
              //     if (_musicPath != null && await _checkMusicPath(_musicPath!)) {
              //       await _audioPlayer!.play(DeviceFileSource(_musicPath!));
              //     } else {
              //       ScaffoldMessenger.of(context).showSnackBar(
              //         const SnackBar(
              //           content: Text('无法播放此音乐文件。'),
              //         ),
              //       );
              //     }
              //   },
              //   child: const Text('播放'),
              // ),

  ElevatedButton(
              onPressed: _pickMusic,
              child: Text('打开'),
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
    _musicPathController.dispose();
    _musicPathFocus.dispose();
    super.dispose();
  }
}