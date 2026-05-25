import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../l10n/app_translations.dart';
import '../models/chat.dart';

class ContactDetailScreen extends StatefulWidget {
  final ContactModel contact;

  const ContactDetailScreen({super.key, required this.contact});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final l = (String key) => AppTranslations.text(context, key);
    final theme = Theme.of(context);
    final contact = widget.contact;
    final name = contact.effectiveName;
    final initial = (name.isNotEmpty ? name[0] : '?').toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(l('contactInfo')),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            CircleAvatar(
              radius: 60,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 48,
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '@${contact.contact.username}',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              contact.contact.id,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l('removeContact')),
                      content: Text(
                        '${l('removeContactConfirm')} $name?',
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
                  if (confirmed == true && mounted) {
                    context.read<ChatProvider>().removeContact(contact.id);
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.person_remove_outlined),
                label: Text(l('removeContact')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
