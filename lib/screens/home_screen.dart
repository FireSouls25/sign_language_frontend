import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/auth_provider.dart';
import '../services/translation_websocket_service.dart';
import 'login_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
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

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeWebSocket();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("es-CO");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.low,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _initializeWebSocket() async {
    final authProvider = context.read<AuthProvider>();

    try {
      await _wsService.connect(token: authProvider.accessToken);

      _translationSubscription = _wsService.translationStream.listen((result) {
        if (mounted) {
          setState(() {
            _currentTranslation = result.text;
            _confidence = result.confidence;
          });
        }
      });

      _errorSubscription = _wsService.errorStream.listen((error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error['message'])));
        }
      });

      _connectionSubscription = _wsService.connectionStream.listen((connected) {
        if (mounted) {
          setState(() {
            _isTranslating = connected;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to connect: $e')));
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
        
        // Optimización: Eliminar el archivo temporal inmediatamente después de leerlo
        try {
          final file = File(image.path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error eliminando archivo temporal: $e');
        }

        final base64Image = base64Encode(bytes);
        _wsService.sendFrame(base64Image);
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

    setState(() {
      _isTranslating = false;
    });
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
      appBar: AppBar(
        title: const Text('Traductor LSC'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
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

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CameraPreview(_cameraController!),
      ),
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
