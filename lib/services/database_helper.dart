import 'dart:async';
import 'dart:convert'; // Added for jsonDecode
import 'package:flutter_quill/flutter_quill.dart'; // Added for Document
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/note.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static const String _databaseName = "notes.db";
  static final int _databaseVersion = 3; // <<< VERSION IS NOW 3

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
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
        // print("Column plainTextContent added.");

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
            // If content is not valid JSON delta, it might be old plain text.
            // Or it might be an error. For simplicity, we'll use the raw content if it's not JSON.
            // A more robust solution might try to differentiate or log this.
            plainText = jsonContent.trim(); 
            // print("Error decoding JSON for note $id, using raw content for plainText: $e");
          }
          await db.update(
            'notes',
            {'plainTextContent': plainText},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        // print("Populated plainTextContent for existing notes.");
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
      orderBy: 'modifiedAt DESC, createdAt DESC', // Sort by modified, then created
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
      // Search in title and the new plainTextContent column
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
