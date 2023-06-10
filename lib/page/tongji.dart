import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wooden_fish_for_windows/view.dart';

import '../muyu.dart';
class TapCountPage extends StatefulWidget {
  @override
  _TapCountPageState createState() => _TapCountPageState();
}

class _TapCountPageState extends State<TapCountPage> {
  int _tapCounts = 0;
  bool _isSwitched = false;

  @override
  void initState() {
    super.initState();
    _loadTapCount();
  }

  void _loadTapCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _tapCounts = prefs.getInt('tapCount') ?? 0;
    });
  }


  void _navigateToSelectImageScreen() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WoodenFish()),
    ).then((value) {
      if (value != null) {
        setState(() {
    //      _tapCounts = 0;
    _tapCounts = value;
        });
      }
    });
  }


  void _saveTapCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tapCount', _tapCounts);
  }

  void _incrementTapCount() {
    setState(() {
      _tapCounts++;
    });
    _saveTapCount();
  }

  void _decrementTapCount() {
    setState(() {
      _tapCounts--;
    });
    _saveTapCount();
  }

  void _clearTapCount() {
    setState(() {
      _tapCounts = 0;
    });
    _saveTapCount();
  }

  String _getTapCountDescription() {
    if (_tapCounts < 0) {
      return '不行';
    } else if (_tapCounts == 0) {
      return '无';
    } else if (_tapCounts <= 100) {
      return '可以';
    } else if (_tapCounts <= 1000) {
      return '厉害';
    } else if (_tapCounts <= 10000) {
      return '大于1000';
    } else {
      return '无敌';
    }
  }

  void _copyResultToClipboard() {
    String resultText =
        "当前水平:" + _getTapCountDescription() + ",敲击次数:" + _tapCounts.toString();
    Clipboard.setData(ClipboardData(text: resultText));
  }

  void _refreshTapCount() {
    _loadTapCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            ListTile(
              title: Text('<返回'),
              trailing: IconButton(
                icon: Icon(Icons.exit_to_app),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: Text('Copy'),
              subtitle:
                  Text(_tapCounts.toString() + '次,   ' + _getTapCountDescription()),
              trailing: IconButton(
                icon: Icon(Icons.content_copy),
                onPressed: _copyResultToClipboard,
              ),
            ),
            ListTile(
              title: Text(_tapCounts.toString()),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove),
                    onPressed: _decrementTapCount,
                  ),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: _incrementTapCount,
                  ),
                  IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: _clearTapCount,
                  ),
                ],
              ),
            ),
                    ElevatedButton(
              onPressed:
             (){
 _refreshTapCount();
 _navigateToSelectImageScreen();
              },
              
              child: Text('保存(加载SP)'),
            ),
            SwitchListTile(
              title: Text('正负极'),
              subtitle: Text('开发中...'),
              value: _isSwitched,
              onChanged: null,
            ),
            SizedBox(height: 16),
          //   ElevatedButton(
          //     child: Text('刷新'),
          //     onPressed: _refreshTapCount,
          //    // color: Colors.blue,
          //  //   textColor: Colors.white,
          //   ),

    
          ],
        ),
      ),
    );
  }
}