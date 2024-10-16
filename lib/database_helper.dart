import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'user_database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE users(id TEXT PRIMARY KEY, password TEXT, name TEXT)',
        );
      },
    );
  }

  Future<void> insertUser(String id, String password, String name) async {
    final db = await database;
  await db.insert(
      'users',
      {'id': id, 'password': password ,'name':name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
