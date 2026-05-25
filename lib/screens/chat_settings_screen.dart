import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../l10n/app_translations.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l = (String key) => AppTranslations.text(context, key);

    return Scaffold(
      appBar: AppBar(
        title: Text(l('chatSettings')),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Consumer<ChatProvider>(
          builder: (context, chatProvider, _) {
            final fontSize = chatProvider.fontSize;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.text_fields),
                  title: Text(l('fontSize')),
                  subtitle: Text(l('fontSizeDesc')),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: fontSize,
                  min: 12.0,
                  max: 24.0,
                  divisions: 12,
                  label: '${fontSize.round()}',
                  onChanged: (value) {
                    chatProvider.setFontSize(value);
                  },
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '${fontSize.round()} pt',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
