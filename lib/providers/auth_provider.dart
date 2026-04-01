import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/oauth_service.dart';
import '../services/secure_storage_service.dart';
import '../services/error_translator.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SecureStorageService _secureStorage = SecureStorageService();

  User? _user;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isRefreshing = false;
  String? _error;
  bool _isVoiceEnabled = true;

  User? get user => _user;
  bool get isAuthenticated => _accessToken != null;
  bool get isLoading => _isLoading && !_isInitialized;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  String? get accessToken => _accessToken;
  bool get isVoiceEnabled => _isVoiceEnabled;

  Future<bool> handleOAuthCallback(OAuthTokens tokens) async {
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    _apiService.setToken(_accessToken!);

    await _saveTokens();
    await fetchCurrentUser();

    return _user != null;
  }

  Future<bool> loginWithGoogleToken(String googleIdToken) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tokens = await _apiService.exchangeGoogleToken(googleIdToken);

      _accessToken = tokens.accessToken;
      _refreshToken = tokens.refreshToken;
      _apiService.setToken(_accessToken!);

      await _saveTokens();
      await fetchCurrentUser();

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      ErrorTranslator.translate(e);
      _error = 'Error de conexión con Google.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  AuthProvider() {
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    try {
      _accessToken = await _secureStorage.getAccessToken();
      _refreshToken = await _secureStorage.getRefreshToken();

      final prefs = await SharedPreferences.getInstance();
      _isVoiceEnabled = prefs.getBool('is_voice_enabled') ?? true;

      if (_accessToken != null) {
        _apiService.setToken(_accessToken!);
        await fetchCurrentUser();
      }
    } catch (e) {
      ErrorTranslator.translate(e);
      _error = 'No se pudo conectar al servidor';
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
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
      ErrorTranslator.translate(e);
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
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } on SocketException {
      _error = 'No hay conexión a internet. Verifica tu red.';
      _isLoading = false;
      notifyListeners();
      return false;
    } on TimeoutException {
      _error = 'El servidor no responde. Intenta más tarde.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      ErrorTranslator.translate(e);
      _error = 'Error de conexión. Verifica tu internet.';
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
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } on SocketException {
      _error = 'No hay conexión a internet. Verifica tu red.';
      _isLoading = false;
      notifyListeners();
      return false;
    } on TimeoutException {
      _error = 'El servidor no responde. Intenta más tarde.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      ErrorTranslator.translate(e);
      _error = 'Error de conexión. Verifica tu internet.';
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
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } on SocketException {
      _error = 'No hay conexión a internet. Verifica tu red.';
      _isLoading = false;
      notifyListeners();
      return false;
    } on TimeoutException {
      _error = 'El servidor no responde. Intenta más tarde.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      ErrorTranslator.translate(e);
      _error = 'Error de conexión. Verifica tu internet.';
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
      ErrorTranslator.translate(e);
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
    try {
      await _apiService.logout();
    } catch (_) {}

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

  Future<(bool, String?)> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _isLoading = false;
      notifyListeners();
      return (true, null);
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return (false, _error);
    } on SocketException {
      _error = 'No hay conexión a internet.';
      _isLoading = false;
      notifyListeners();
      return (false, _error);
    } catch (e) {
      ErrorTranslator.translate(e);
      _error = 'Error de conexión.';
      _isLoading = false;
      notifyListeners();
      return (false, _error);
    }
  }

  Future<void> retryConnection() async {
    _isInitialized = false;
    _error = null;
    notifyListeners();
    await _loadTokens();
  }
}
