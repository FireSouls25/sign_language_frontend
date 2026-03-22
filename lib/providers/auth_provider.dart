import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/oauth_service.dart';
import '../services/secure_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SecureStorageService _secureStorage = SecureStorageService();

  User? _user;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;
  bool _isVoiceEnabled = true;

  User? get user => _user;
  bool get isAuthenticated => _accessToken != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get accessToken => _accessToken;
  bool get isVoiceEnabled => _isVoiceEnabled;

  AuthProvider() {
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    _accessToken = await _secureStorage.getAccessToken();
    _refreshToken = await _secureStorage.getRefreshToken();

    final prefs = await SharedPreferences.getInstance();
    _isVoiceEnabled = prefs.getBool('is_voice_enabled') ?? true;

    if (_accessToken != null) {
      _apiService.setToken(_accessToken!);
      await fetchCurrentUser();
    }
    notifyListeners();
  }

  Future<void> _saveTokens() async {
    if (_accessToken != null && _refreshToken != null) {
      await _secureStorage.saveTokens(
        accessToken: _accessToken!,
        refreshToken: _refreshToken!,
      );
    }
  }

  Future<void> _updateAccessToken(String token) async {
    _accessToken = token;
    _apiService.setToken(token);
    await _secureStorage.saveAccessToken(token);
  }

  Future<void> _clearTokens() async {
    await _secureStorage.clearTokens();
  }

  Future<bool> _tryRefreshToken() async {
    if (_refreshToken == null || _isRefreshing) return false;

    _isRefreshing = true;
    try {
      final tokens = await _apiService.refreshTokens(_refreshToken!);
      await _updateAccessToken(tokens.accessToken);
      _refreshToken = tokens.refreshToken;
      await _saveTokens();
      _isRefreshing = false;
      return true;
    } catch (e) {
      _isRefreshing = false;
      return false;
    }
  }

  Future<dynamic> authenticatedRequest(
    Future<dynamic> Function(String token) request,
  ) async {
    if (_accessToken == null) {
      throw ApiException('Not authenticated');
    }

    try {
      return await request(_accessToken!);
    } on ApiException catch (e) {
      if (e.statusCode == 401 && _refreshToken != null) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          return await request(_accessToken!);
        }
      }
      rethrow;
    }
  }

  Future<bool> register({
    required String email,
    required String username,
    required String password,
    required String fullName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.register(
        email: email,
        username: username,
        password: password,
        fullName: fullName,
      );

      return await login(username: username, password: password);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tokens = await _apiService.login(
        username: username,
        password: password,
      );

      _accessToken = tokens.accessToken;
      _refreshToken = tokens.refreshToken;
      _apiService.setToken(_accessToken!);

      await _saveTokens();
      await fetchCurrentUser();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithOAuth(OAuthTokens tokens) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _accessToken = tokens.accessToken;
      _refreshToken = tokens.refreshToken;
      _apiService.setToken(_accessToken!);

      await _saveTokens();
      await fetchCurrentUser();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchCurrentUser() async {
    if (_accessToken == null) return;

    try {
      _user = await _apiService.getCurrentUser();
      notifyListeners();
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          await fetchCurrentUser();
          return;
        }
      }
      await logout();
    }
  }

  Future<void> logout() async {
    await _apiService.logout();

    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _apiService.clearToken();
    await _clearTokens();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> toggleVoice(bool enabled) async {
    _isVoiceEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_voice_enabled', enabled);
    notifyListeners();
  }
}
