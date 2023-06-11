import 'package:flutter/material.dart';

class MyLicensePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
     
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MIT License',
              style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.0),
            Text(
              '版权所有 (c)\n 2023.6\n           by 无书',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.0),
            Text(
              '       特此授予任何获得本软件和相关文档文件（“软件”）副本的人员无限制地处理本软件的权利，包括但不限于使用、复制、修改、合并、出版、分发、再许可和/或销售本软件的副本，以及允许软件提供的人员这样做，但须符合以下条件：',
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 8.0),
            Text(
              '       本软件的所有副本或实质性部分必须包含上述版权声明、本条件声明和以下免责声明。',
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 8.0),
            Text(
              '       本软件按“原样”提供，不作任何明示或暗示的保证，包括但不限于适销性、特定用途的适用性和非侵权性的保证。在任何情况下，作者或版权持有人均不对任何索赔、损害赔偿或其他责任承担责任，无论是在合同、侵权行为或其他方面产生的，与本软件有关或与本软件的使用或其他交易有关。',
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 16.0),
            Text(
              '隐私政策',
              style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.0),
            Text(
              '       本软件保护用户隐私，不会收集用户的个人信息或隐私数据。本软件使用的第三方服务可能会收集一些匿名数据，用于改善软件的性能和用户体验。这些服务的隐私政策可能与本软件的隐私政策不同，请用户在使用本软件前仔细阅读相关服务的隐私政策。',
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 16.0),
            Text(
              '开源信息',
              style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.0),
            Text(
              '       本软件基于 MIT 许可协议开源，任何人都可以自由使用、复制、修改、合并、出版、分发、再许可和/或销售本软件的副本。开源软件不提供任何担保或技术支持，开发者不承担因软件使用或修改而导致的任何责任。如有商业需求，请联系开发者获取商业授权。',
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 16.0),
            Text(
              '联系我们',
              style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.0),
            Text(
'开发者：\nLi Zhenyan\nQQ群号：574237747\n反馈电子邮箱：\n2821981550\n@qq.com\n软件技术：Flutter dart3',
              style: TextStyle(fontSize: 16.0),
            ),
         ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Container(
          height: 50.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}