import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MySwitch extends StatefulWidget {
  @override
  _MySwitchState createState() => _MySwitchState();
}

class _MySwitchState extends State<MySwitch> {
  bool _isSwitchOn = false;

  @override
  void initState() {
    super.initState();
    _loadSwitchValue();
  }

  Future<void> _loadSwitchValue() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSwitchOn = prefs.getBool('is_switch_on') ?? false;
    });
  }

  Future<void> _saveSwitchValue(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_switch_on', value);
    setState(() {
      _isSwitchOn = value;
    });
  }

  bool getSwitchValue() {
    return _isSwitchOn;
  }

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: _isSwitchOn,
      onChanged: (bool value) async {
        await _saveSwitchValue(value);
      },
    );
  }
}