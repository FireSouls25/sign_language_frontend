import 'package:flutter_appauth/flutter_appauth.dart';
import '../config/api_config.dart';

const String _clientId =
    '908648917103-g1q1qh4f8bln3fukvd3h335a1g1bieak.apps.googleusercontent.com';
const String _discoveryUrl =
    'https://accounts.google.com/.well-known/openid-configuration';

class GoogleAuthService {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  String get _redirectUrl =>
      '${ApiConfig.baseUrl}/api/auth/oauth/callback-page';

  Future<GoogleSignInResult> signIn() async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUrl,
          discoveryUrl: _discoveryUrl,
          scopes: ['email', 'profile', 'openid'],
        ),
      );

      if (result == null) {
        return GoogleSignInResult(success: false, error: 'sign_in_cancelled');
      }

      return GoogleSignInResult(
        success: true,
        idToken: result.idToken,
        accessToken: result.accessToken,
      );
    } catch (e) {
      final error = e.toString();
      if (error.contains('cancel') || error.contains('dismiss')) {
        return GoogleSignInResult(success: false, error: 'sign_in_cancelled');
      }
      return GoogleSignInResult(success: false, error: error);
    }
  }
}

class GoogleSignInResult {
  final bool success;
  final String? idToken;
  final String? accessToken;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? error;

  GoogleSignInResult({
    required this.success,
    this.idToken,
    this.accessToken,
    this.email,
    this.displayName,
    this.photoUrl,
    this.error,
  });
}
