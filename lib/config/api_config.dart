import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum Environment { development, staging, production }

class ApiConfig {
  static Environment _currentEnvironment = Environment.development;
  static Environment get currentEnvironment => _currentEnvironment;

  static String get baseUrl => dotenv.env['API_URL'] ?? 'http://localhost:8000';
  static String get wsUrl =>
      dotenv.env['WS_URL'] ?? 'ws://localhost:8000/ws/translate';

  static String get wsUrlWithToken {
    final tokenParam = 'token';
    return '$wsUrl?$tokenParam=';
  }

  static String buildWsUrlWithToken(String token) {
    return '$wsUrl?token=$token';
  }

  static String getOAuthRedirectUrl(String provider) {
    final base = dotenv.env['API_URL'] ?? 'http://localhost:8000';
    if (_currentEnvironment == Environment.development) {
      return '$base/api/auth/callback-dev/$provider';
    }
    return '$base/api/auth/callback/$provider';
  }

  static String get callbackScheme => 'lsc';

  static void setEnvironment(Environment env) {
    _currentEnvironment = env;
  }

  static Future<void> initialize() async {
    await dotenv.load(fileName: _envFileName);
    final envName = dotenv.env['ENVIRONMENT'] ?? 'development';
    switch (envName.toLowerCase()) {
      case 'staging':
        _currentEnvironment = Environment.staging;
        break;
      case 'production':
        _currentEnvironment = Environment.production;
        break;
      default:
        _currentEnvironment = Environment.development;
    }
  }

  static String get _envFileName {
    if (kDebugMode) return '.env.development';
    if (dotenv.env['ENVIRONMENT'] == 'staging') return '.env.staging';
    return '.env.production';
  }

  static bool get isDevelopment =>
      _currentEnvironment == Environment.development;
  static bool get isStaging => _currentEnvironment == Environment.staging;
  static bool get isProduction => _currentEnvironment == Environment.production;

  static String get environmentName {
    switch (_currentEnvironment) {
      case Environment.development:
        return 'Desarrollo';
      case Environment.staging:
        return 'Staging';
      case Environment.production:
        return 'Producción';
    }
  }
}
