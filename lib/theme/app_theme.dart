import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import google_fonts

class AppTheme {
  // Common seed color for consistency, but can be different for light/dark if desired
  static const Color _seedColor = Colors.blueGrey;

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    ),
    useMaterial3: true, // Explicitly use Material 3
    appBarTheme: AppBarTheme(
      backgroundColor: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.light).surfaceContainer, // Changed to surfaceContainer
      foregroundColor: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.light).onSurface,
      elevation: 0, // Modern flat app bar
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.light).primary,
      foregroundColor: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.light).onPrimary,
    ),
    cardTheme: CardThemeData( // Corrected: CardThemeData
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.light).surfaceContainerLow,
    ),
    textTheme: GoogleFonts.poppinsTextTheme( // Apply Poppins to light theme
      ThemeData(brightness: Brightness.light).textTheme,
    ),
    // Add other customizations as needed
  );

  // Custom accent colors for FABs in dark mode
  static const Color fabMainColor = Color(0xFF769FEA); // Blue accent
  static const Color fabChecklistColor = Color(0xFF307F76); // Teal accent
  static const Color fabNoteColor = Color(0xFFFFB74D); // Amber accent

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF35363A),    // Slightly lighter for surfaces
      surfaceContainerHighest: const Color(0xFF3C3F41),
      primary: fabMainColor,    // Use blue accent for primary
      secondary: fabChecklistColor,  // Teal for secondary/accent
      onSurface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF23242A), // Slightly lighter for better color pop
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF2B2B2B),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: fabMainColor, // Blue accent
      foregroundColor: Colors.white, // White icon/text
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      color: Color(0xFF323232),
    ),
    textTheme: GoogleFonts.poppinsTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    // Add other customizations as needed
  );

  // Private constructor to prevent instantiation
  AppTheme._();
}
