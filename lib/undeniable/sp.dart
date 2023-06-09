import 'package:flutter/material.dart';
//import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';


class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _soundSetting = '开';
  String _textSetting = '默认';
  String _colorSetting = '黑';
  String _rankingSetting = 'http://iqg.cc/';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundSetting = prefs.getString('sound_setting') ?? '开';
      _textSetting = prefs.getString('text_setting') ?? '默认';
      _colorSetting = prefs.getString('color_setting') ?? '黑';
      _rankingSetting = prefs.getString('ranking_setting') ?? 'http://iqg.cc/';
    });
  }

  void _saveSetting(String key, String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: ListView(
        children: [
          ListTile(
            title: const Text('声音'),
            trailing: DropdownButton<String>(
              value: _soundSetting,
              onChanged: (newValue) {
                setState(() {
                  _soundSetting = newValue!;
                  _saveSetting('sound_setting', newValue);
                });
              },
              items: <String>['开', '关', '切换'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          ListTile(
            title: const Text('文字'),
            trailing: DropdownButton<String>(
              value: _textSetting,
              onChanged: (newValue) {
                setState(() {
                  _textSetting = newValue!;
                  _saveSetting('text_setting', newValue);
                });
              },
              items: <String>['默认', '自定义'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          ListTile(
            title: const Text('颜色'),
            trailing: DropdownButton<String>(
              value: _colorSetting,
              onChanged: (newValue) {
                setState(() {
                  _colorSetting = newValue!;
                  _saveSetting('color_setting', newValue);
                });
              },
              items: <String>['黑', '白'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          ListTile(
            title: const Text('排行榜'),
            trailing: TextButton(
              onPressed: () {},
              child: Text(_rankingSetting),
            ),
          ),
          ListTile(
            title:const Text('清空退出'),
            onTap: () {
              //  清空数据并退出应用
            },
          ),
        ],
      ),
    );
  }
  
}

