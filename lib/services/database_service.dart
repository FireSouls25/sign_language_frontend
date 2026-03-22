import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'lsc_translator.db';
  static const int _dbVersion = 1;

  static const String tableTranslations = 'translations';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableTranslations (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        text_result TEXT NOT NULL,
        audio_url TEXT,
        confidence_score REAL NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_translations_created_at 
      ON $tableTranslations (created_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_translations_user_id 
      ON $tableTranslations (user_id)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}

  Future<int> insertTranslation(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      tableTranslations,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getTranslations({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    return await db.query(
      tableTranslations,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<int> deleteTranslation(String id) async {
    final db = await database;
    return await db.delete(tableTranslations, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllTranslations() async {
    final db = await database;
    return await db.delete(tableTranslations);
  }

  Future<int> getTranslationCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableTranslations',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> searchTranslations(String query) async {
    final db = await database;
    return await db.query(
      tableTranslations,
      where: 'text_result LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
