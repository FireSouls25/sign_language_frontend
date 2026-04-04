import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../l10n/app_translations.dart';
import '../config/theme_config.dart';
import 'logs_screen.dart';

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
      appBar: AppBar(
        title: Text(l('myProfile')),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                  _buildSectionTitle(l('appSettings')),
                  SwitchListTile(
                    title: Text(l('darkMode')),
                    subtitle: Text(l('changeTheme')),
                    value: context.watch<ThemeProvider>().isDarkMode,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (bool value) {
                      context.read<ThemeProvider>().toggleTheme(value);
                    },
                    secondary: const Icon(Icons.dark_mode),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(l('themeButtonInAppBar')),
                    subtitle: Text(l('themeButtonInAppBarDesc')),
                    value: context.watch<ThemeProvider>().showAppBarToggle,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (bool value) {
                      context.read<ThemeProvider>().setShowAppBarToggle(value);
                    },
                    secondary: Icon(
                      Icons.app_settings_alt,
                      color: AppTheme.getIconPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l('accentColor'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildColorOption(
                          context,
                          Colors.deepPurple,
                          l('purple'),
                        ),
                        _buildColorOption(context, Colors.blue, l('blue')),
                        _buildColorOption(context, Colors.teal, l('green')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(l('voiceOutput')),
                    subtitle: Text(l('voiceOutputDesc')),
                    value: authProvider.isVoiceEnabled,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (bool value) {
                      authProvider.toggleVoice(value);
                    },
                    secondary: const Icon(Icons.volume_up),
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
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: Text(l('logout')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
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

  Widget _buildColorOption(BuildContext context, Color color, String label) {
    final themeProvider = context.watch<ThemeProvider>();
    final isSelected = themeProvider.seedColor.value == color.value;

    return GestureDetector(
      onTap: () => themeProvider.setSeedColor(color),
      child: Column(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 2,
                    )
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
