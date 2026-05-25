import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../l10n/app_translations.dart';
import '../models/chat.dart';

class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key});

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadContacts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = (String key) => AppTranslations.text(context, key);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_showSearch ? l('searchUsers') : l('contacts')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  context.read<ChatProvider>().searchUsers('');
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l('searchByUsername'),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (query) {
                  context.read<ChatProvider>().searchUsers(query);
                },
              ),
            ),
          if (_showSearch)
            Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                if (chatProvider.isSearching) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  );
                }

                final results = chatProvider.searchResults;
                if (results.isEmpty && _searchController.text.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l('noUsersFound'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return Expanded(
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final user = results[index];
                      return _UserSearchTile(
                        user: user,
                        onTap: () async {
                          final myId = chatProvider.myId?['id'] as String?;

                          if (myId == user.id) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l('cannotChatWithSelf'))),
                            );
                            return;
                          }

                          final conv = await chatProvider.createConversation(
                            user.id,
                          );
                          if (conv != null && mounted) {
                            Navigator.of(context).pop();
                            Navigator.of(context).pushNamed(
                              '/chat',
                              arguments: conv,
                            );
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          if (!_showSearch)
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, chatProvider, _) {
                  if (chatProvider.isLoadingContacts) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (chatProvider.contacts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 80,
                            color: theme.colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            l('noContacts'),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _showSearch = true);
                            },
                            icon: const Icon(Icons.search),
                            label: Text(l('searchUsers')),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => chatProvider.loadContacts(),
                    child: ListView.builder(
                      itemCount: chatProvider.contacts.length,
                      itemBuilder: (context, index) {
                        final contact = chatProvider.contacts[index];
                        return _ContactTile(
                          contact: contact,
                          onRemove: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(l('removeContact')),
                                content: Text(
                                  '${l('removeContactConfirm')} ${contact.effectiveName}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: Text(l('cancel')),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: Text(l('remove')),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              chatProvider.removeContact(contact.id);
                            }
                          },
                          onChat: () async {
                            final conv = await chatProvider.createConversation(
                              contact.contact.id,
                            );
                            if (conv != null && mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _UserSearchTile extends StatelessWidget {
  final UserBrief user;
  final VoidCallback onTap;

  const _UserSearchTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial =
        (user.displayName.isNotEmpty ? user.displayName[0] : user.username[0])
            .toUpperCase();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Text(
          initial,
          style: TextStyle(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(user.displayName),
      subtitle: Text('@${user.username}'),
      trailing: IconButton(
        icon: const Icon(Icons.chat_outlined),
        onPressed: onTap,
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final ContactModel contact;
  final VoidCallback onRemove;
  final VoidCallback onChat;

  const _ContactTile({
    required this.contact,
    required this.onRemove,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = contact.effectiveName;
    final initial = (name.isNotEmpty ? name[0] : '?').toUpperCase();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          initial,
          style: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(name),
      subtitle: Text('@${contact.contact.username}'),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'chat':
              onChat();
              break;
            case 'remove':
              onRemove();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'chat',
            child: ListTile(
              leading: Icon(Icons.chat_outlined),
              title: Text('Chat'),
            ),
          ),
          const PopupMenuItem(
            value: 'remove',
            child: ListTile(
              leading: Icon(Icons.person_remove_outlined),
              title: Text('Remove'),
            ),
          ),
        ],
      ),
      onTap: onChat,
    );
  }
}
