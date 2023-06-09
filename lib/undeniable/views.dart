import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GridPage extends StatefulWidget {
  const GridPage({Key? key}) : super(key: key);

  @override
  _GridPageState createState() => _GridPageState();
}

class _GridPageState extends State<GridPage> {
  final int rowCount = 4;
  final int columnCount = 4;
  late List<List<TextEditingController>> _controllers;
  late List<List<String?>> _values;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(rowCount, (_) => List.generate(columnCount, (_) => TextEditingController()));
    _values = List.generate(rowCount, (_) => List.generate(columnCount, (_) => null));
    _loadValues();
  }

  Future<void> _loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> values = [];
    for (int i = 0; i < rowCount * columnCount; i++) {
      String key = 'grid_value_$i';
      String? value = prefs.getString(key);
      if (value != null && value.isNotEmpty) {
        values.add(value);
      }
    }
    for (int i = 0; i < values.length; i++) {
      int row = i ~/ columnCount;
      int column = i % columnCount;
      setState(() {
        _controllers[row][column].text = values[i];
        _values[row][column] = values[i];
      });
    }
  }

  void _saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int index = 0;
    List<String> values = [];
    for (int row = 0; row < rowCount; row++) {
      for (int column = 0; column < columnCount; column++) {
        String? value = _values[row][column];
        if (value != null && value.isNotEmpty) {
          String key = 'grid_value_$index';
          prefs.setString(key, value);
          values.add(value);
          index++;
        }
      }
    }
    for (int i = index; i < rowCount * columnCount; i++) {
      String key = 'grid_value_$i';
      prefs.remove(key);
    }
    _generateJSON(values);
  }

  void _generateJSON(List<String> values) {
    List<Map<String, String>> jsonValues = [];
    for (int i = 0; i < values.length; i++) {
      int row = i ~/ columnCount;
      int column = i % columnCount;
      Map<String, String> data = {
        'row': row.toString(),
        'column': column.toString(),
        'value': values[i],
      };
      jsonValues.add(data);
    }
    Clipboard.setData(ClipboardData(text: json.encode(jsonValues)));
  }

  void _clearValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < rowCount * columnCount; i++) {
      String key = 'grid_value_$i';
      prefs.remove(key);
    }
    setState(() {
      _values = List.generate(rowCount, (_) => List.generate(columnCount, (_) => null));
    });
  }

  @override
  Widget build(BuildContextcontext) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Grid Page'),
        actions: [
          IconButton(
            onPressed: _saveValues,
            icon: Icon(Icons.save),
          ),
          IconButton(
            onPressed: _clearValues,
            icon: Icon(Icons.delete),
          ),
          IconButton(
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              List<String> values = [];
              for (int i = 0; i < rowCount * columnCount; i++) {
                String key = 'grid_value_$i';
                String? value = prefs.getString(key);
                if (value != null && value.isNotEmpty) {
                  values.add(value);
                }
              }
              _generateJSON(values);
            },
            icon: Icon(Icons.copy),
          ),
          SizedBox(width: 8),
          // Placeholder button for layout purposes
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.add),
          ),
        ],
      ),
      body: GridView.builder(
        padding: EdgeInsets.all(16),
        itemCount: rowCount * columnCount,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (BuildContext context, int index) {
          int row = index ~/ columnCount;
          int column = index % columnCount;
          return TextFormField(
            controller: _controllers[row][column],
            onChanged: (value) {
              setState(() {
                _values[row][column] = value.isNotEmpty ? value : null;
              });
              if (value.isNotEmpty) {
                SharedPreferences.getInstance().then((prefs) {
                  String key = 'grid_value_$index';
                  prefs.setString(key, value);
                });
              } else {
                SharedPreferences.getInstance().then((prefs) {
                  String key = 'grid_value_$index';
                  prefs.remove(key);
                });
              }
            },
            maxLength: 3,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z\u4e00-\u9fa5]{0,3}')),
            ],
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: '$row,$column',
            ),
          );
        },
      ),
    );
  }
}