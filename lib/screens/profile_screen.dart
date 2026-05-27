import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../l10n/app_translations.dart';
import '../config/theme_config.dart';
import '../widgets/ls_app_bar.dart';
import 'login_screen.dart';
import 'visual_settings_screen.dart';
import 'preferences_screen.dart';
import 'chat_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final l = (String key) => AppTranslations.text(context, key);

    return Scaffold(
      appBar: LSAppBar(
        title: l('myProfile'),
        showLanguageSelector: true,
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 40,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.fullName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '@${user.username}',
                    style: TextStyle(color: AppTheme.getTextSecondary(context)),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle(l('personalInfo')),
                  _buildInfoTile(Icons.email, l('email'), user.email),
                  const SizedBox(height: 24),
                  _buildSectionTitle(l('settings')),
                  ListTile(
                    leading: Icon(
                      Icons.palette_outlined,
                      color: AppTheme.getIconPrimary(context),
                    ),
                    title: Text(l('visualSettings')),
                    subtitle: Text(l('visualSettingsDesc')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VisualSettingsScreen(),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.tune,
                      color: AppTheme.getIconPrimary(context),
                    ),
                    title: Text(l('preferences')),
                    subtitle: Text(l('preferencesDesc')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PreferencesScreen(),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.chat_outlined,
                      color: AppTheme.getIconPrimary(context),
                    ),
                    title: Text(l('chatSettings')),
                    subtitle: Text(l('chatSettingsDesc')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatSettingsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await authProvider.logout();
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: Text(l('logout')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.getDangerColor(context),
                      side: BorderSide(color: AppTheme.getDangerColor(context)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.getTextSecondary(context),
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(fontSize: 16, color: AppTheme.getTextPrimary(context)),
      ),
    );
  }

}
