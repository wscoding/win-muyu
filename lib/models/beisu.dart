import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wooden_fish_for_windows/muyu.dart';

class SpeedSettingPage extends StatefulWidget {
  @override
  _SpeedSettingPageState createState() => _SpeedSettingPageState();
}

class _SpeedSettingPageState extends State<SpeedSettingPage> {
  double _speedMultiplier = 1.0;




  void _saveSpeedMultiplier() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('speedMultiplier', _speedMultiplier);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存(非实时更新)')),
    );
     Navigator.of(context).pop(); 
      navigateToSelectImageScreen();
  }

  @override
  void initState() {
    super.initState();
    _loadSpeedMultiplier();
  }

  void _loadSpeedMultiplier() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _speedMultiplier = prefs.getDouble('speedMultiplier') ?? 1.0;
     
    });
    
  }

    void navigateToSelectImageScreen() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WoodenFish()),
    ).then((value) {
      if (value != null) {
        setState(() {
            _speedMultiplier = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              SizedBox(height: 34),
            Text(
              '$_speedMultiplier x \n 敲击速度 ',
              style: TextStyle(fontSize: 24),
            ),
         //   SizedBox(height: 15),
            Slider(
              value: _speedMultiplier,
              min: 0.5,
              max: 2.0,
              divisions: 6,
              label: '$_speedMultiplier',
              onChanged: (value) {
                setState(() {
                  _speedMultiplier = value;
                });
              },
            ),
          ],
        ),
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: _saveSpeedMultiplier,
        child: Icon(Icons.save),
        
      ),
        floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
       floatingActionButtonLocation: FloatingActionButtonLocation.endTop,

    );
  }
}

