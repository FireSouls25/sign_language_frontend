import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/oauth_service.dart';

class OAuthWebViewScreen extends StatefulWidget {
  final OAuthProvider provider;

  const OAuthWebViewScreen({super.key, required this.provider});

  @override
  State<OAuthWebViewScreen> createState() => _OAuthWebViewScreenState();
}

class _OAuthWebViewScreenState extends State<OAuthWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _loadingMessage = 'Loading...';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _loadingMessage = 'Loading...';
            });

            if (url.startsWith('lsc://oauth/callback')) {
              _handleCallback(url);
            }
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _loadingMessage = 'Error: ${error.description}';
            });
          },
        ),
      );

    final loginUrl = OAuthConfig.getLoginUrl(widget.provider);
    _controller.loadRequest(Uri.parse(loginUrl));
  }

  Future<void> _handleCallback(String url) async {
    try {
      final uri = Uri.parse(url);
      final accessToken = uri.queryParameters['access_token'];
      final refreshToken = uri.queryParameters['refresh_token'];
      final error = uri.queryParameters['error'];

      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('OAuth Error: $error')));
          Navigator.of(context).pop();
        }
        return;
      }

      if (accessToken != null) {
        final tokens = OAuthTokens(
          accessToken: accessToken,
          refreshToken: refreshToken ?? '',
        );

        if (mounted) {
          Navigator.of(context).pop(tokens);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OAuth Error: No tokens received')),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('OAuth Error: $e')));
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.provider == OAuthProvider.google
              ? 'Login with Google'
              : 'Login with Apple',
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _loadingMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<OAuthTokens?> startOAuthWebView(
  BuildContext context,
  OAuthProvider provider,
) {
  return Navigator.of(context).push<OAuthTokens>(
    MaterialPageRoute(
      builder: (context) => OAuthWebViewScreen(provider: provider),
    ),
  );
}
