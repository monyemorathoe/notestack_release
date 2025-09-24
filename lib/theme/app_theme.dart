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

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark, // Important for correct dark color generation
    ),
    useMaterial3: true, // Explicitly use Material 3
    appBarTheme: AppBarTheme(
      backgroundColor: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark).surfaceContainerHighest,
      foregroundColor: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark).onSurface,
      elevation: 0, // Modern flat app bar
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark).primaryContainer,
      foregroundColor: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark).onPrimaryContainer,
    ),
    cardTheme: CardThemeData( // Corrected: CardThemeData
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark).surfaceContainerLow,
    ),
    textTheme: GoogleFonts.poppinsTextTheme( // Apply Poppins to dark theme
      ThemeData(brightness: Brightness.dark).textTheme,
    ),
    // Add other customizations as needed
  );

  // Private constructor to prevent instantiation
  AppTheme._();
}
