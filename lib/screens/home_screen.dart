import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/auth_provider.dart';
import '../services/translation_websocket_service.dart';
import '../services/error_translator.dart';
import '../widgets/ls_app_bar.dart';
import 'login_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _currentCameraIndex = 0;
  final TranslationWebSocketService _wsService = TranslationWebSocketService();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isCameraInitialized = false;
  bool _isTranslating = false;
  String _currentTranslation = '';
  double _confidence = 0.0;
  Timer? _frameTimer;
  StreamSubscription? _translationSubscription;
  StreamSubscription? _errorSubscription;
  StreamSubscription? _connectionSubscription;
  bool _isVoiceEnabled = true;

  @override
  void initState() {
    super.initState();
    _isVoiceEnabled = context.read<AuthProvider>().isVoiceEnabled;
    _initializeCamera();
    _initializeWebSocket();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage('es-CO');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        await _setupCamera(_currentCameraIndex);
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _setupCamera(int cameraIndex) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    if (_cameras == null || _cameras!.isEmpty) {
      return;
    }

    _cameraController = CameraController(
      _cameras![cameraIndex],
      ResolutionPreset.low,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _currentCameraIndex = cameraIndex;
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error setting up camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      return;
    }

    final newIndex = (_currentCameraIndex + 1) % _cameras!.length;
    await _setupCamera(newIndex);
  }

  Future<void> _initializeWebSocket() async {
    final authProvider = context.read<AuthProvider>();

    try {
      await _wsService.connect(token: authProvider.accessToken);

      _translationSubscription = _wsService.translationStream.listen((result) {
        if (!mounted) return;
        final text = result.text;

        if (result.confidence >= 0.8 &&
            text.isNotEmpty &&
            text != _currentTranslation) {
          HapticFeedback.lightImpact();
        }

        setState(() {
          _currentTranslation = text;
          _confidence = result.confidence;
        });
        if (_isVoiceEnabled && text.isNotEmpty) {
          _speak(text);
        }
      });

      _errorSubscription = _wsService.errorStream.listen((error) {
        if (!mounted) return;
        final translatedMessage = ErrorTranslator.translate(
          error['message'] ?? 'Error desconocido',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(translatedMessage)));
      });

      _connectionSubscription = _wsService.connectionStream.listen((connected) {
        if (!mounted) return;
        setState(() {
          _isTranslating = connected;
        });
      });
    } catch (e) {
      if (mounted) {
        final translatedMessage = ErrorTranslator.translate(e);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(translatedMessage)));
      }
    }
  }

  void _startTranslation() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isTranslating = true;
      _currentTranslation = '';
      _confidence = 0.0;
    });

    _frameTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      if (!_wsService.isConnected || _cameraController == null) {
        timer.cancel();
        return;
      }

      try {
        final image = await _cameraController!.takePicture();
        final bytes = await image.readAsBytes();

        try {
          final file = File(image.path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}

        _wsService.sendFrameBinary(bytes);
      } catch (e) {
        debugPrint('Error sending frame: $e');
      }
    });
  }

  void _stopTranslation() {
    _frameTimer?.cancel();
    _frameTimer = null;

    if (_wsService.isConnected) {
      _wsService.sendReset();
    }

    setState(() => _isTranslating = false);
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error speaking text: $e');
    }
  }

  Future<void> _logout() async {
    _stopTranslation();
    _translationSubscription?.cancel();
    _errorSubscription?.cancel();
    _connectionSubscription?.cancel();
    await _wsService.disconnect();
    await _flutterTts.stop();

    if (mounted) {
      final authProvider = context.read<AuthProvider>();
      await authProvider.logout();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _translationSubscription?.cancel();
    _errorSubscription?.cancel();
    _connectionSubscription?.cancel();
    _wsService.dispose();
    _flutterTts.stop();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LSAppBar(
        title: 'Traductor LSC',
        showConnectionIndicator: true,
        isConnected: _wsService.isConnected,
        isConnecting: _wsService.isConnecting,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Column(
        children: [
          Expanded(flex: 3, child: _buildCameraPreview()),
          Expanded(flex: 2, child: _buildTranslationResult()),
        ],
      ),
      floatingActionButton: _buildTranslateButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurple, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CameraPreview(_cameraController!),
          ),
        ),
        if (_cameras != null && _cameras!.length > 1)
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'switch_camera',
              onPressed: _switchCamera,
              backgroundColor: Colors.deepPurple.withOpacity(0.8),
              child: const Icon(Icons.flip_camera_ios, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildTranslationResult() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Traducción',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Text(
                _currentTranslation.isEmpty
                    ? 'Presiona el botón para empezar a traducir'
                    : _currentTranslation,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: _currentTranslation.isEmpty
                      ? Colors.grey
                      : Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (!_wsService.isConnected && !_wsService.isConnecting) ...[
            Center(
              child: ElevatedButton.icon(
                onPressed: _initializeWebSocket,
                icon: const Icon(Icons.refresh),
                label: const Text('Reconectar Servidor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
          if (_currentTranslation.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Precisión: ${(_confidence * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: _confidence >= 0.7 ? Colors.green : Colors.orange,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  onPressed: () => _speak(_currentTranslation),
                  color: Colors.deepPurple,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTranslateButton() {
    return FloatingActionButton.extended(
      onPressed: _isTranslating ? _stopTranslation : _startTranslation,
      backgroundColor: _isTranslating ? Colors.red : Colors.deepPurple,
      icon: Icon(_isTranslating ? Icons.stop : Icons.translate),
      label: Text(_isTranslating ? 'Detener' : 'Traducir'),
    );
  }
}
