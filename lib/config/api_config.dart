import 'package:flutter/foundation.dart';
import '../main.dart' show EnvVars;

enum Environment { development, production }

class ApiConfig {
  static Environment get _environment =>
      kDebugMode ? Environment.development : Environment.production;

  static Environment get currentEnvironment => _environment;

  static String get baseUrl {
    return EnvVars.backendUrl;
  }

  static String get wsUrl {
    final base = EnvVars.backendWsUrl;
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
