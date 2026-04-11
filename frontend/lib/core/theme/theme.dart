import 'package:flutter/material.dart';

class AppTheme {
  static const _primary = Color(0xFF1A1A2E);
  static const _accent = Color(0xFFE94560);
  static const _surface = Color(0xFF16213E);
  static const _background = Color(0xFF0F0F23);
  static const _card = Color(0xFF1A1A3E);

  static ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _background,
    primaryColor: _primary,
    colorScheme: const ColorScheme.dark(
      primary: _accent,
      secondary: _accent,
      surface: _surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _primary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: const CardThemeData(
      color: _card,
      elevation: 0,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _accent,
      foregroundColor: Colors.white,
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF2A2A4E), thickness: 0.5),
  );
}
