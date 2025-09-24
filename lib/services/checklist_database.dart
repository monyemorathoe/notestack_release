import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/checklist_item.dart';

class ChecklistDatabase {
  static Database? _db;
  static const int _databaseVersion = 2;
  static const String _tableName = 'checklist_items';

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'checklist.db'),
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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
      // Migration path for removing scheduledDateTime and reminderEnabled
      // Create a temporary table with the new schema
      await db.execute('''
        CREATE TABLE ${_tableName}_temp (
          id INTEGER PRIMARY KEY,
          title TEXT,
          isDone INTEGER
        )
      ''');

      // Copy data from the old table to the temporary table
      // Make sure to only select columns that exist in the old table and are needed in the new one.
      // This assumes the old table (version 1) had id, title, isDone, scheduledDateTime, reminderEnabled
      try {
        final oldData = await db.query(_tableName); // Query old table
        for (var row in oldData) {
          await db.insert('${_tableName}_temp', {
            'id': row['id'],
            'title': row['title'],
            'isDone': row['isDone'],
          });
        }
        // Drop the old table
        await db.execute('DROP TABLE $_tableName');
        // Rename the temporary table to the original table name
        await db.execute('ALTER TABLE ${_tableName}_temp RENAME TO $_tableName');

      } catch (e) {
        // If the old table didn't exist or an error occurs, 
        // it might be a fresh install or a different state.
        // Fallback to just creating the new table if it doesn't exist.
        await db.execute('DROP TABLE IF EXISTS ${_tableName}_temp'); // clean up temp if it exists
        await db.execute('DROP TABLE IF EXISTS $_tableName'); // drop original if exists
        await _onCreate(db, newVersion); // create with new schema
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
