import 'package:flutter_appauth/flutter_appauth.dart';

const String _clientId =
    '908648917103-qhfpi7jnnou8mp2hnhig1r66gr31p4oc.apps.googleusercontent.com';
const String _redirectUrl =
    'com.googleusercontent.apps.908648917103-qhfpi7jnnou8mp2hnhig1r66gr31p4oc:/oauth2redirect';
const String _discoveryUrl =
    'https://accounts.google.com/.well-known/openid-configuration';

class GoogleAuthService {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

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
