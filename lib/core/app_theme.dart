import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seedColor = Color(0xFF3157A4);
  static const _fontFamily = 'Sniglet';

  static ThemeData get light => _buildTheme(Brightness.light);

  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: brightness == Brightness.light ? const Color(0xFFF7F9FC) : null,
      textTheme: (brightness == Brightness.light
              ? Typography.material2021(platform: TargetPlatform.android).black
              : Typography.material2021(platform: TargetPlatform.android).white)
          .apply(
        bodyColor: brightness == Brightness.light ? const Color(0xFF1A1D24) : null,
        displayColor: brightness == Brightness.light ? const Color(0xFF1A1D24) : null,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: brightness == Brightness.light ? Colors.white : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light ? const Color(0xFFF0F3F8) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}