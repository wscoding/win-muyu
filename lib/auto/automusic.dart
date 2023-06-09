import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class automusicPage extends StatefulWidget {
  const automusicPage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<automusicPage> {
  String _selectedMusic = ''; // 存储所选音乐

  @override
  void initState() {
    super.initState();
    _loadSelectedMusic(); // 加载保存的音乐选项
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('列表选择示例'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          const SizedBox(
            height: 100.0,
            child: Center(child: Text('列表项 1')),
          ),
          const SizedBox(
            height: 100.0,
            child: Center(child: Text('列表项 2')),
          ),
          const SizedBox(
            height: 100.0,
            child: Center(child: Text('列表项 3')),
          ),
          const SizedBox(
            height: 100.0,
            child: Center(child: Text('列表项 4')),
          ),
          const SizedBox(
            height: 100.0,
            child: Center(child: Text('列表项 5')),
          ),
          const SizedBox(
            height: 100.0,
            child: Center(child: Text('列表项 6')),
          ),
          const SizedBox(
            height: 100.0,
            child: Center(child: Text('列表项 7')),
          ),
          const SizedBox(
            height: 100.0,
            child: Center(child: Text('列表项 8')),
          ),
          const SizedBox(
            height: 100.0,
            child: Center(child: Text('列表项 9')),
          ),
          const SizedBox(
            height: 100.0,
            child: Center(child: Text('列表项 10')),
          ),
          RadioListTile<String>(
            title: const Text('音乐 A'),
            value: 'A',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
            },
          ),
          RadioListTile<String>(
            title: const Text('音乐 B'),
            value: 'B',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
            },
          ),
          RadioListTile<String>(
            title: const Text('音乐 C'),
            value: 'C',
            groupValue: _selectedMusic,
            onChanged: (String? value) {
              setState(() {
                _selectedMusic = value!;
                _saveSelectedMusic(value);
              });
            },
          ),
        ],
      ),
    );
  }
}