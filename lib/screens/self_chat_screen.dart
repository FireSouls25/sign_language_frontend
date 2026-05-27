import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../l10n/app_translations.dart';
import '../widgets/ls_app_bar.dart';
import 'chat_detail_screen.dart';

class SelfChatScreen extends StatefulWidget {
  const SelfChatScreen({super.key});

  @override
  State<SelfChatScreen> createState() => _SelfChatScreenState();
}

class _SelfChatScreenState extends State<SelfChatScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSelfChat());
  }

  Future<void> _ensureSelfChat() async {
    final chatProvider = context.read<ChatProvider>();
    final myId = chatProvider.myId?['id'] as String?;
    if (myId == null) {
      await chatProvider.loadMyId();
    }
    final id = chatProvider.myId?['id'] as String?;
    if (id != null) {
      await chatProvider.ensureSelfChat();
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = (String key) => AppTranslations.text(context, key);

    if (_loading) {
      return Scaffold(
        appBar: LSAppBar(
          title: l('selfChat'),
          showLanguageSelector: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final chatProvider = context.watch<ChatProvider>();
    final selfConv = chatProvider.selfConversation;

    if (selfConv == null) {
      return Scaffold(
        appBar: LSAppBar(
          title: l('selfChat'),
          showLanguageSelector: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 16),
              Text(l('errorLoadingData')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _ensureSelfChat,
                child: Text(l('retry')),
              ),
            ],
          ),
        ),
      );
    }

    return ChatDetailScreen(
      conversation: selfConv,
      isSelfChat: true,
    );
  }
}
