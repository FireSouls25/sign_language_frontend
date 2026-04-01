import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/log.dart';
import '../models/translation.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'app_data.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            message TEXT,
            technical_details TEXT,
            timestamp TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE offline_translations(
            id TEXT PRIMARY KEY,
            user_id TEXT,
            text_result TEXT,
            audio_url TEXT,
            confidence_score REAL,
            created_at TEXT,
            is_favorite INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE offline_translations ADD COLUMN is_favorite INTEGER DEFAULT 0',
          );
        }
      },
    );
  }

  // Logs (Errores Técnicos)
  Future<void> insertLog(Log log) async {
    final db = await database;
    await db.insert('logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Log>> getLogs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('logs', orderBy: 'timestamp DESC');
    return List.generate(maps.length, (i) => Log.fromMap(maps[i]));
  }

  Future<void> clearLogs() async {
    final db = await database;
    await db.delete('logs');
  }

  // Traducciones (Modo Offline)
  Future<void> saveTranslations(List<Translation> translations) async {
    final db = await database;
    final batch = db.batch();
    for (var t in translations) {
      // Usamos ON CONFLICT para actualizar los datos del servidor sin perder el favorito local
      batch.execute('''
        INSERT INTO offline_translations (id, user_id, text_result, audio_url, confidence_score, created_at, is_favorite)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          user_id = excluded.user_id,
          text_result = excluded.text_result,
          audio_url = excluded.audio_url,
          confidence_score = excluded.confidence_score,
          created_at = excluded.created_at
      ''', [
        t.id,
        t.userId,
        t.textResult,
        t.audioUrl,
        t.confidenceScore,
        t.createdAt.toIso8601String(),
        t.isFavorite ? 1 : 0,
      ]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> toggleFavorite(String id, bool isFavorite) async {
    final db = await database;
    await db.update(
      'offline_translations',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Translation>> getFavorites(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'offline_translations',
      where: 'user_id = ? AND is_favorite = 1',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Translation.fromJson(maps[i]));
  }

  Future<List<Translation>> getOfflineTranslations(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'offline_translations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC'
    );
    return List.generate(maps.length, (i) => Translation.fromJson(maps[i]));
  }
}
