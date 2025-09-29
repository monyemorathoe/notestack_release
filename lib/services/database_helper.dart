import 'dart:async';
import 'dart:convert'; // Added for jsonDecode
import 'dart:io'; // <<< ADD THIS IMPORT
import 'package:flutter_quill/flutter_quill.dart'; // Added for Document
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart'; // <<< ADD THIS IMPORT
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // <<< ADD THIS IMPORT
// <<< HIDE the old getDatabasesPath
import '../models/note.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static const String _databaseName = "notes.db";
  static final int _databaseVersion = 3;

  // Define a subfolder name for your app's data to keep things organized
  static const String _appNameForPath = "NoteStack";

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Ensure FFI is initialized (typically done once in main.dart for desktop)
    // sqfliteFfiInit(); 

    Directory appSupportDir = await getApplicationSupportDirectory();
    String dbPath = join(appSupportDir.path, _appNameForPath, _databaseName);

    // For sqflite_common_ffi, the directory is created automatically if it doesn't exist
    // during openDatabase. Explicit creation can be done if needed for other reasons
    // or if issues arise, but often isn't necessary for the database file itself.
    // Example of explicit directory creation if you wanted it:
    // final dbDir = Directory(join(appSupportDir.path, _appNameForPath));
    // if (!await dbDir.exists()) {
    //   await dbDir.create(recursive: true);
    // }

    var dbFactory = databaseFactoryFfi; // Use FFI factory for desktop

    return await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL, -- Raw Quill Delta JSON
        plainTextContent TEXT NOT NULL DEFAULT '', -- For search
        category TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        modifiedAt TEXT,
        isArchived INTEGER NOT NULL DEFAULT 0,
        isPinned INTEGER NOT NULL DEFAULT 0,
        isLocked INTEGER NOT NULL DEFAULT 0,
        colorValue INTEGER
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute("ALTER TABLE notes ADD COLUMN modifiedAt TEXT;");
      } catch (e) {
        // print("Failed to add modifiedAt or it already exists: $e");
      }
      try {
        await db.execute("ALTER TABLE notes ADD COLUMN colorValue INTEGER;");
      } catch (e) {
        // print("Failed to add colorValue or it already exists: $e");
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute("ALTER TABLE notes ADD COLUMN plainTextContent TEXT NOT NULL DEFAULT '';");
        List<Map<String, dynamic>> existingNotes = await db.query('notes');
        for (var noteMap in existingNotes) {
          String id = noteMap['id'];
          String jsonContent = noteMap['content'];
          String plainText = '';
          try {
            if (jsonContent.isNotEmpty) {
              final List<dynamic> jsonData = jsonDecode(jsonContent);
              final doc = Document.fromJson(jsonData);
              plainText = doc.toPlainText().trim();
            }
          } catch (e) {
            plainText = jsonContent.trim();
          }
          await db.update(
            'notes',
            {'plainTextContent': plainText},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      } catch (e) {
        // print("Failed to add plainTextContent column or populate it: $e");
      }
    }
  }

  Future<void> insertNote(Note note) async {
    final db = await database;
    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Note?> getNoteById(String id) async {
    final db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Note.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Note>> getNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'modifiedAt DESC, createdAt DESC',
    );
    if (maps.isEmpty) {
      return [];
    }
    return List.generate(maps.length, (i) {
      return Note.fromMap(maps[i]);
    });
  }

  Future<List<Note>> searchNotes(String query) async {
    final db = await database;
    if (query.isEmpty) {
      return [];
    }
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: '(title LIKE ? OR plainTextContent LIKE ?) AND isArchived = 0',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'modifiedAt DESC',
    );

    if (maps.isEmpty) {
      return [];
    }
    return List.generate(maps.length, (i) {
      return Note.fromMap(maps[i]);
    });
  }

  Future<void> updateNote(Note note) async {
    final db = await database;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
