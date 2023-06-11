import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyTableLayoutPage extends StatefulWidget {
  @override
  _MyTableLayoutPageState createState() => _MyTableLayoutPageState();
}

class _MyTableLayoutPageState extends State<MyTableLayoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  List<String> _list = [];

String? str = 'hello';
//String nonNullableStr = str!;

  @override
  void initState() {
    super.initState();
    _loadList();
  }




    Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData == null) return;

    final jsonString = clipboardData.text;
    try {
      final list = json.decode(jsonString!) as List<dynamic>;
      _list.addAll(list.cast<String>());
      setState(() {});

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('list', json.encode(_list));
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已写入'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      // 剪贴板中的内容不是合法的 JSON 字符串

         ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('无json'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _loadList() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('list');
    if (json != null) {
      final list = jsonDecode(json);
      if (list is List) {
        setState(() {
          _list = List<String>.from(list);
        });
      }
    }
  }

  void _saveList() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_list);
    prefs.setString('list', json);
  }

  void _addToList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _textController,
                    autofocus: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入内容';
                      } else if (value.length < 1 || value.length > 3) {
                        return '请输入 1-3 个字符';
                      } else if (!RegExp(r'^[\u4e00-\u9fa5a-zA-Z]+$').hasMatch(value)) {
                        return '请输入中英文字符';
                      } else {
                        return null;
                      }
                    },
                    decoration: InputDecoration(labelText: '内容'),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        setState(() {
                          _list.add(_textController.text);
                        });
                        _saveList();
                        Navigator.pop(context);
                      }
                    },
                    child: Text('添加'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _editListItem(int index) {
    _textController.text = _list[index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _textController,
                    autofocus: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入内容';
                      } else if (value.length < 1 || value.length > 3) {
                        return '请输入 1-3 个字符';
                      } else if (!RegExp(r'^[\u4e00-\u9fa5a-zA-Z]+$').hasMatch(value)) {
                        return '请输入中英文字符';
                      } else {
                        return null;
                      }
                    },
                    decoration: InputDecoration(labelText: '内容'),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        setState(() {
                          _list[index] = _textController.text;
                        });
                        _saveList();
                        Navigator.pop(context);
                      }
                    },
                    child: Text('保存'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _removeFromList(int index) {
    setState(() {
      _list.removeAt(index);
    });
    _saveList();
  }

  void _copyListToClipboard() async {
    if (_list.isNotEmpty) {
      final json = jsonEncode(_list);
      await Clipboard.setData(ClipboardData(text: json));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已复制'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
       // title: Text('列表页'),
        actions: [
          IconButton(
            onPressed: _copyListToClipboard,
            icon: Icon(Icons.copy),
          ),
          IconButton(
            icon: Icon(Icons.paste),
            onPressed: _pasteFromClipboard,
          ),
        ],
      ),
      body: _list.isEmpty
          ? Center(
              child: Text('列表为空'),
            )
          : ListView.separated(
              itemBuilder: (BuildContext context, int index) {
                return Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (DismissDirection direction) async {
                    return await showDialog(
                          context: context,
                    builder: (BuildContext context) {
    return AlertDialog(
      title: Text('确认'),
      content: Container(
        height: 30,
        child: Center(
          child: Text('您确认要执行此操作吗？'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('确认'),
        ),
      ],
    );
  },
                        ) ??
                        false;
                  },
                  onDismissed: (DismissDirection direction) {
                    _removeFromList(index);
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  child: ListTile(
                    title: Text(_list[index]),
                    onTap: () {
                      _editListItem(index);
                    },
                  ),
                );
              },
              separatorBuilder: (BuildContext context, int index) => Divider(),
              itemCount: _list.length,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addToList,
        child: Icon(Icons.add),
      ),
    );
  }
}


/*
Future<void> printListFromPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = prefs.getString('list');
  if (jsonString != null) {
    final list = json.decode(jsonString) as List<dynamic>;
    final stringList = list.cast<String>();
    print(stringList);
  } else {
    print('List not found in SharedPreferences.');
  }
}



import 'package:path/to/prefs.dart';

// 在其他文件中调用 printListFromPrefs 函数
await printListFromPrefs();









*/
