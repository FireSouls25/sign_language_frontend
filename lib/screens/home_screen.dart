import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:hand_detection/hand_detection.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/auth_provider.dart';
import '../providers/translation_mode_provider.dart';
import '../l10n/app_translations.dart';
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

  HandDetectorIsolate? _handDetector;
  int _frameCounter = 0;
  static const int _framesToProcess = 3;
  bool _isHandDetectorInitialized = false;

  String _signMode = 'handshape';

  bool _isCameraInitialized = false;
  bool _isTranslating = false;
  String _currentTranslation = '';
  String _currentCandidate = '';
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
      _handDetector = await HandDetectorIsolate.spawn(
        mode: HandMode.boxesAndLandmarks,
        maxDetections: 2,
        detectorConf: 0.5,
        minLandmarkScore: 0.5,
        performanceConfig: const PerformanceConfig.xnnpack(numThreads: 4),
      );
      _isHandDetectorInitialized = true;
      debugPrint('[HomeScreen] HandDetectorIsolate initialized successfully');
    } catch (e) {
      debugPrint('[HomeScreen] Error initializing HandDetectorIsolate: $e');
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
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.yuv420,
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
          '[HomeScreen] Received translation result: text="${result.text}", confidence=${result.confidence}, candidate="${result.candidate}", candidate_confidence=${result.candidateConfidence}',
        );
        if (!mounted) return;

        // Handle fingerspelling differently - only show text when finalized
        String displayText = result.text;
        double displayConfidence = result.confidence;

        // In fingerspelling mode, only show text when finalized
        if (result.mode == 'fingerspelling' && result.isFinalized == true) {
          displayText = result.text;
          displayConfidence = result.confidence;
          debugPrint('[HomeScreen] Fingerspelling finalized: $displayText');
        } else if (result.mode != 'fingerspelling') {
          // For handshape mode, use candidate if text is empty
          if (result.candidate.isNotEmpty &&
              result.text.isEmpty &&
              result.candidateConfidence >= 0.3) {
            displayText = result.candidate;
            displayConfidence = result.candidateConfidence;
          }
        } else {
          displayText = '';
          displayConfidence = 0.0;
        }

        if (displayText.isNotEmpty && displayText != _currentTranslation) {
          debugPrint(
            '[HomeScreen] High confidence translation detected, triggering haptic',
          );
          HapticFeedback.lightImpact();
        }

        setState(() {
          _currentTranslation = displayText;
          _confidence = displayConfidence;
        });
        debugPrint(
          '[HomeScreen] Updated UI with translation: $displayText (confidence: ${displayConfidence.toStringAsFixed(2)})',
        );
        if (_isVoiceEnabled && displayText.isNotEmpty) {
          _speak(displayText);
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

    final inputMode = context.read<TranslationModeProvider>().inputMode;
    debugPrint('[HomeScreen] Input mode: $inputMode');

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
            inputMode == TranslationInputMode.landmarks) {
          _frameCounter = 0;

          if (_isHandDetectorInitialized && _handDetector != null) {
            debugPrint('[HomeScreen] Processing frame for landmarks...');
            final landmarks = await _processImageForLandmarks(image);

            debugPrint(
              '[HomeScreen] Landmarks result: left=${landmarks['left_hand']?.length ?? 0}, right=${landmarks['right_hand']?.length ?? 0}',
            );

            if (landmarks['left_hand'] != null ||
                landmarks['right_hand'] != null) {
              debugPrint('[HomeScreen] Sending landmarks to WebSocket...');
              _wsService.sendLandmarks(landmarks, mode: _signMode);
              debugPrint('[HomeScreen] Landmarks sent successfully');
            } else {
              debugPrint('[HomeScreen] No hands detected, skipping send');
            }
          }
        } else if (_frameCounter >= _framesToProcess &&
            inputMode == TranslationInputMode.frames) {
          _frameCounter = 0;

          debugPrint('[HomeScreen] Processing frame for sending...');
          final frameData = await _convertCameraImageToBytes(image);

          if (frameData != null) {
            debugPrint('[HomeScreen] Sending frame to WebSocket...');
            _wsService.sendFrame(
              frameData,
              width: image.width,
              height: image.height,
              mode: _signMode,
            );
            debugPrint('[HomeScreen] Frame sent successfully');
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
      cv.Mat? mat = await _convertCameraImageToMat(image);
      if (mat == null) {
        debugPrint('[HomeScreen] Failed to convert camera image to Mat');
        return landmarks;
      }

      final int detectionWidth = mat.cols;
      final int detectionHeight = mat.rows;

      final List<Hand> hands = await _handDetector!.detectHandsFromMat(mat);

      if (hands.isNotEmpty) {
        debugPrint('[HomeScreen] Detected ${hands.length} hand(s)');
        for (int i = 0; i < hands.length; i++) {
          final hand = hands[i];
          if (hand.hasLandmarks) {
            final handLandmarks = hand.landmarks
                .map((point) => [point.x, point.y, point.z])
                .toList();

            debugPrint(
              '[HomeScreen] Hand $i has ${handLandmarks.length} landmarks, image size: ${detectionWidth}x${detectionHeight}',
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

      mat.dispose();
    } catch (e) {
      debugPrint('[HomeScreen] Error processing image for landmarks: $e');
    }

    return landmarks;
  }

  Future<cv.Mat?> _convertCameraImageToMat(CameraImage image) async {
    try {
      final int width = image.width;
      final int height = image.height;

      if (image.planes.length == 1 &&
          (image.planes[0].bytesPerPixel ?? 1) >= 4) {
        final bytes = image.planes[0].bytes;
        final stride = image.planes[0].bytesPerRow;
        final matCols = stride ~/ 4;
        final bgraOrRgba = cv.Mat.fromList(
          height,
          matCols,
          cv.MatType.CV_8UC4,
          bytes,
        );
        final cropped = matCols != width
            ? bgraOrRgba.region(cv.Rect(0, 0, width, height))
            : bgraOrRgba;
        final bgr = cv.cvtColor(cropped, cv.COLOR_BGRA2BGR);
        if (!identical(cropped, bgraOrRgba)) cropped.dispose();
        bgraOrRgba.dispose();
        return bgr;
      }

      final bgrBytes = Uint8List(width * height * 3);
      final int yRowStride = image.planes[0].bytesPerRow;
      final int yPixelStride = image.planes[0].bytesPerPixel ?? 1;

      void writePixel(int x, int y, int yp, int up, int vp) {
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
        final int bgrIdx = (y * width + x) * 3;
        bgrBytes[bgrIdx] = b;
        bgrBytes[bgrIdx + 1] = g;
        bgrBytes[bgrIdx + 2] = r;
      }

      if (image.planes.length == 2) {
        final int uvRowStride = image.planes[1].bytesPerRow;
        final int uvPixelStride = image.planes[1].bytesPerPixel ?? 2;
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final int uvIndex =
                uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
            final int index = y * yRowStride + x * yPixelStride;
            writePixel(
              x,
              y,
              image.planes[0].bytes[index],
              image.planes[1].bytes[uvIndex],
              image.planes[1].bytes[uvIndex + 1],
            );
          }
        }
      } else if (image.planes.length >= 3) {
        final int uvRowStride = image.planes[1].bytesPerRow;
        final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final int uvIndex =
                uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
            final int index = y * yRowStride + x * yPixelStride;
            writePixel(
              x,
              y,
              image.planes[0].bytes[index],
              image.planes[1].bytes[uvIndex],
              image.planes[2].bytes[uvIndex],
            );
          }
        }
      } else {
        return null;
      }

      return cv.Mat.fromList(height, width, cv.MatType.CV_8UC3, bgrBytes);
    } catch (e) {
      debugPrint('[HomeScreen] Error converting CameraImage to Mat: $e');
      return null;
    }
  }

  Future<List<int>?> _convertCameraImageToBytes(CameraImage image) async {
    try {
      final int width = image.width;
      final int height = image.height;

      final bgrBytes = Uint8List(width * height * 3);
      final int yRowStride = image.planes[0].bytesPerRow;
      final int yPixelStride = image.planes[0].bytesPerPixel ?? 1;

      void writePixel(int x, int y, int yp, int up, int vp) {
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
        final int bgrIdx = (y * width + x) * 3;
        bgrBytes[bgrIdx] = b;
        bgrBytes[bgrIdx + 1] = g;
        bgrBytes[bgrIdx + 2] = r;
      }

      if (image.planes.length == 2) {
        final int uvRowStride = image.planes[1].bytesPerRow;
        final int uvPixelStride = image.planes[1].bytesPerPixel ?? 2;
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final int uvIndex =
                uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
            final int index = y * yRowStride + x * yPixelStride;
            writePixel(
              x,
              y,
              image.planes[0].bytes[index],
              image.planes[1].bytes[uvIndex],
              image.planes[1].bytes[uvIndex + 1],
            );
          }
        }
      } else if (image.planes.length >= 3) {
        final int uvRowStride = image.planes[1].bytesPerRow;
        final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final int uvIndex =
                uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
            final int index = y * yRowStride + x * yPixelStride;
            writePixel(
              x,
              y,
              image.planes[0].bytes[index],
              image.planes[1].bytes[uvIndex],
              image.planes[2].bytes[uvIndex],
            );
          }
        }
      } else {
        return null;
      }

      return bgrBytes.toList();
    } catch (e) {
      debugPrint('[HomeScreen] Error converting CameraImage to bytes: $e');
      return null;
    }
  }

  void _stopTranslation() {
    _cameraController?.stopImageStream();
    _frameTimer?.cancel();
    _frameTimer = null;
    _frameCounter = 0;

    if (_wsService.isConnected) {
      _wsService.sendReset();
    }

    setState(() {
      _isTranslating = false;
    });
  }

  void _cancelTranslation() {
    debugPrint('[HomeScreen] _cancelTranslation called');
    _cameraController?.stopImageStream();
    _frameTimer?.cancel();
    _frameTimer = null;
    _frameCounter = 0;

    if (_wsService.isConnected) {
      _wsService.sendReset();
    }

    setState(() {
      _isTranslating = false;
      _currentTranslation = '';
      _currentCandidate = '';
      _confidence = 0.0;
    });

    debugPrint('[HomeScreen] Translation cancelled, sequence reset');
  }

  void _finalizeTranslation() {
    debugPrint('[HomeScreen] _finalizeTranslation called');
    _cameraController?.stopImageStream();
    _frameTimer?.cancel();
    _frameTimer = null;
    _frameCounter = 0;

    setState(() {
      _isTranslating = false;
    });

    if (_wsService.isConnected) {
      debugPrint('[HomeScreen] Sending finalize request...');
      _wsService.sendFinalize();
    }

    debugPrint('[HomeScreen] Finalize request sent');
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
    final l = (String key) => AppTranslations.text(context, key);

    return Scaffold(
      appBar: LSAppBar(
        title: l('translation'),
        showConnectionIndicator: true,
        isConnected: _wsService.isConnected,
        isConnecting: _wsService.isConnecting,
        showLanguageSelector: true,
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
        ],
      ),
      body: Column(
        children: [
          _buildModeSelector(l),
          Expanded(flex: 3, child: _buildCameraPreview()),
          Expanded(flex: 2, child: _buildTranslationResult(l)),
          if (_isTranslating) _buildActionButtons(l),
        ],
      ),
      floatingActionButton: _isTranslating ? null : _buildStartButton(l),
    );
  }

  Widget _buildStartButton(String Function(String) l) {
    return FloatingActionButton.extended(
      onPressed: _startTranslation,
      backgroundColor: Theme.of(context).colorScheme.primary,
      icon: const Icon(Icons.translate),
      label: Text(l('translateWord')),
    );
  }

  Widget _buildActionButtons(String Function(String) l) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: _cancelTranslation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.close),
            label: Text(l('cancelTranslating')),
          ),
          ElevatedButton.icon(
            onPressed: _finalizeTranslation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.check),
            label: Text(l('finalizeTranslating')),
          ),
        ],
      ),
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

  Widget _buildModeSelector(String Function(String) l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: _buildModeButton(
              'handshape',
              l('handshapes'),
              Icons.pan_tool,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildModeButton(
              'fingerspelling',
              l('fingerspelling'),
              Icons.keyboard,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String mode, String label, IconData icon) {
    final isSelected = _signMode == mode;
    return ElevatedButton.icon(
      onPressed: () => _setSignMode(mode),
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: isSelected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _setSignMode(String mode) {
    setState(() {
      _signMode = mode;
    });
    _wsService.sendMode(mode);
    _wsService.sendReset();
  }

  Widget _buildTranslationResult(String Function(String) l) {
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
            l('translation'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentTranslation.isEmpty
                        ? l('startTranslating')
                        : _currentTranslation,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: _currentTranslation.isEmpty
                          ? AppTheme.getTextSecondary(context)
                          : Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_currentCandidate.isNotEmpty &&
                      _currentTranslation.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Detectando: $_currentCandidate',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!_wsService.isConnected && !_wsService.isConnecting) ...[
            Center(
              child: ElevatedButton.icon(
                onPressed: _initializeWebSocket,
                icon: const Icon(Icons.refresh),
                label: Text(l('reconnectServer')),
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
                  '${l('confidence')}: ${(_confidence * 100).toStringAsFixed(1)}%',
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
}
