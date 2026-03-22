import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '908648917103-g1q1qh4f8bln3fukvd3h335a1g1bieak.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  Future<GoogleSignInResult> signIn() async {
    try {
      final account = await _googleSignIn.signIn();

      if (account == null) {
        return GoogleSignInResult(success: false, error: 'Sign in cancelled');
      }

      final auth = await account.authentication;

      return GoogleSignInResult(
        success: true,
        idToken: auth.idToken,
        accessToken: auth.accessToken,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      );
    } catch (e) {
      return GoogleSignInResult(success: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  bool get isSignedIn => _googleSignIn.currentUser != null;
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
