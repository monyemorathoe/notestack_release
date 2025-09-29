import 'dart:io'; // Added for Platform check
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Added for FFI
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:google_fonts/google_fonts.dart'; // Already handled in AppTheme
import 'providers/note_provider.dart';
import 'providers/theme_provider.dart'; // Import ThemeProvider
import 'providers/checklist_provider.dart';
import 'screens/home_screen.dart';
import 'screens/checklist_screen.dart';
import 'package:notestack/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart'; // For setting native window title

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    // Set native window title
    await windowManager.setTitle('NoteStack');

    // Lock minimum size
    await windowManager.setMinimumSize(const Size(650, 700));
    // (Optional) Lock maximum size too, if you want to prevent resizing beyond certain bounds
    // await windowManager.setMaximumSize(const Size(800, 800));
  }

  // Initialize FFI for sqflite if on desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ChecklistProvider()),
      ],
      child: const NoteStackApp(),
    ),
  );
}

class NoteStackApp extends StatelessWidget {
  const NoteStackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>( // Consume ThemeProvider to access themeMode
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'NoteStack',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode, // Use themeMode from ThemeProvider
          home: const HomeScreen(),
          routes: {
            '/checklist': (context) => const ChecklistScreen(),
          },
          debugShowCheckedModeBanner: false, // Optional: to hide debug banner
          localizationsDelegates: const [
            GlobalCupertinoLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'), // Add more locales as needed
          ],
        );
      },
    );
  }
}
