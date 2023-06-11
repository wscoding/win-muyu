
import 'package:flutter/material.dart';
import 'package:prue_widgets/models/version.dart';
import 'zanzhu.dart';
import 'license.dart';
class MorePage extends StatefulWidget {
  @override
  _MorePageState createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  bool switchValue = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(10.0, 0, 10.0, 1.0),
            height: 40,
            child: ListTile(
              title: Text('<返回'),
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
          ),
          ListTile(
            title: Text('赞助'),
            subtitle: Text('开发者'),
            trailing: Icon(Icons.arrow_forward),
            onTap: () {
               Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => zhzuListPage(),
                ),
              );
            },
          ),
          ListTile(
            title: Text('更新'),
            subtitle: Text('当前版本:v2.0'),
            trailing: Icon(Icons.arrow_forward),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DataListPage(),
                ),
              );
              // TODO: 在这里添加 Card 3 的点击事件处理代码
            },
          ),


            ListTile(
            title: Text('关于'),
            subtitle: Text('软件协议'),
            trailing: Icon(Icons.arrow_forward),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyLicensePage(),
                ),
              );
            },
          ),
          ListTile(
            title: Text('排行榜'),
            subtitle: Text('更多功能开发中'),
            trailing: Icon(Icons.arrow_forward),
            onTap: () {
              // TODO: 在这里添加 Card 2 的点击事件处理代码
            },
          ),
     
        ],
      ),
    );
  }
}