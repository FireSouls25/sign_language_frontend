import 'dart:async';
import 'oauth_service.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _deeplinkController = StreamController<OAuthTokens>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<OAuthTokens> get onOAuthCallback => _deeplinkController.stream;
  Stream<String> get onOAuthError => _errorController.stream;

  void handleUri(Uri uri) {
    if (uri.scheme == 'lsc' && uri.host == 'oauth' && uri.path == '/callback') {
      final error = uri.queryParameters['error'];
      if (error != null) {
        _errorController.add(error);
        return;
      }

      final accessToken = uri.queryParameters['access_token'];
      final refreshToken = uri.queryParameters['refresh_token'];
      final tokenType = uri.queryParameters['token_type'] ?? 'bearer';

      if (accessToken != null && refreshToken != null) {
        _deeplinkController.add(
          OAuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
          ),
        );
      }
    }
  }

  void dispose() {
    _deeplinkController.close();
    _errorController.close();
  }
}
