import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../models/translation.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../services/error_translator.dart';
import '../l10n/app_translations.dart';
import '../config/theme_config.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Translation> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id ?? '';

    try {
      final favorites = await _dbService.getFavorites(userId);
      if (mounted) {
        setState(() {
          _favorites = favorites;
          _isLoading = false;
        });
      }
    } catch (e) {
      ErrorTranslator.translate(e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _playAudio(String? audioUrl) async {
    if (audioUrl == null || audioUrl.isEmpty) return;
    try {
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
    } catch (e) {
      ErrorTranslator.translate(e);
      if (mounted) {
        final l = (String key) => AppTranslations.text(context, key);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l('audioPlaybackFailed'))));
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = (String key) => AppTranslations.text(context, key);

    return Scaffold(
      appBar: AppBar(
        title: Text(l('favorites')),
        backgroundColor: Colors.redAccent,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _buildBody(l),
    );
  }

  Widget _buildBody(String Function(String) l) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: AppTheme.getTextSecondary(context),
            ),
            const SizedBox(height: 16),
            Text(
              l('noFavoritesYet'),
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final translation = _favorites[index];
        return _buildTranslationCard(translation);
      },
    );
  }

  Widget _buildTranslationCard(Translation translation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      translation.textResult,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: () async {
                    setState(() {
                      _favorites.remove(translation);
                    });
                    await _dbService.toggleFavorite(translation.id, false);
                  },
                ),
                if (translation.audioUrl != null)
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () => _playAudio(translation.audioUrl),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(translation.createdAt),
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
