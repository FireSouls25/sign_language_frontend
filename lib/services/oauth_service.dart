import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';

enum OAuthProvider { google, apple }

class OAuthTokens {
  final String accessToken;
  final String refreshToken;
  final String tokenType;

  OAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
  });

  factory OAuthTokens.fromJson(Map<String, dynamic> json) {
    return OAuthTokens(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      tokenType: json['token_type'] ?? 'bearer',
    );
  }
}

class OAuthConfig {
  static String getLoginUrl(OAuthProvider provider) {
    switch (provider) {
      case OAuthProvider.google:
        return '${ApiConfig.baseUrl}/api/auth/login/google';
      case OAuthProvider.apple:
        return '${ApiConfig.baseUrl}/api/auth/login/apple';
    }
  }

  static String getRedirectUri() {
    return '${ApiConfig.baseUrl}/api/auth/callback/google';
  }
}

class OAuthService {
  bool get isDesktop {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  bool get isMobile {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<OAuthTokens?> startOAuthFlow(OAuthProvider provider) async {
    final loginUrl = OAuthConfig.getLoginUrl(provider);

    final uri = Uri.parse(loginUrl);
    if (!await canLaunchUrl(uri)) {
      throw Exception('Cannot launch OAuth URL');
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);

    return null;
  }

  Future<OAuthTokens> exchangeCodeForTokens(
    String url,
    OAuthProvider provider,
  ) async {
    Uri uri = Uri.parse(url);
    String? code = uri.queryParameters['code'];
    String? error = uri.queryParameters['error'];

    if (error != null) {
      throw Exception('OAuth error: $error');
    }

    if (code == null) {
      throw Exception('No authorization code received');
    }

    final callbackUrl = OAuthConfig.getRedirectUri();

    try {
      final response = await http.get(
        Uri.parse('$callbackUrl?code=$code'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return OAuthTokens.fromJson(data);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['detail'] ?? 'OAuth token exchange failed');
      }
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        throw Exception(
          'Cannot connect to server. Make sure the backend is running.',
        );
      }
      rethrow;
    }
  }

  void dispose() {}
}
