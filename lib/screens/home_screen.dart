import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:provider/provider.dart';
import '../services/tts_service.dart';
import '../providers/auth_provider.dart';
import '../providers/translation_mode_provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_translations.dart';
import '../services/translation_websocket_service.dart';
import '../services/error_translator.dart';
import '../config/theme_config.dart';
import '../widgets/ls_app_bar.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _currentCameraIndex = 0;
  final TranslationWebSocketService _wsService = TranslationWebSocketService();
  final TtsService _ttsService = TtsService();

  HandLandmarkerPlugin? _handDetector;
  int _frameCounter = 0;
  static const int _framesToProcess = 3;
  bool _isHandDetectorInitialized = false;

  String _signMode = 'fingerspelling';

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
  bool _isDeviceLandscape = true;
  String _localeCode = 'es';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isVoiceEnabled = context.read<AuthProvider>().isVoiceEnabled;
    _localeCode = context.read<LocaleProvider>().locale.languageCode;
    _initializeHandDetector();
    _initializeCamera();
    _initializeWebSocket();
    _initializeTts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateOrientation();
        _updateDeviceOrientation();
      }
    });
  }

  void _updateOrientation() {
    if (!mounted) return;
    final orientation = MediaQuery.of(context).orientation;
    _localeCode = context.read<LocaleProvider>().locale.languageCode;
    setState(() {
      _isDeviceLandscape = orientation == Orientation.landscape;
    });
  }

  void _updateDeviceOrientation() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _frameTimer?.cancel();
    _translationSubscription?.cancel();
    _errorSubscription?.cancel();
    _connectionSubscription?.cancel();
    _wsService.dispose();
    _ttsService.stop();
    _cameraController?.dispose();
    _handDetector?.dispose();
    super.dispose();
  }

  Future<void> _initializeHandDetector() async {
    try {
      _handDetector = HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.7,
        delegate: HandLandmarkerDelegate.gpu,
      );
      _isHandDetectorInitialized = true;
      debugPrint('[HomeScreen] HandLandmarkerPlugin initialized successfully');
    } catch (e) {
      debugPrint('[HomeScreen] Error initializing HandLandmarkerPlugin: $e');
      _isHandDetectorInitialized = false;
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
          displayText = result.text.replaceAll('"', '').trim();
          displayConfidence = result.confidence;
          debugPrint('[HomeScreen] Fingerspelling finalized: $displayText');
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
          final cleanText = displayText.replaceAll('"', '').trim();
          debugPrint(
            '[HomeScreen] TTS check: voiceEnabled=$_isVoiceEnabled, text="$cleanText"',
          );
          if (cleanText.isNotEmpty) {
            _speakText(cleanText);
          }
        }

        if (result.warning == 'rotate_camera') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppTranslations.textStatic(_localeCode, 'rotateDevice'),
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });

      _errorSubscription = _wsService.errorStream.listen((error) {
        if (!mounted) return;
        final errorMsg = error['message'] ?? '';
        final errorCode = error['code'] ?? '';

        if (errorCode == 'AUTH_ERROR' ||
            errorMsg.toLowerCase().contains('token') ||
            errorMsg.toLowerCase().contains('auth') ||
            errorMsg.toLowerCase().contains('unauthorized')) {
          debugPrint('[HomeScreen] Auth error detected in WS, logging out');
          context.read<AuthProvider>().logout();
          return;
        }

        final translatedMessage = ErrorTranslator.translate(errorMsg);
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
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('401') ||
            errStr.contains('unauthorized') ||
            errStr.contains('token') ||
            errStr.contains('auth')) {
          debugPrint('[HomeScreen] Auth error in WS connection, logging out');
          context.read<AuthProvider>().logout();
          return;
        }
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

      final inputMode = context.read<TranslationModeProvider>().inputMode;

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
            _wsService.sendLandmarks(landmarks, mode: _signMode);
            debugPrint('[HomeScreen] Landmarks sent successfully');
          } else {
            debugPrint('[HomeScreen] No hands detected, skipping send');
          }

          if (inputMode == TranslationInputMode.frames) {
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
      // Use the new API with detect() method
      final sensorOrientation =
          _cameraController?.description.sensorOrientation ?? 0;
      final List<Hand> hands = _handDetector!.detect(image, sensorOrientation);

      if (hands.isNotEmpty) {
        debugPrint('[HomeScreen] Detected ${hands.length} hand(s)');
        for (int i = 0; i < hands.length; i++) {
          final hand = hands[i];

          // Get landmarks directly - no flip needed
          // MediaPipe on mobile handles front camera the same as cv2.flip in local scripts
          final handLandmarks = hand.landmarks
              .map<List<double>>((point) => <double>[point.x, point.y, point.z])
              .toList();

          debugPrint(
            '[HomeScreen] Hand $i has ${handLandmarks.length} landmarks',
          );

          // Determine handedness from wrist position
          final wristX = hand.landmarks[0].x;
          if (wristX > 0.5) {
            landmarks['right_hand'] = handLandmarks;
          } else {
            landmarks['left_hand'] = handLandmarks;
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

  Future<void> _speakText(String text) async {
    if (!_ttsService.isEnabled || text.isEmpty) return;
    try {
      debugPrint('[HomeScreen] Speaking: $text');
      await _ttsService.speak(text);
    } catch (e) {
      debugPrint('Error speaking: $e');
    }
  }

  Future<void> _initializeTts() async {
    try {
      await _ttsService.initialize(_localeCode);
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = (String key) => AppTranslations.text(context, key);
    final orientation = MediaQuery.of(context).orientation;
    final isLandscapeDevice = orientation == Orientation.landscape;

    if (isLandscapeDevice) {
      return Scaffold(
        appBar: LSAppBar(
          title: l('translation'),
          showConnectionIndicator: true,
          isConnected: _wsService.isConnected,
          isConnecting: _wsService.isConnecting,
          showLanguageSelector: true,
          toolbarHeight: kToolbarHeight - 5,
          actions: [
            if (_cameras != null && _cameras!.length > 1)
              IconButton(
                icon: const Icon(Icons.flip_camera_ios, size: 20),
                onPressed: _switchCamera,
              ),
            IconButton(
              icon: const Icon(Icons.history, size: 20),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.person, size: 20),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child:
                              _cameraController != null && _isCameraInitialized
                              ? CameraPreview(_cameraController!)
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                        ),
                      ),
                      if (_cameras != null && _cameras!.length > 1)
                        Positioned(
                          top: 8,
                          right: 16,
                          child: FloatingActionButton.small(
                            heroTag: 'switch_camera',
                            onPressed: _switchCamera,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.8),
                            child: const Icon(
                              Icons.flip_camera_ios,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 2, 4, 4),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: SizedBox.expand(
                              child: _buildTranslationResult(l),
                            ),
                          ),
                        ),
                        _buildActionButton(l),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: LSAppBar(
        title: l('translation'),
        showConnectionIndicator: true,
        isConnected: _wsService.isConnected,
        isConnecting: _wsService.isConnecting,
        showLanguageSelector: true,
        toolbarHeight: kToolbarHeight - 3,
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              Expanded(flex: 3, child: _buildCameraPreview()),
              Expanded(flex: 2, child: _buildTranslationResult(l)),
              _buildActionButton(l),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton(String Function(String) l) {
    if (_signMode == 'fingerspelling' && !_isDeviceLandscape) {
      return const SizedBox.shrink();
    }

    if (_isTranslating) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _cancelTranslation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.close),
                label: Text(l('cancelTranslating')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _finalizeTranslation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.check),
                label: Text(l('finalizeTranslating')),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _startTranslation,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.translate),
          label: Text(l('translateWord')),
        ),
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
        if (_signMode == 'fingerspelling' && !_isDeviceLandscape)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.screen_rotation,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppTranslations.textStatic(_localeCode, 'landscape'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTranslationResult(String Function(String) l) {
    final isCompact = _isDeviceLandscape;
    return Container(
      margin: isCompact ? const EdgeInsets.all(4) : const EdgeInsets.all(16),
      padding: isCompact ? const EdgeInsets.all(8) : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isCompact ? '' : l('translation'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (!isCompact) const SizedBox(height: 8),
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
                      '${l('detecting')} $_currentCandidate',
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
                  icon: Icon(
                    _ttsService.isEnabled ? Icons.volume_up : Icons.volume_off,
                  ),
                  onPressed: () {
                    _ttsService.toggle();
                    setState(() {});
                  },
                  color: _ttsService.isEnabled
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ],
            ),
          ],
          SizedBox(height: isCompact ? 4 : MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
