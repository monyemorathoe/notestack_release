import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/note.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static const String _databaseName = "notes.db";
  static final int _databaseVersion = 2; // <<< VERSION IS NOW 2

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
      onUpgrade: _onUpgrade, // <<< ENSURED onUpgrade IS CALLED
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
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

  // <<< NEW/UPDATED onUpgrade METHOD
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute("ALTER TABLE notes ADD COLUMN modifiedAt TEXT;");
        // print("Column modifiedAt added.");
      } catch (e) {
        // print("Failed to add modifiedAt or it already exists: $e");
      }
      try {
        await db.execute("ALTER TABLE notes ADD COLUMN colorValue INTEGER;");
        // print("Column colorValue added.");
      } catch (e) {
        // print("Failed to add colorValue or it already exists: $e");
      }
    }
    // For future versions:
    // if (oldVersion < 3) {
    //   // await db.execute("ALTER TABLE notes ADD COLUMN anotherNewColumn TEXT;");
    // }
  }

  Future<void> insertNote(Note note) async {
    final db = await database;
    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // print('Note inserted: ${note.id}');
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
    final List<Map<String, dynamic>> maps = await db.query('notes');
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
      where: '(title LIKE ? OR content LIKE ?) AND isArchived = 0',
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
    // print('Note updated: ${note.id}');
  }

  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    // print('Note deleted: ${id}');
  }

  // Optional: Method to close the database if needed, though often not explicitly called in Flutter apps
  Future close() async {
    final db = await database;
    db.close();
  }
}
