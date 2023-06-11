

import 'package:flutter/material.dart';




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
  onChanged: (_autofile) {
    widget.onSave(_autofile);
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