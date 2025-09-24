import 'dart:io'; // Added for Platform check
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Added for FFI
// import 'package:google_fonts/google_fonts.dart'; // Already handled in AppTheme
import 'providers/note_provider.dart';
import 'providers/theme_provider.dart'; // Import ThemeProvider
import 'providers/checklist_provider.dart';
import 'screens/home_screen.dart';
import 'screens/checklist_screen.dart';
import 'package:notestack/theme/app_theme.dart';
// import 'services/notification_service.dart'; // Removed NotificationService import

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for sqflite if on Windows, Linux or macOS
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // await NotificationService().init(); // Removed NotificationService initialization
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()), // Add ThemeProvider
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
        );
      },
    );
  }
}
