import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../muyu.dart';


class MyImageSelectionPage extends StatefulWidget {
  const MyImageSelectionPage({super.key});

  @override
  _MyImageSelectionPageState createState() => _MyImageSelectionPageState();
}

class _MyImageSelectionPageState extends State<MyImageSelectionPage> {
  final List<String> imageNames = [
    'bad',
    'bagua',
    'bug',
    'car',
    'code',
    'ddog',
    'def',
    'eat',
    'fang',
    'fish',
    'fishs',
    'game',
    'good',
    'goods',
    'hearts',
    'herat',
    'hhh',
    'home',
    'hongbao',
    'idea',
    'jing',
    'love',
    'mb',
    'mooy',
    'moyu',
    'music',
    'muyu',
    'no',
    'pass',
    'phone',
    'qianbao',
    'qing',
    'qq',
    'rigthfish',
    'school',
    'shop',
    'sleep',
    'sui',
    'wechat',
    'wh',
    'xiao',
    'xiaochou',
    'muyu',
  ];

  String? _selectedImageName;

  @override
  void initState() {
    super.initState();
    _selectedImageName = SelectedImageName.value;
  }


  void _navigateToSelectImageScreen() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WoodenFish()),
    ).then((value) {
      if (value != null) {
        setState(() {
          _selectedImageName = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  
      body: ListView.builder(
        itemCount: imageNames.length,
        itemBuilder: (context, index) {
          String imageName = imageNames[index];
          return ListTile(
            leading: Image.asset('assets/images/$imageName.png', width: 40, height: 40),
            title: Text(imageName),
            trailing: _selectedImageName == imageName ? Icon(Icons.check, color: Colors.green) : null,
            onTap: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setString('selectedImageName', imageName);
              setState(() {
                _selectedImageName = imageName;
              });
              Navigator.pop(context, imageName);
              _navigateToSelectImageScreen();
            },
          );
        },
      ),
    );
  }
}

class SelectedImageName {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String? get value => _prefs.getString('selectedImageName');

  static Future<void> setValue(String value) async {
    await _prefs.setString('selectedImageName', value);
  }
}