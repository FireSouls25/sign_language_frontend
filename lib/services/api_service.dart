import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user.dart';
import '../models/translation.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  ApiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => message;
}

class ApiService {
  static const _timeout = Duration(seconds: 30);

  String? _accessToken;

  void setToken(String token) {
    _accessToken = token;
  }

  void clearToken() {
    _accessToken = null;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<User> register({
    required String email,
    required String username,
    required String password,
    required String fullName,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'username': username,
            'password': password,
            'full_name': fullName,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 201) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      String detail;
      try {
        final error = jsonDecode(response.body);
        detail = error['detail'] ?? 'Registration failed';
      } catch (_) {
        detail = response.body.isNotEmpty
            ? response.body
            : 'Registration failed (HTTP ${response.statusCode})';
      }
      throw ApiException(detail, statusCode: response.statusCode);
    }
  }

  Future<AuthTokens> login({
    required String username,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return AuthTokens.fromJson(jsonDecode(response.body));
    } else {
      String detail;
      try {
        final error = jsonDecode(response.body);
        detail = error['detail'] ?? 'Login failed';
      } catch (_) {
        detail = response.body.isNotEmpty
            ? response.body
            : 'Login failed (HTTP ${response.statusCode})';
      }
      throw ApiException(detail, statusCode: response.statusCode);
    }
  }

  Future<User> getCurrentUser() async {
    final response = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/api/auth/me'), headers: _headers)
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException('Failed to get user', statusCode: response.statusCode);
    }
  }

  Future<AuthTokens> refreshTokens(String refreshToken) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return AuthTokens.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException(
        'Failed to refresh tokens',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> logout() async {
    try {
      await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/logout'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/me/change-password'),
          headers: _headers,
          body: jsonEncode({
            'current_password': currentPassword,
            'new_password': newPassword,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw ApiException(
        error['detail'] ?? 'Failed to change password',
        statusCode: response.statusCode,
      );
    }
  }

  Future<AuthTokens> exchangeGoogleToken(String idToken) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/google-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id_token': idToken}),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return AuthTokens.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw ApiException(
        error['detail'] ?? 'Google authentication failed',
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<Translation>> getTranslationHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/translation?size=$limit&page=${(offset ~/ limit) + 1}',
          ),
          headers: _headers,
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> items = data['items'] ?? [];
      return items.map((json) => Translation.fromJson(json)).toList();
    } else {
      throw ApiException(
        'Failed to get translation history',
        statusCode: response.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> healthCheck() async {
    final response = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/health'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw ApiException(
        'Health check failed',
        statusCode: response.statusCode,
      );
    }
  }
}
