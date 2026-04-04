import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../models/translation.dart';
import '../services/translation_repository.dart';
import '../providers/auth_provider.dart';
import '../services/error_translator.dart';
import '../l10n/app_translations.dart';
import '../config/theme_config.dart';
import '../widgets/ls_app_bar.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final TranslationRepository _repository;
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Translation> _translations = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _error;
  bool _isOffline = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repository = TranslationRepository();
    _loadHistory();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory({bool forceRefresh = false}) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.accessToken == null) return;

    _repository.setToken(authProvider.accessToken!);

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final translations = await _repository.getTranslations(
        forceRefresh: forceRefresh,
      );
      setState(() {
        _translations = translations;
        _isLoading = false;
        _isOffline = false;
      });
    } catch (e) {
      ErrorTranslator.translate(e);
      setState(() {
        _error = ErrorTranslator.translate(e);
        _isLoading = false;
        _isOffline = true;
      });
    }
  }

  Future<void> _syncFromServer() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.accessToken == null) return;

    _repository.setToken(authProvider.accessToken!);

    setState(() => _isSyncing = true);

    try {
      await _repository.syncFromServer();
      await _loadHistory(forceRefresh: true);
    } catch (e) {
      ErrorTranslator.translate(e);
      if (mounted) {
        final l = (String key) => AppTranslations.text(context, key);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l('syncError') + ': ${ErrorTranslator.translate(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _playAudio(String? audioUrl) async {
    if (audioUrl == null || audioUrl.isEmpty) return;

    try {
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
    } catch (e) {
      if (mounted) {
        final l = (String key) => AppTranslations.text(context, key);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l('audioPlaybackFailed'))));
      }
    }
  }

  Widget _buildBody() {
    final l = (String key) => AppTranslations.text(context, key);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _translations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: AppTheme.getTextSecondary(context),
            ),
            const SizedBox(height: 16),
            Text(
              _isOffline ? l('noInternetConnection') : l('errorLoadingData'),
              style: const TextStyle(fontSize: 18),
            ),
            if (_isOffline) ...[
              const SizedBox(height: 8),
              Text(
                l('showingLocalData'),
                style: TextStyle(color: AppTheme.getTextSecondary(context)),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isOffline
                  ? _syncFromServer
                  : () => _loadHistory(forceRefresh: true),
              icon: Icon(_isOffline ? Icons.sync : Icons.refresh),
              label: Text(_isOffline ? l('sync') : l('retry')),
            ),
          ],
        ),
      );
    }

    if (_translations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: AppTheme.getTextSecondary(context),
            ),
            const SizedBox(height: 16),
            Text(
              l('noHistoryYet'),
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _syncFromServer,
              icon: const Icon(Icons.sync),
              label: Text(l('sync')),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadHistory(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _translations.length,
        itemBuilder: (context, index) {
          final translation = _translations[index];
          if (_searchQuery.isNotEmpty &&
              !translation.textResult.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              )) {
            return const SizedBox.shrink();
          }
          return _buildTranslationCard(translation);
        },
      ),
    );
  }

  Widget _buildTranslationCard(Translation translation) {
    return Dismissible(
      key: Key(translation.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: Icon(
          Icons.delete,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      onDismissed: (_) async {
        await _repository.deleteTranslation(translation.id);
        setState(() {
          _translations.removeWhere((t) => t.id == translation.id);
        });
        if (mounted) {
          final l = (String key) => AppTranslations.text(context, key);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l('translationDeleted'))));
        }
      },
      child: Card(
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
                    child: Text(
                      translation.textResult,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(translation.createdAt),
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 12,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getConfidenceColor(translation.confidenceScore),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(translation.confidenceScore * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    final l = (String key) => AppTranslations.text(context, key);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return l('today') +
          ' ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return l('yesterday');
    } else if (difference.inDays < 7) {
      return l('daysAgo').replaceAll('{days}', difference.inDays.toString());
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = (String key) => AppTranslations.text(context, key);

    return Scaffold(
      appBar: LSAppBar(
        title: l('historyTitle'),
        actions: [
          if (_isSyncing)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _searchQuery = '';
                  }
                });
              },
              tooltip: _isSearching ? l('closeSearch') : l('search'),
            ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncFromServer,
            tooltip: l('sync'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
