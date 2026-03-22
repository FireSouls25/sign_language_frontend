import 'package:flutter/foundation.dart';

enum Environment { development, production }

class ApiConfig {
  static Environment get _environment =>
      kDebugMode ? Environment.development : Environment.production;

  static Environment get currentEnvironment => _environment;

  static String get baseUrl {
    switch (_environment) {
      case Environment.development:
        return 'http://10.0.2.2:8000';
      case Environment.production:
        return 'https://sign-language-backend-vqq1.onrender.com';
    }
  }

  static String get wsUrl {
    final base = _environment == Environment.development
        ? 'ws://10.0.2.2:8000'
        : 'wss://sign-language-backend-vqq1.onrender.com';
    return '$base/ws/translate';
  }

  static String buildWsUrlWithToken(String token) {
    return '$wsUrl?token=$token';
  }

  static String getOAuthRedirectUrl(String provider) {
    if (_environment == Environment.development) {
      return '$baseUrl/api/auth/callback-dev/$provider';
    }
    return '$baseUrl/api/auth/callback/$provider';
  }

  static String get callbackScheme => 'lsc';

  static bool get isDevelopment => _environment == Environment.development;
  static bool get isProduction => _environment == Environment.production;

  static String get environmentName {
    switch (_environment) {
      case Environment.development:
        return 'Desarrollo';
      case Environment.production:
        return 'Producción';
    }
  }
}
