import 'dart:io'; // <<< ADD THIS IMPORT
import 'package:path_provider/path_provider.dart'; // <<< ADD THIS IMPORT
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // <<< ADD THIS IMPORT
// <<< MODIFIED IMPORT
import 'package:path/path.dart';
import '../models/checklist_item.dart';

class ChecklistDatabase {
  static Database? _db;
  static const int _databaseVersion = 2;
  static const String _tableName = 'checklist_items';
  static const String _databaseName = 'checklist.db'; // <<< ADDED DB NAME

  // Define a subfolder name for your app's data to keep things organized
  static const String _appNameForPath = "NoteStack"; // <<< ADDED APP NAME FOR PATH

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    // Ensure FFI is initialized (typically done once in main.dart for desktop)
    // sqfliteFfiInit();

    Directory appSupportDir = await getApplicationSupportDirectory();
    String dbPath = join(appSupportDir.path, _appNameForPath, _databaseName);

    // For sqflite_common_ffi, the directory is created automatically if it doesn't exist
    // during openDatabase.

    var dbFactory = databaseFactoryFfi; // Use FFI factory for desktop

    return await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions( // <<< Use OpenDatabaseOptions for FFI
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY,
        title TEXT,
        isDone INTEGER
      )
    ''');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE ${_tableName}_temp (
          id INTEGER PRIMARY KEY,
          title TEXT,
          isDone INTEGER
        )
      ''');
      try {
        final oldData = await db.query(_tableName);
        for (var row in oldData) {
          await db.insert('${_tableName}_temp', {
            'id': row['id'],
            'title': row['title'],
            'isDone': row['isDone'],
          });
        }
        await db.execute('DROP TABLE $_tableName');
        await db.execute('ALTER TABLE ${_tableName}_temp RENAME TO $_tableName');
      } catch (e) {
        await db.execute('DROP TABLE IF EXISTS ${_tableName}_temp');
        await db.execute('DROP TABLE IF EXISTS $_tableName');
        await _onCreate(db, newVersion);
      }
    }
  }

  static Future<List<ChecklistItem>> getItems() async {
    final db = await database;
    final maps = await db.query(_tableName);
    return maps.map((map) => ChecklistItem(
      id: map['id'] as int,
      title: map['title'] as String,
      isDone: (map['isDone'] as int) == 1,
    )).toList();
  }

  static Future<void> insertItem(ChecklistItem item) async {
    final db = await database;
    await db.insert(_tableName, {
      'id': item.id,
      'title': item.title,
      'isDone': item.isDone ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateItem(ChecklistItem item) async {
    final db = await database;
    await db.update(_tableName, {
      'title': item.title,
      'isDone': item.isDone ? 1 : 0,
    }, where: 'id = ?', whereArgs: [item.id]);
  }

  static Future<void> deleteItem(int id) async {
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
}
