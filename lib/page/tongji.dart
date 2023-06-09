import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TapCountPage extends StatefulWidget {
  @override
  _TapCountPageState createState() => _TapCountPageState();
}
  int _tapCount = 0;
  bool _isSwitched = false;

class _TapCountPageState extends State<TapCountPage> {

  @override
  void initState() {
    super.initState();
    _loadTapCount();
  }

  void _loadTapCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _tapCount = prefs.getInt('tapCount') ?? 0;
    });
  }

  void _saveTapCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tapCount', _tapCount);
  }

  void _incrementTapCount() {
    setState(() {
      _tapCount++;
    });
    _saveTapCount();
  }

  void _decrementTapCount() {
    setState(() {
      _tapCount--;
    });
    _saveTapCount();
  }

  void _clearTapCount() {
    setState(() {
      _tapCount = 0;
    });
    _saveTapCount();
  }

  String _getTapCountDescription() {
    if (_tapCount < 0) {
      return '不行';
    } else if (_tapCount == 0) {
      return '无';
    } else if (_tapCount <= 100) {
      return '可以';
    } else if (_tapCount <= 1000) {
      return '厉害';
    } else if (_tapCount <= 10000) {
      return '大于1000';
    } else {
      return '无敌';
    }
  }

  void _copyResultToClipboard() {
    String resultText = "当前水平:"+_getTapCountDescription() +",敲击次数:"+ _tapCount.toString();
    Clipboard.setData(ClipboardData(text: resultText));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
   
      body: SingleChildScrollView(
   child: Column(
 children: [

    ListTile(
              title: Text('<返回'),
           //   subtitle: Text(_getTapCountDescription()),
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
              subtitle: Text(_tapCount.toString()+'次,   '+_getTapCountDescription()),
              trailing: IconButton(
                icon: Icon(Icons.content_copy),
                onPressed: _copyResultToClipboard,
              ),
            ),
            ListTile(
          //    title: Text('T'),
              title: Text(_tapCount.toString()),
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
                    onPressed:
                     _clearTapCount,
              
                  ),
                ],
              ),
              

            ),
               SwitchListTile(
              title: Text('正负极'),
              subtitle:Text('开发中...'),
              
              value: _isSwitched,
               onChanged: null,
            ),
          ],
        ),
      ),
    );
  }
}