import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../l10n/app_translations.dart';
import '../config/theme_config.dart';
import '../widgets/ls_app_bar.dart';
import '../models/chat.dart';
import '../services/translation_websocket_service.dart';
import '../services/webrtc_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final ConversationModel conversation;
  final bool isSelfChat;

  const ChatDetailScreen({
    super.key,
    required this.conversation,
    this.isSelfChat = false,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _scrollController = ScrollController();
  final TranslationWebSocketService _translateWs = TranslationWebSocketService();
  final WebRTCService _webrtc = WebRTCService();

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _currentCameraIndex = 0;
  HandLandmarkerPlugin? _handDetector;
  bool _isHandDetectorInitialized = false;
  bool _isCameraInitialized = false;
  bool _isTranslating = false;
  int _frameCounter = 0;
  static const int _framesToProcess = 5;
  Timer? _frameTimer;
  StreamSubscription? _translationSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _signalingSub;
  StreamSubscription? _callEventSub;
  StreamSubscription<CallState>? _callStateSub;
  StreamSubscription<MediaStream?>? _remoteStreamSub;

  bool _isVideoCall = false;
  bool _isCallRinging = false;
  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;

  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    if (!widget.isSelfChat) {
      _initRenderers();
    }
    _initChat();
    _initCamera();
    _initHandDetector();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _initChat() async {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();

    await chatProvider.loadMessages(widget.conversation.id);

    if (authProvider.accessToken != null) {
      chatProvider.connectSignal(
        widget.conversation.id,
        authProvider.accessToken!,
      );
    }

    await _initTranslateWs();
    if (!widget.isSelfChat) {
      _initSignaling();
    }
  }

  Future<void> _initTranslateWs() async {
    final authProvider = context.read<AuthProvider>();
    try {
      await _translateWs.connect(token: authProvider.accessToken);

      _translationSub = _translateWs.translationStream.listen((result) {
        if (!mounted) return;
        if (result.isFinalized) {
          final text = result.text.replaceAll('"', '').trim();
          if (text.isNotEmpty) {
            HapticFeedback.lightImpact();
            context.read<ChatProvider>().sendMessage(
              widget.conversation.id,
              text: text,
              confidenceScore: result.confidence,
            );
          }
        }
      });

      _errorSub = _translateWs.errorStream.listen((error) {
        final msg = error['message'] ?? '';
        if (msg.toLowerCase().contains('token') ||
            msg.toLowerCase().contains('auth')) {
          context.read<AuthProvider>().logout();
        }
      });
    } catch (_) {}
  }

  void _initSignaling() {
    final chatProvider = context.read<ChatProvider>();

    _callEventSub = chatProvider.signalWs.callEventStream.listen((data) {
      if (!mounted) return;
      final type = data['type'] as String?;
      final fromId = data['from_id'] as String?;
      if (fromId == null) return;

      switch (type) {
        case 'call_request':
          _showIncomingCallDialog(fromId);
          break;
        case 'call_response':
          final accepted = data['accepted'] as bool? ?? false;
          if (accepted) {
            _startWebRTCOffer();
          } else {
            if (mounted) {
              setState(() => _isCallRinging = false);
              final l = (String key) => AppTranslations.text(context, key);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${widget.conversation.otherUser.displayName} ${l('callDeclined')}')),
              );
            }
          }
          break;
      }
    });

    _signalingSub = chatProvider.signalWs.signalingStream.listen((data) {
      if (!mounted) return;
      final type = data['type'] as String?;
      final fromId = data['from_id'] as String?;
      if (fromId == null) return;

      switch (type) {
        case 'offer':
          _webrtc.handleOffer(data);
          break;
        case 'answer':
          _webrtc.handleAnswer(data);
          break;
        case 'ice_candidate':
          _webrtc.handleIceCandidate(data);
          break;
      }
    });
  }

  void _showIncomingCallDialog(String fromId) {
    final l = (String key) => AppTranslations.text(context, key);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l('incomingCall')),
        content: Text('${widget.conversation.otherUser.displayName} ${l('incomingCallDesc')}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<ChatProvider>().signalWs.sendCallResponse(fromId, false);
            },
            child: Text(l('decline')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<ChatProvider>().signalWs.sendCallResponse(fromId, true);
              _initWebRTC();
            },
            child: Text(l('accept')),
          ),
        ],
      ),
    );
  }

  void _initWebRTC() {
    final chatProvider = context.read<ChatProvider>();
    final otherId = widget.conversation.otherUser.id;

    _webrtc.initialize(
      signalWs: chatProvider.signalWs,
      otherUserId: otherId,
    );

    _callStateSub = _webrtc.callStateStream.listen((state) {
      if (!mounted) return;
      if (state == CallState.disconnected) {
        setState(() => _isVideoCall = false);
      }
    });

    _remoteStreamSub = _webrtc.remoteStreamStream.listen((stream) {
      if (!mounted) return;
      if (stream != null) {
        _remoteRenderer.srcObject = stream;
      }
    });
  }

  Future<void> _startVideoCall() async {
    if (_isCallRinging) return;
    final chatProvider = context.read<ChatProvider>();
    chatProvider.signalWs.sendCallRequest(widget.conversation.otherUser.id);
    setState(() => _isCallRinging = true);
  }

  Future<void> _startWebRTCOffer() async {
    _initWebRTC();
    final success = await _webrtc.startCall();
    if (mounted && success) {
      setState(() {
        _isVideoCall = true;
        _isCallRinging = false;
        _localRenderer.srcObject = _webrtc.localStream;
      });
    }
  }

  Future<void> _endVideoCall() async {
    await _webrtc.endCall();
    if (mounted) {
      setState(() {
        _isVideoCall = false;
        _localRenderer.srcObject = null;
        _remoteRenderer.srcObject = null;
      });
    }
  }

  Future<void> _initHandDetector() async {
    try {
      _handDetector = HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.7,
        delegate: HandLandmarkerDelegate.gpu,
      );
      _isHandDetectorInitialized = true;
    } catch (_) {
      _isHandDetectorInitialized = false;
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        await _setupCamera(0);
      }
    } catch (_) {}
  }

  Future<void> _setupCamera(int index) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }
    if (_cameras == null || _cameras!.isEmpty) return;
    if (index >= _cameras!.length) return;

    _currentCameraIndex = index;
    _cameraController = CameraController(
      _cameras![index],
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (_) {}
  }

  void _switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    final next = (_currentCameraIndex + 1) % _cameras!.length;
    _setupCamera(next);
  }

  void _startTranslation() {
    if (_cameraController == null || !_isCameraInitialized) return;

    setState(() {
      _isTranslating = true;
    });

    _cameraController!.startImageStream((CameraImage image) async {
      if (!_translateWs.isConnected || _cameraController == null) return;

      _frameCounter++;
      if (_frameCounter >= _framesToProcess &&
          _isHandDetectorInitialized && _handDetector != null) {
        _frameCounter = 0;
        final landmarks = await _processImageForLandmarks(image);
        if (landmarks['left_hand'] != null ||
            landmarks['right_hand'] != null) {
          _translateWs.sendLandmarks(landmarks, mode: 'fingerspelling');
        }
      }
    });
  }

  Future<Map<String, List<List<double>>>> _processImageForLandmarks(
    CameraImage image,
  ) async {
    final landmarks = <String, List<List<double>>>{};
    if (_handDetector == null || !_isHandDetectorInitialized) return landmarks;
    try {
      final sensorOrientation =
          _cameraController?.description.sensorOrientation ?? 0;
      final hands = _handDetector!.detect(image, sensorOrientation);
      if (hands.isNotEmpty) {
        for (final hand in hands) {
          final handLandmarks = hand.landmarks
              .map<List<double>>(
                  (point) => <double>[point.x, point.y, point.z])
              .toList();
          final wristX = hand.landmarks[0].x;
          if (wristX > 0.5) {
            landmarks['right_hand'] = handLandmarks;
          } else {
            landmarks['left_hand'] = handLandmarks;
          }
        }
      }
    } catch (_) {}
    return landmarks;
  }

  void _stopTranslation() {
    _cameraController?.stopImageStream();
    _frameTimer?.cancel();
    _frameCounter = 0;
    if (_translateWs.isConnected) _translateWs.sendReset();
    setState(() => _isTranslating = false);
  }

  void _finalizeTranslation() {
    _cameraController?.stopImageStream();
    _frameTimer?.cancel();
    _frameCounter = 0;
    setState(() => _isTranslating = false);
    if (_translateWs.isConnected) _translateWs.sendFinalize();
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _handDetector?.dispose();
    _frameTimer?.cancel();
    _translationSub?.cancel();
    _errorSub?.cancel();
    _signalingSub?.cancel();
    _callEventSub?.cancel();
    _callStateSub?.cancel();
    _remoteStreamSub?.cancel();
    _translateWs.dispose();
    if (!widget.isSelfChat) {
      _webrtc.dispose();
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    }
    context.read<ChatProvider>().disconnectSignal();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = (String key) => AppTranslations.text(context, key);
    final theme = Theme.of(context);
    final other = widget.conversation.otherUser;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final _titleWidget = widget.isSelfChat
        ? null
        : Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.getPrimaryContainer(context),
                child: Text(
                  (other.displayName.isNotEmpty
                          ? other.displayName[0]
                          : other.username[0])
                      .toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.getOnPrimaryContainer(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(other.displayName, style: const TextStyle(fontSize: 16)),
            ],
          );

    final _chatActions = widget.isSelfChat
        ? null
        : [
            if (_isCallRinging)
              IconButton(
                icon: Icon(Icons.call_end, color: AppTheme.getDangerColor(context)),
                onPressed: () {
                  context.read<ChatProvider>().signalWs.sendCallResponse(
                    widget.conversation.otherUser.id, false,
                  );
                  setState(() => _isCallRinging = false);
                },
                tooltip: l('endCall'),
              )
            else
              IconButton(
                icon: const Icon(Icons.videocam),
                onPressed: _startVideoCall,
                tooltip: l('videoCall'),
              ),
          ];

    if (!isLandscape) {
      return Scaffold(
        appBar: LSAppBar(
          title: widget.isSelfChat ? l('selfChat') : other.displayName,
          titleWidget: _titleWidget,
          showThemeToggle: false,
          actions: _chatActions,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.screen_rotation, size: 80, color: Colors.orange),
              const SizedBox(height: 24),
              Text(
                l('rotateDevice'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                l('landscape'),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final _landscapeTitleWidget = widget.isSelfChat
        ? null
        : Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.getPrimaryContainer(context),
                child: Text(
                  (other.displayName.isNotEmpty
                          ? other.displayName[0]
                          : other.username[0])
                      .toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.getOnPrimaryContainer(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(other.displayName, style: const TextStyle(fontSize: 16)),
                  Text(
                    _isCallRinging
                        ? l('ringing')
                        : _isVideoCall
                            ? l('onCall')
                            : '@${other.username}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _isVideoCall || _isCallRinging
                          ? AppTheme.getSuccessColor(context)
                          : AppTheme.getOnSurfaceVariant(context),
                    ),
                  ),
                ],
              ),
            ],
          );

    final _landscapeActions = widget.isSelfChat
        ? null
        : [
            if (_isCallRinging)
              IconButton(
                icon: Icon(Icons.call_end, color: AppTheme.getDangerColor(context)),
                onPressed: () {
                  context.read<ChatProvider>().signalWs.sendCallResponse(
                    widget.conversation.otherUser.id, false,
                  );
                  setState(() => _isCallRinging = false);
                },
                tooltip: l('endCall'),
              )
            else
              IconButton(
                icon: Icon(_isVideoCall ? Icons.call_end : Icons.videocam),
                color: _isVideoCall ? AppTheme.getDangerColor(context) : null,
                onPressed: _isVideoCall ? _endVideoCall : _startVideoCall,
                tooltip: _isVideoCall ? l('endCall') : l('videoCall'),
              ),
          ];

    return Scaffold(
      appBar: LSAppBar(
        title: widget.isSelfChat ? l('selfChat') : other.displayName,
        titleWidget: widget.isSelfChat ? null : _landscapeTitleWidget,
        showThemeToggle: false,
        actions: _landscapeActions,
      ),
      body: Row(
        children: [
          Expanded(child: _buildCameraArea(l, theme, other)),
          _buildMessagePanel(l, theme),
        ],
      ),
    );
  }

  Widget _buildCameraArea(
    String Function(String) l,
    ThemeData theme,
    UserBrief other,
  ) {
    if (!widget.isSelfChat && _isVideoCall) {
      return _buildVideoCallView(theme, other);
    }
    return _buildTranslationView(l, theme);
  }

  Widget _buildVideoCallView(ThemeData theme, UserBrief other) {
    return Stack(
      children: [
        if (_remoteRenderer.srcObject != null)
          RTCVideoView(
            _remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            mirror: false,
          )
        else
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Connecting...',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        Positioned(
          right: 12, top: 12,
          child: Container(
            width: 100, height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _localRenderer.srcObject != null
                  ? RTCVideoView(
                      _localRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      mirror: true,
                    )
                  : Container(color: Colors.black),
            ),
          ),
        ),
        Positioned(
          bottom: 16, left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CallControlButton(
                icon: _isMicEnabled ? Icons.mic : Icons.mic_off,
                color: _isMicEnabled ? Colors.white : Colors.red,
                onPressed: () async {
                  await _webrtc.toggleMic();
                  setState(() => _isMicEnabled = !_isMicEnabled);
                },
              ),
              const SizedBox(width: 16),
              _CallControlButton(
                icon: Icons.call_end, color: Colors.red,
                onPressed: _endVideoCall,
              ),
              const SizedBox(width: 16),
              _CallControlButton(
                icon: _isCameraEnabled ? Icons.videocam : Icons.videocam_off,
                color: _isCameraEnabled ? Colors.white : Colors.red,
                onPressed: () async {
                  await _webrtc.toggleCamera();
                  setState(() => _isCameraEnabled = !_isCameraEnabled);
                },
              ),
              const SizedBox(width: 16),
              _CallControlButton(
                icon: Icons.flip_camera_ios, color: Colors.white,
                onPressed: () => _webrtc.switchCamera(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTranslationView(String Function(String) l, ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              if (_isCameraInitialized && _cameraController != null)
                RepaintBoundary(
                  child: ClipRRect(
                    child: CameraPreview(_cameraController!),
                  ),
                )
              else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off, size: 48,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text(l('startTranslating'),
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              if (_cameras != null && _cameras!.length > 1)
                Positioned(
                  top: 8, right: 8,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    onPressed: _switchCamera,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.8),
                    child: const Icon(Icons.flip_camera_ios,
                        color: Colors.white, size: 20),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessagePanel(String Function(String) l, ThemeData theme) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.5,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Consumer<ChatProvider>(
              builder: (context, cp, _) {
                final count = cp.messages.length;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.keyboard_arrow_up, size: 16,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${count > 0 ? l('messages') : l('noMessages')} ($count)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                if (chatProvider.isLoadingMessages &&
                    chatProvider.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final msgs = chatProvider.messages;
                if (msgs.isEmpty) {
                  return Center(
                    child: Text(l('noMessages'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                final myId = chatProvider.myId?['id'] as String?;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4,
                  ),
                  itemCount: msgs.length,
                  itemBuilder: (context, index) {
                    final msg = msgs[index];
                    final isMe = msg.senderId == myId;
                    return _MessageBubble(message: msg, isMe: isMe);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              12, 8, 12, MediaQuery.of(context).padding.bottom + 8,
            ),
            child: _buildTranslateControls(l),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslateControls(String Function(String) l) {
    if (_isTranslating) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _stopTranslation,
              icon: const Icon(Icons.close, size: 18),
              label: Text(l('cancelTranslating')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _finalizeTranslation,
              icon: const Icon(Icons.check, size: 18),
              label: Text(l('finalizeTranslating')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _startTranslation,
        icon: const Icon(Icons.translate, size: 18),
        label: Text(l('translateWord')),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _CallControlButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: null,
      onPressed: onPressed,
      backgroundColor: color.withValues(alpha: 0.8),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.4,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.text,
                    style: TextStyle(
                      color: isMe
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (message.confidenceScore != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${(message.confidenceScore! * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe
                            ? theme.colorScheme.onPrimary
                                .withValues(alpha: 0.7)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? theme.colorScheme.onPrimary
                              .withValues(alpha: 0.6)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
