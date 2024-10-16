import 'package:flutter/material.dart';
import 'home.dart'; // นำเข้า Home.dart

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SQLite User App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(), // ตั้งค่า HomePage เป็นหน้าแรก
    );
  }
}
