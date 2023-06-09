import 'package:flutter/material.dart';

class AboutPage extends StatefulWidget{
  final String initialValue;

  AboutPage({required this.initialValue});

  @override
  _AboutPageState createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('输入路径 or URL'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: '操作值',
              ),
            ),
          ),
          ElevatedButton(
            child: Text('保存'),
            onPressed: () {
              Navigator.pop(context, _controller.text);
            },
          ),
        ],
      ),
    );
  }
}