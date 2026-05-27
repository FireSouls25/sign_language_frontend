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
                  const SizedBox(height: 24),
                  _buildSectionTitle(l('security')),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(l('changePassword')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showChangePasswordDialog(l),
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

  void _showChangePasswordDialog(String Function(String) l) {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(l('changePassword')),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l('currentPassword'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l('enterCurrentPassword');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l('newPassword'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l('enterNewPassword');
                      }
                      if (value.length < 6) {
                        return l('passwordMinLength');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l('confirmNewPassword'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value != newController.text) {
                        return l('passwordsDoNotMatch');
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: Text(l('cancel')),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        setDialogState(() => isLoading = true);

                        final authProvider = context.read<AuthProvider>();
                        final (success, error) = await authProvider
                            .changePassword(
                              currentPassword: currentController.text,
                              newPassword: newController.text,
                            );

                        if (!dialogContext.mounted) return;

                        setDialogState(() => isLoading = false);

                        if (success) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(l('passwordUpdatedSuccess')),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(error ?? l('passwordUpdateError')),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l('update')),
              ),
            ],
          );
        },
      ),
    );
  }
}
