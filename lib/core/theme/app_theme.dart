import 'package:flutter/material.dart';

class AppTheme {
  // Светлая тема
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 255, 152, 0), brightness: Brightness.light),
      scaffoldBackgroundColor: Colors.grey[50],
      appBarTheme: const AppBarTheme(centerTitle: true, backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.black87),
    );
  }

  // Темная тема
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color.fromARGB(255, 149, 117, 205),
        brightness: Brightness.dark,
        // 👇 ВОТ СЮДА ДОБАВЛЯЕМ ЭТУ СТРОЧКУ:
        // Она перекрасит все фоны плашек и кастомных панелей в благородный тёмно-серый
        surface: const Color(0xFF1E1E1E),
      ),
      scaffoldBackgroundColor: const Color.fromARGB(255, 30, 30, 30),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Color.fromARGB(255, 72, 43, 96),
        elevation: 1,
        foregroundColor: Colors.white,
      ),
    );
  }
}
