import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../models/translation.dart';
import '../services/translation_repository.dart';
import '../providers/auth_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _repository = TranslationRepository();
    _loadHistory();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
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
      setState(() {
        _error = e.toString();
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al sincronizar: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falló la reproducción del audio')),
        );
      }
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _translations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _isOffline ? 'Sin conexión a internet' : 'Error al cargar',
              style: const TextStyle(fontSize: 18),
            ),
            if (_isOffline) ...[
              const SizedBox(height: 8),
              const Text(
                'Mostrando datos guardados localmente',
                style: TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isOffline
                  ? _syncFromServer
                  : () => _loadHistory(forceRefresh: true),
              icon: Icon(_isOffline ? Icons.sync : Icons.refresh),
              label: Text(_isOffline ? 'Sincronizar' : 'Reintentar'),
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
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Aún no hay historial de traducciones',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _syncFromServer,
              icon: const Icon(Icons.sync),
              label: const Text('Sincronizar'),
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
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        await _repository.deleteTranslation(translation.id);
        setState(() {
          _translations.removeWhere((t) => t.id == translation.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Traducción eliminada')));
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
                      color: Colors.deepPurple,
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
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                      style: const TextStyle(
                        color: Colors.white,
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
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LSAppBar(
        title: 'Historial de Traducciones',
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _syncFromServer,
              tooltip: 'Sincronizar',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
