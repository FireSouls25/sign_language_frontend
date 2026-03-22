import '../models/translation.dart';
import 'api_service.dart';
import 'database_service.dart';

class TranslationRepository {
  final DatabaseService _dbService;
  final ApiService _apiService;

  TranslationRepository({DatabaseService? dbService, ApiService? apiService})
    : _dbService = dbService ?? DatabaseService(),
      _apiService = apiService ?? ApiService();

  void setToken(String token) {
    _apiService.setToken(token);
  }

  Future<List<Translation>> getTranslations({
    int limit = 50,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final localData = await _dbService.getTranslations(
        limit: limit,
        offset: offset,
      );
      if (localData.isNotEmpty) {
        return localData.map((map) => Translation.fromMap(map)).toList();
      }
    }

    try {
      final remoteData = await _apiService.getTranslationHistory(
        limit: limit,
        offset: offset,
      );

      for (final translation in remoteData) {
        await _dbService.insertTranslation(translation.toMap());
      }

      return remoteData;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        final localData = await _dbService.getTranslations(
          limit: limit,
          offset: offset,
        );
        if (localData.isNotEmpty) {
          return localData.map((map) => Translation.fromMap(map)).toList();
        }
      }
      rethrow;
    }
  }

  Future<void> saveTranslation(Translation translation) async {
    await _dbService.insertTranslation(translation.toMap());
  }

  Future<void> deleteTranslation(String id) async {
    await _dbService.deleteTranslation(id);
  }

  Future<void> clearAll() async {
    await _dbService.deleteAllTranslations();
  }

  Future<int> getLocalCount() async {
    return await _dbService.getTranslationCount();
  }

  Future<List<Translation>> searchTranslations(String query) async {
    final localData = await _dbService.searchTranslations(query);
    return localData.map((map) => Translation.fromMap(map)).toList();
  }

  Future<void> syncFromServer({int limit = 100}) async {
    try {
      final remoteData = await _apiService.getTranslationHistory(
        limit: limit,
        offset: 0,
      );

      for (final translation in remoteData) {
        await _dbService.insertTranslation(translation.toMap());
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        return;
      }
      rethrow;
    }
  }
}
