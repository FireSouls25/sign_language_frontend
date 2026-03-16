class ApiConfig {
  static const String development = 'http://localhost:8000';
  static const String staging = 'https://staging-api.lsc-translator.com';
  static const String production = 'https://api.lsc-translator.com';

  static String baseUrl = development;
  static String wsUrl = 'ws://localhost:8000/ws/translate';

  static String getOAuthRedirectUrl(String provider) {
    return '$baseUrl/api/auth/callback-dev/$provider';
  }
}
