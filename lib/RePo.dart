
import 'dart:convert';
import 'package:http/http.dart' as http;



//const or  static  ----help doc
// 常量和静态变量在 Dart 中有以下区别：

// 可变性
// 常量是指在编译时就确定了值的变量，它们的值在程序运行时不可更改。而静态变量是指在整个程序生命周期中都存在的变量，它们的值可以被修改。

// 关联性
// 常量是与类或方法关联的，而静态变量是与类关联的。这意味着，常量只能在声明它们的类或方法中被访问，而静态变量可以在整个程序中被访问。

// 内存占用
// 常量在编译时就确定了值，它们只会占用一份内存空间。而静态变量在整个程序生命周期中都存在，它们的值在内存中也只有一份拷贝。因此，常量和静态变量都可以用于优化内存占用。

// 声明方式
// 常量是使用 const 关键字声明的，而静态变量是使用 static 关键字声明的。

//const String baseUrl = 'http://zt.999087.com/app/muyu/repo.php';
const String versions = "1.4";
const String appkey = "8f23f05b4a50b6481ff020320692f9e9";
const String hosturl = "d.999087.com";
const String mposturl = "zt.999087.com/app/muyu/repo.php";
//const String mycolor = "black";
//const String others = "1";


//启动次数
class Getadd {
  static Future<http.Response> sendRequest() async {
    var url = Uri.parse('http://$hosturl/api.php?type=add&appkey=$appkey');
    var response = await http.get(url);
    //print(response.body);
   //print(url.toString());
    return response;
  }
}
// use class
//  Getadd.sendRequest();

//在线人数
class GetOnline {
  static Future<http.Response> sendRequest() async {
    var url = Uri.parse('http://$hosturl/api.php?type=addOnlineNumber&appkey=$appkey');
    var response = await http.get(url);
   //print(response.body);
    //print(url.toString());
    return response;
  }
}
// use class
//  GetOnline.sendRequest();

//主程序统计
class Masterpost {
//sendRequest(String other,String more) ...
  static Future<Map<String, dynamic>> sendRequest(String content,String others, var colorss) async {
    var url = Uri.parse('http://$mposturl');
    var body = {
    
      'version': versions,
      'content': content,
      'appkey': appkey,
      'other': others,
      'color': colorss
    };
    var headers = {'Content-Type': 'application/x-www-form-urlencoded'};
    var response = await http.post(url, headers: headers, body: body);
    var responseBody = utf8.decode(response.bodyBytes);
    var responseJson = json.decode(responseBody);
    return responseJson;
  }

}

//debug 开关 请求demo方法  
// void main() async {
//    var others = '123'; 
//   var responseJson = await Masterpost.sendRequest(others);
//   print(responseJson);
// }
