import 'package:flutter/material.dart';

class zhzuListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
   
      body: ListView(
        children: [
          Column(
            children: [
      Text('向下滚动滑轮返回  '),
        
              Image.asset(
                'assets/images/wx.png',
                width: MediaQuery.of(context).size.width,
                fit: BoxFit.fitWidth,
                     semanticLabel: '测试2',
              ),
               Text('微信扫一扫 ↑'),
            ],
          ),
          Column(
            children: [
                Text('支付宝扫一扫 ↓'),
             //   Text('支付宝扫一扫 ↓'),
              Image.asset(
                'assets/images/alipay.png',
                width: MediaQuery.of(context).size.width,
                fit: BoxFit.fitWidth,
                     semanticLabel: '测试2',
              ),
            
            ],
          ),
          Column(
            children: [
                Text('官网二维码 ↓'),
              Image.network(
                'http://file.iqg.cc/0l9rfsPI',
                width: MediaQuery.of(context).size.width,
                fit: BoxFit.fitWidth,
                     semanticLabel: '测试2',

                     errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                  return Image.network(
                    'http://iqg.cc/assets/img/about-01.jpg',
                    width: MediaQuery.of(context).size.width,
                    fit: BoxFit.fitWidth,
                    semanticLabel: '测试2',
                  );
                },
              ),
            Text('开发不易,多多支持'),
            ],
          ),

               ListTile(
                trailing:  Icon(Icons.heart_broken_rounded),
              title: Text('<返回'),
              subtitle: Text('           谢谢阅读'),
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}