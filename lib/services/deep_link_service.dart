import 'dart:async';
import 'package:flutter/material.dart';
import '../services/oauth_service.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _deeplinkController = StreamController<OAuthTokens>.broadcast();

  Stream<OAuthTokens> get onOAuthCallback => _deeplinkController.stream;

  bool handleUri(Uri uri) {
    if (uri.scheme == 'lsc' && uri.host == 'oauth') {
      if (uri.path == '/callback') {
        final accessToken = uri.queryParameters['access_token'];
        final refreshToken = uri.queryParameters['refresh_token'];
        final tokenType = uri.queryParameters['token_type'] ?? 'bearer';

        if (accessToken != null && refreshToken != null) {
          final tokens = OAuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
          );
          _deeplinkController.add(tokens);
          return true;
        }
      }
    }
    return false;
  }

  void dispose() {
    _deeplinkController.close();
  }
}

class DeepLinkWrapper extends StatefulWidget {
  final Widget child;

  const DeepLinkWrapper({super.key, required this.child});

  @override
  State<DeepLinkWrapper> createState() => _DeepLinkWrapperState();
}

class _DeepLinkWrapperState extends State<DeepLinkWrapper> {
  final DeepLinkService _deeplinkService = DeepLinkService();

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
