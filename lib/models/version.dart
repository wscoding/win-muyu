import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class DataListPage extends StatefulWidget {
  @override
  _DataListPageState createState() => _DataListPageState();
}

class _DataListPageState extends State<DataListPage> {
  List<dynamic> dataList = [];
  bool switchValue = false;
  String url = 'http://zt.999087.com/app/muyu/version.json';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      switchValue = prefs.getBool('switchValue') ?? false;
      url = switchValue
          ? 'http://zt.999087.com/app/muyu/version.json'
          : 'http://code.iqg.cc/app/version.json';
    });

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
 final jsonString = utf8.decode(response.bodyBytes);
  final jsonData = json.decode(jsonString);
      setState(() {
        dataList = [jsonData];
      });
        String downloadUrl = jsonData['download'];
      prefs.setString('data', json.encode(jsonData));
      
    //      await _launchUrl(downloadUrl);
  // await _launchUrl(downloadUrl);
    } else {
      throw Exception('Failed to load data');
    }
  }



Future<void> _launchUrl(String downloadUrl) async {

  final Uri url = Uri.parse(downloadUrl);
 //  await _launchUrl(downloadUrl);
   print('Opened URL: $downloadUrl');
  
  if (!await launchUrl(url)) {
    throw Exception('Could not launch $downloadUrl');
  }
}
openurl(String downloadUrl){
   final Uri url = Uri.parse(downloadUrl);
   _launchUrl(downloadUrl);
   print(downloadUrl);
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
  
      body: SingleChildScrollView(
        child: Column(
          children: [

            ListTile(
       
        title:  Text('< 返回'),
     
        onTap: () {
         //  clearSharedPreferences();
   Navigator.of(context).pop();   // 按钮点击事件处理
   
        },
      ),
            SwitchListTile(
              title: Text('发行'),
              subtitle: Text(switchValue ? 'release' : 'beta'),
              value: switchValue,
              onChanged: (value) async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                prefs.setBool('switchValue', value);
                setState(() {
                  switchValue = value;
                });
                _loadData();
              },
              
            ),


            
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: dataList.length,
              itemBuilder: (context, index) {
                return ListTile(
               title: Text(dataList[index]['appName']),
               subtitle :const Text('服务器版本号'),
                  trailing: Text(dataList[index]['version']),
                );
              },
            ),
               ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: dataList.length,
              itemBuilder: (context, index) {
                return ListTile(
                subtitle  :const Text('开发环境'),
                  title: Text(dataList[index]['packageName']),
                trailing  : Text(dataList[index]['buildNumber']),
                   
                );
              },
            ),

                 ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: dataList.length,
              itemBuilder: (context, index) {
                return ListTile(
                subtitle    :const Text('构建日期'),
                  title: Text(dataList[index]['buildSignature']),
                 trailing : Text(dataList[index]['installerStore']),
                );
              },
            ),

                   ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: dataList.length,
              itemBuilder: (context, index) {
                return ListTile(
                subtitle    :const Text('更新日志'),
                  title: Text(dataList[index]['appbuild']),
                 trailing : Text(dataList[index]['newlog']),
                );
              },
            ),

        //     ListView.builder(
        //   shrinkWrap: true,
        //   physics: NeverScrollableScrollPhysics(),
        //   itemCount: dataList.length,
        //   itemBuilder: (context, index) {
        //     return ListTile(
        //       subtitle: const Text('更新日志'),
        //       title: Text(dataList[index]['download']),
        //       trailing: ElevatedButton(
        //         child: Text('打开'),
        //         onPressed: () => _launchURL(dataList[index]['download']),
             
        //       ),
        //     );
        //   },
        // ),

        ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: dataList.length,
      itemBuilder: (context, index) {
        return ListTile(
        title  : const Text('PW官网'),
          subtitle: Text(Uri.parse(dataList[index]['download']).host),
          trailing: ElevatedButton(
            child: Text('打开'),
            onPressed: () {
                         openurl(dataList[index]['download']);
            },
            //_launchUrl(downloadUrl);
          ),
        );
      },
    ),


          ],
        ),
      ),
    );
  }




}