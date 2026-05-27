import 'package:flutter/material.dart';
import '../widgets/ls_app_bar.dart';
import '../l10n/app_translations.dart';
import '../config/theme_config.dart';

class DictionaryScreen extends StatelessWidget {
  const DictionaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = (String key) => AppTranslations.text(context, key);
    
    // Lista de letras disponibles (sin J ni Z)
    final List<String> letters = [
      'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'K', 
      'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 
      'V', 'W', 'X', 'Y'
    ];

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: LSAppBar(
        title: l('dictionary'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, // 4 columnas
            childAspectRatio: 1.0,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
          ),
          itemCount: letters.length, // 24 elementos (6 filas de 4)
          itemBuilder: (context, index) {
            final letter = letters[index];
            return Card(
              color: AppTheme.getCardColor(context),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        'assets/letters/$letter.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.image_not_supported,
                            color: AppTheme.getTextSecondary(context),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
