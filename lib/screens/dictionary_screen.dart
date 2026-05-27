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
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FullScreenLetterView(
                      letter: letter,
                      imagePath: 'assets/letters/$letter.png',
                    ),
                  ),
                );
              },
              child: Card(
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
                        child: Hero(
                          tag: 'letter_$letter',
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
              ),
            );
          },
        ),
      ),
    );
  }
}

class FullScreenLetterView extends StatelessWidget {
  final String letter;
  final String imagePath;

  const FullScreenLetterView({
    super.key,
    required this.letter,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fondo negro para resaltar la imagen
      body: Stack(
        children: [
          // Imagen en pantalla completa con zoom habilitado
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Hero(
                tag: 'letter_$letter',
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.image_not_supported,
                      color: Colors.white,
                      size: 100,
                    );
                  },
                ),
              ),
            ),
          ),
          // Botón de retroceso (flecha)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          // Texto de la letra en la parte inferior
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  letter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
