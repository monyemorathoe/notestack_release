import 'package:flutter/material.dart';

class AppTheme {
  // Common seed color for consistency, but can be different for light/dark if desired
  static const Color _seedColor = Colors.blueGrey;
  static const String _fontFamily = 'Poppins'; // Added

  // Returns true when running on desktop platforms (Windows, macOS, Linux)

  // Create a light theme while taking platform into account
  static final ThemeData lightTheme = _buildLightTheme();

  static ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );

    // Base text theme with Poppins applied
    TextTheme baseTextTheme = ThemeData(brightness: Brightness.light).textTheme.apply(fontFamily: _fontFamily);

    return ThemeData(
      brightness: Brightness.light,
      fontFamily: _fontFamily,
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surfaceContainer,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        // Use semibold for app bar titles (600). Make color dynamic via colorScheme.
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 20) ??
            TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w600, color: colorScheme.onSurface, fontSize: 20),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: colorScheme.surfaceContainerLow,
      ),
      textTheme: baseTextTheme,
    );
  }

  // Create a dark theme while taking platform into account
  static final ThemeData darkTheme = _buildDarkTheme();

  static ThemeData _buildDarkTheme() {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF35363A),
      surfaceContainerHighest: const Color(0xFF3C3F41),
      primary: fabMainColor,
      secondary: fabChecklistColor,
      onSurface: Colors.white,
    );

    TextTheme baseTextTheme = ThemeData(brightness: Brightness.dark).textTheme.apply(
          fontFamily: _fontFamily,
          bodyColor: Colors.white,
          displayColor: Colors.white,
        );

    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: _fontFamily,
      colorScheme: baseScheme,
      scaffoldBackgroundColor: const Color(0xFF23242A),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF2B2B2B),
        foregroundColor: baseScheme.onSurface,
        elevation: 0,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(color: baseScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 20) ??
            const TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w600, color: Colors.white, fontSize: 20),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: fabMainColor,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        color: const Color(0xFF323232),
      ),
      textTheme: baseTextTheme,
    );
  }

  // Custom accent colors for FABs in dark mode
  static const Color fabMainColor = Color(0xFF769FEA); // Blue accent
  static const Color fabChecklistColor = Color(0xFF307F76); // Teal accent
  static const Color fabNoteColor = Color(0xFFFFB74D); // Amber accent

  // Private constructor to prevent instantiation
  AppTheme._();
}
