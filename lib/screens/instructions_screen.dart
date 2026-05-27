import 'package:flutter/material.dart';
import '../widgets/ls_app_bar.dart';
import '../l10n/app_translations.dart';
import '../config/theme_config.dart';

class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = (String key) => AppTranslations.text(context, key);
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: LSAppBar(
        title: l('instructionsTitle'),
        showThemeToggle: false,
        showHelp: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildInstructionSection(
            context,
            l('addContactsTitle'),
            l('addContactsContent'),
            Icons.person_add_outlined,
          ),
          const SizedBox(height: 16),
          _buildInstructionSection(
            context,
            l('profileOptionsTitle'),
            l('profileOptionsContent'),
            Icons.account_circle_outlined,
          ),
          const SizedBox(height: 16),
          _buildInstructionSection(
            context,
            l('videoCallsTitle'),
            l('videoCallsContent'),
            Icons.video_call_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionSection(
    BuildContext context,
    String title,
    String content,
    IconData icon,
  ) {
    return Card(
      color: AppTheme.getCardColor(context),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              content,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
