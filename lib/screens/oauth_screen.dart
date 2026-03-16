import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/oauth_service.dart';

class OAuthScreen extends StatefulWidget {
  final OAuthProvider provider;

  const OAuthScreen({super.key, required this.provider});

  @override
  State<OAuthScreen> createState() => _OAuthScreenState();
}

class _OAuthScreenState extends State<OAuthScreen> {
  bool _isLoading = true;
  String _statusMessage = 'Opening browser...';

  @override
  void initState() {
    super.initState();
    _startOAuthFlow();
  }

  Future<void> _startOAuthFlow() async {
    try {
      final loginUrl = OAuthConfig.getLoginUrl(widget.provider);
      final uri = Uri.parse(loginUrl);

      setState(() {
        _isLoading = false;
        _statusMessage =
            'Browser opening...\n\n'
            'After logging in, you will be redirected back to the app.\n\n'
            'If the browser doesn\'t open automatically, '
            'click the button below.';
      });

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Cannot open browser')));
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const CircularProgressIndicator()
              else ...[
                const Icon(Icons.login, size: 64, color: Colors.deepPurple),
                const SizedBox(height: 24),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _startOAuthFlow,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Open Browser'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<OAuthTokens?> startOAuthFlow(
  BuildContext context,
  OAuthProvider provider,
) {
  return Navigator.of(context).push<OAuthTokens>(
    MaterialPageRoute(builder: (context) => OAuthScreen(provider: provider)),
  );
}
