import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../l10n/app_translations.dart';
import '../config/theme_config.dart';

class VisualSettingsScreen extends StatefulWidget {
  const VisualSettingsScreen({super.key});

  @override
  State<VisualSettingsScreen> createState() => _VisualSettingsScreenState();
}

class _VisualSettingsScreenState extends State<VisualSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l = (String key) => AppTranslations.text(context, key);

    return Scaffold(
      appBar: AppBar(
        title: Text(l('visualSettings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SwitchListTile(
            title: Text(l('darkMode')),
            subtitle: Text(l('changeTheme')),
            value: context.watch<ThemeProvider>().isDarkMode,
            activeTrackColor: Theme.of(context).colorScheme.primary,
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
            activeTrackColor: Theme.of(context).colorScheme.primary,
            onChanged: (bool value) {
              context.read<ThemeProvider>().setShowAppBarToggle(value);
            },
            secondary: Icon(
              Icons.app_settings_alt,
              color: AppTheme.getIconPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
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
                _buildColorOption(context, Colors.deepPurple, l('purple')),
                _buildColorOption(context, Colors.blue, l('blue')),
                _buildColorOption(context, Colors.teal, l('green')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption(BuildContext context, Color color, String label) {
    final themeProvider = context.watch<ThemeProvider>();
    final isSelected = themeProvider.seedColor.toARGB32() == color.toARGB32();

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
