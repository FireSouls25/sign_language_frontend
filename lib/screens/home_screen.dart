import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:hand_detection/hand_detection.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/auth_provider.dart';
import '../services/translation_websocket_service.dart';
import '../services/error_translator.dart';
import '../config/theme_config.dart';
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

  HandDetector? _handDetector;
  int _frameCounter = 0;
  static const int _framesToProcess = 5;
  bool _isHandDetectorInitialized = false;

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
    _initializeHandDetector();
    _initializeCamera();
    _initializeWebSocket();
    _initializeTts();
  }

  Future<void> _initializeHandDetector() async {
    try {
      _handDetector = HandDetector(
        mode: HandMode.boxesAndLandmarks,
        landmarkModel: HandLandmarkModel.full,
      );
      await _handDetector!.initialize();
      _isHandDetectorInitialized = true;
      debugPrint('[HomeScreen] HandDetector initialized successfully');
    } catch (e) {
      debugPrint('[HomeScreen] Error initializing HandDetector: $e');
      _isHandDetectorInitialized = false;
    }
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
        debugPrint(
          '[HomeScreen] Received translation result: text="${result.text}", confidence=${result.confidence}',
        );
        if (!mounted) return;
        final text = result.text;

        if (result.confidence >= 0.8 &&
            text.isNotEmpty &&
            text != _currentTranslation) {
          debugPrint(
            '[HomeScreen] High confidence translation detected, triggering haptic',
          );
          HapticFeedback.lightImpact();
        }

        setState(() {
          _currentTranslation = text;
          _confidence = result.confidence;
        });
        debugPrint('[HomeScreen] Updated UI with translation: $text');
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
    debugPrint('[HomeScreen] _startTranslation called');
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      debugPrint('[HomeScreen] Camera not initialized, returning');
      return;
    }

    debugPrint('[HomeScreen] Camera initialized, starting image stream');
    _frameCounter = 0;

    setState(() {
      _isTranslating = true;
      _currentTranslation = '';
      _confidence = 0.0;
    });

    _cameraController!.startImageStream((CameraImage image) async {
      if (!_wsService.isConnected || _cameraController == null) {
        debugPrint('[HomeScreen] WebSocket not connected or camera null');
        return;
      }

      try {
        _frameCounter++;
        debugPrint('[HomeScreen] Frame #$_frameCounter received');

        if (_frameCounter >= _framesToProcess &&
            _isHandDetectorInitialized &&
            _handDetector != null) {
          _frameCounter = 0;

          debugPrint('[HomeScreen] Processing frame for landmarks...');
          final landmarks = await _processImageForLandmarks(image);

          debugPrint(
            '[HomeScreen] Landmarks result: left=${landmarks['left_hand']?.length ?? 0}, right=${landmarks['right_hand']?.length ?? 0}',
          );

          if (landmarks['left_hand'] != null ||
              landmarks['right_hand'] != null) {
            debugPrint('[HomeScreen] Sending landmarks to WebSocket...');
            _wsService.sendLandmarks(landmarks);
            debugPrint('[HomeScreen] Landmarks sent successfully');
          } else {
            debugPrint('[HomeScreen] No hands detected, skipping send');
          }
        }
      } catch (e) {
        debugPrint('[HomeScreen] Error in frame processing: $e');
      }
    });
  }

  Future<Map<String, List<List<double>>>> _processImageForLandmarks(
    CameraImage image,
  ) async {
    Map<String, List<List<double>>> landmarks = {};

    if (_handDetector == null || !_isHandDetectorInitialized) {
      debugPrint('[HomeScreen] HandDetector not initialized');
      return landmarks;
    }

    try {
      final Uint8List imageBytes = image.planes.first.bytes;
      final List<Hand> hands = await _handDetector!.detect(imageBytes);

      if (hands.isNotEmpty) {
        debugPrint('[HomeScreen] Detected ${hands.length} hand(s)');
        for (int i = 0; i < hands.length; i++) {
          final hand = hands[i];
          if (hand.hasLandmarks) {
            final handLandmarks = hand.landmarks
                .map((point) => [point.x, point.y, point.z])
                .toList();

            debugPrint(
              '[HomeScreen] Hand $i has ${handLandmarks.length} landmarks, handedness: ${hand.handedness?.name ?? "unknown"}',
            );

            if (hand.handedness == Handedness.left) {
              landmarks['left_hand'] = handLandmarks;
            } else if (hand.handedness == Handedness.right) {
              landmarks['right_hand'] = handLandmarks;
            }
          }
        }
      } else {
        debugPrint('[HomeScreen] No hands detected in frame');
      }
    } catch (e) {
      debugPrint('[HomeScreen] Error processing image for landmarks: $e');
    }

    return landmarks;
  }

  void _stopTranslation() {
    _cameraController?.stopImageStream();
    _frameTimer?.cancel();
    _frameTimer = null;
    _frameCounter = 0;

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
    _handDetector?.dispose();
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
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
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
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.8),
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
        color: AppTheme.getSurfaceColor(context),
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
                      ? AppTheme.getTextSecondary(context)
                      : Theme.of(context).colorScheme.primary,
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
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildTranslateButton() {
    return FloatingActionButton.extended(
      onPressed: _isTranslating ? _stopTranslation : _startTranslation,
      backgroundColor: _isTranslating
          ? Colors.red
          : Theme.of(context).colorScheme.primary,
      icon: Icon(_isTranslating ? Icons.stop : Icons.translate),
      label: Text(_isTranslating ? 'Detener' : 'Traducir'),
    );
  }
}
