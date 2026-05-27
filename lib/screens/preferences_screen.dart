import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/translation_mode_provider.dart';
import '../l10n/app_translations.dart';
import '../config/theme_config.dart';
import '../widgets/ls_app_bar.dart';
import 'logs_screen.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  @override
  Widget build(BuildContext context) {
    final l = (String key) => AppTranslations.text(context, key);

    return Scaffold(
      appBar: LSAppBar(
        title: l('preferences'),
        showLanguageSelector: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SwitchListTile(
            title: Text(l('voiceOutput')),
            subtitle: Text(l('voiceOutputDesc')),
            value: context.watch<AuthProvider>().isVoiceEnabled,
            activeTrackColor: Theme.of(context).colorScheme.primary,
            onChanged: (bool value) {
              context.read<AuthProvider>().toggleVoice(value);
            },
            secondary: const Icon(Icons.volume_up),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Icons.camera_alt,
              color: AppTheme.getIconPrimary(context),
            ),
            title: Text(l('inputMode')),
            subtitle: Text(
              context.watch<TranslationModeProvider>().isFrameMode
                  ? l('sendFrames')
                  : l('sendLandmarks'),
            ),
            trailing: Switch(
              value: context.watch<TranslationModeProvider>().isFrameMode,
              activeTrackColor: Theme.of(context).colorScheme.primary,
              onChanged: (bool value) {
                context.read<TranslationModeProvider>().setInputMode(
                  value
                      ? TranslationInputMode.frames
                      : TranslationInputMode.landmarks,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Icons.bug_report,
              color: AppTheme.getIconPrimary(context),
            ),
            title: Text(l('systemLogs')),
            subtitle: Text(l('systemLogsDesc')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
