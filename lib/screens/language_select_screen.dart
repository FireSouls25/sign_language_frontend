import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';

class LanguageSelectScreen extends StatelessWidget {
  const LanguageSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final currentLocale = localeProvider.locale.languageCode;

    final languages = [
      {
        'code': 'es',
        'name': 'Español',
        'flag': '🇨🇴',
        'nativeName': 'Español',
      },
      {
        'code': 'en',
        'name': 'English',
        'flag': '🇺🇸',
        'nativeName': 'English',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar idioma'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: languages.length,
        itemBuilder: (context, index) {
          final lang = languages[index];
          final isSelected = currentLocale == lang['code'];

          return ListTile(
            leading: Text(lang['flag']!, style: const TextStyle(fontSize: 32)),
            title: Text(
              lang['name']!,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Text(lang['nativeName']!),
            trailing: isSelected
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () {
              localeProvider.setLocale(Locale(lang['code']!));
              Navigator.of(context).pop();
            },
            selected: isSelected,
            selectedTileColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.1),
          );
        },
      ),
    );
  }
}
