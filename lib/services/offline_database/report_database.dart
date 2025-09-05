// lib/helpers/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'issues.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE issues(
        id INTEGER PRIMARY KEY,
        description TEXT,
        location TEXT,
        dateTime TEXT
      )
    ''');
  }

  Future<void> insertIssue(String description, String location) async {
    final db = await database;
    try {
      await db.insert(
        'issues',
        {'description': description, 'location': location},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Insert Error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getIssues() async {
    final db = await database;
    return await db.query('issues');
  }

  Future<int> deleteIssue(int id) async {
    final db = await database;
    return await db.delete('issues', where: 'id = ?', whereArgs: [id]);
  }
}
