import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/oauth_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  User? _user;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;
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
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _isVoiceEnabled = prefs.getBool('is_voice_enabled') ?? true;

    if (_accessToken != null) {
      _apiService.setToken(_accessToken!);
      await fetchCurrentUser();
    }
    notifyListeners();
  }

  Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) {
      await prefs.setString('access_token', _accessToken!);
    }
    if (_refreshToken != null) {
      await prefs.setString('refresh_token', _refreshToken!);
    }
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
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
      await logout();
    }
  }

  Future<void> logout() async {
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
