import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../l10n/app_translations.dart';
import 'chat_list_screen.dart';
import 'self_chat_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const ChatListScreen(),
      const SelfChatScreen(),
      const ProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final chatProvider = context.read<ChatProvider>();
    chatProvider.loadMyId();
    chatProvider.loadConversations();
    chatProvider.loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    final l = (String key) => AppTranslations.text(context, key);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Badge(
              isLabelVisible: false,
              child: Icon(Icons.chat_outlined),
            ),
            selectedIcon: const Icon(Icons.chat),
            label: l('chats'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.translate_outlined),
            selectedIcon: const Icon(Icons.translate),
            label: l('translate'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l('profile'),
          ),
        ],
      ),
    );
  }
}
