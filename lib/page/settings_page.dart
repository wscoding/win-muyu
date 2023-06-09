import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  final int initialValue;

  SettingsPage({required this.initialValue});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedMenuItem = 1;

  @override
  void initState() {
    super.initState();
    _selectedMenuItem = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('设置'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text('菜单 1'),
            trailing: Radio(
              value: 1,
              groupValue: _selectedMenuItem,
              onChanged: (value) {
                setState(() {
                  _selectedMenuItem = value!;
                });
              },
            ),
            onTap: () {
              setState(() {
                _selectedMenuItem = 1;
              });
            },
          ),
          ListTile(
            title: Text('菜单 2'),
            trailing: Radio(
              value: 2,
              groupValue: _selectedMenuItem,
              onChanged: (value) {
                setState(() {
                  _selectedMenuItem = value!;
                });
              },
            ),
            onTap: () {
              setState(() {
                _selectedMenuItem = 2;
              });
            },
          ),
          ListTile(
            title: Text('菜单 3'),
            trailing: Radio(
              value: 3,
              groupValue: _selectedMenuItem,
              onChanged: (value) {
                setState(() {
                  _selectedMenuItem = value!;
                });
              },
            ),
            onTap: () {
              setState(() {
                _selectedMenuItem = 3;
              });
            },
          ),
          ElevatedButton(
            child: Text('保存'),
            onPressed: () {
              Navigator.pop(context, _selectedMenuItem);
            },
          ),
        ],
      ),
    );
  }
}