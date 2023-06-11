// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prue_widgets/models/automusic.dart';
import 'package:prue_widgets/muyu.dart';

import '../models/palymusic.dart';
import '../models/urlplay.dart';

class musicSubPage extends StatefulWidget {
  const musicSubPage({Key? key}) : super(key: key);

  @override
  _MySubPageState createState() => _MySubPageState();
}

class _MySubPageState extends State<musicSubPage> {
  String? _selectedOption;
  String _autofile = '';
  String _selectmusic = 'muyu';

  @override
  void initState() {
    super.initState();
    _loadSelectedOption();
  }

    void navigateToSelectImageScreen() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WoodenFish()),
    ).then((value) {
      if (value != null) {
        setState(() {
            _selectedOption = value;
        });
      }
    });
  }


  Future<void> _loadSelectedOption() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedOption = prefs.getString('selectedOption');
        _autofile = prefs.getString('autofile') ?? '';
         _selectmusic = prefs.getString('selectmusic') ?? '';
    });
  }

  zhenze1(){
  String tt = _selectmusic;
RegExp exp = RegExp(r"audio\/|\.mp3");
String resultmp3 = tt.replaceAll(exp, "");
//print(result);  // 输出 "qingcui"
return resultmp3;
}


  Future<void> _saveSelectedOption(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedOption', value);
    await prefs.setString('autofile', _autofile);


  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     
      body: ListView(

        
        children: <Widget>[

   ListTile(
        title:  Text('<返回'),
          trailing: 
           IconButton( icon: Icon(Icons.save), 
          onPressed: (){  
            
navigateToSelectImageScreen();
           }),  
     //   trailing: IconButton( icon: Icon(Icons.exit_to_app), onPressed: (){   }),  
        onTap: () {
         //  clearSharedPreferences();
             ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('记得保存')),
    );
   Navigator.of(context).pop();   // 按钮点击事件处理
   
        },
      ),

          ListTile(
            title: const Text('内置'),
 trailing: const Text('默认'),
            subtitle:  Text(zhenze1()),
            leading: Radio(
              value: 'demusic',
              groupValue: _selectedOption,
              onChanged: (String? value) async {
                setState(() {
                  _selectedOption = value;
                });
                await _saveSelectedOption(value!);
                if (_selectedOption == 'demusic') {
                   Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => automusicPage()),
                );
                }
              },
            ),
            onTap: () {
              if (_selectedOption == 'demusic') {
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => automusicPage()),
                );
          //      Navigator.pushNamed(context, '/built-in');
              }
            },
          ),
          ListTile(
            trailing: const Text('推荐'),
            title: const Text('本地'),
                   subtitle:  Text("mp3、wav等"),
            leading: Radio(
              value: 'localmusic',
              groupValue: _selectedOption,
              onChanged: (String? value) async {
                setState(() {
                  _selectedOption = value;
                });
                await _saveSelectedOption(value!);
                if (_selectedOption == 'localmusic') {
           
             Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyMusicPage()),
                );

                }
              },
            ),
            onTap: () {
              if (_selectedOption == 'localmusic') {

             Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyMusicPage()),
                );

              }

            },
          ),
          ListTile(
            title: const Text('URL'),
                  subtitle:  Text("直链"),
             trailing: const Text('不推荐'),
            leading: Radio(
              value: 'urlmusic',
              groupValue: _selectedOption,
              onChanged: (String? value) async {
                
                setState(() {
                  _selectedOption = value;
                });
                await _saveSelectedOption(value!);
                if (_selectedOption == 'urlmusic') {
            Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => urlMusicPage()),
                );
                  
                }
              },
            ),
            onTap: () {
              if (_selectedOption == 'urlmusic') {
               Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => urlMusicPage()),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}