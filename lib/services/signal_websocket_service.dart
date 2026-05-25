import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../models/chat.dart';

class SignalWebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  final _messageController = StreamController<ChatMessage>.broadcast();
  final _userEventController = StreamController<Map<String, dynamic>>.broadcast();
  final _signalingController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _errorController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get userEventStream => _userEventController.stream;
  Stream<Map<String, dynamic>> get signalingStream => _signalingController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get errorStream => _errorController.stream;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isDisconnecting = false;
  String? _lastConversationId;
  String? _lastToken;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _pingInterval = Duration(seconds: 15);

  Future<void> connect({
    required String conversationId,
    required String token,
  }) async {
    if (_isDisconnecting) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (_isConnected && _channel != null &&
        _lastConversationId == conversationId) {
      return;
    }

    if (_isConnecting) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_isConnected) return;
    }

    await disconnect();

    _lastConversationId = conversationId;
    _lastToken = token;
    final wsUrl = ApiConfig.buildSignalWsUrl(conversationId, token);

    _isConnecting = true;
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      if (!_connectionController.isClosed) {
        _connectionController.add(true);
      }

      _startPingTimer();
    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      if (!_connectionController.isClosed) {
        _connectionController.add(false);
      }
      _channel = null;
      _scheduleReconnect();
      rethrow;
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) => _sendPing());
    Future.delayed(const Duration(seconds: 5), () {
      if (_isConnected && !_isDisconnecting) _sendPing();
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _sendPing() {
    if (_channel == null || !_isConnected) return;
    try {
      _channel!.sink.add(jsonEncode({'type': 'ping'}));
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (_isDisconnecting || _reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectTimer?.cancel();

    final delaySeconds =
        (2 * (1 << _reconnectAttempts.clamp(0, 5))).clamp(2, 30);

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_isDisconnecting) return;
      if (!_isConnected && !_isConnecting &&
          _lastConversationId != null && _lastToken != null) {
        _reconnectAttempts++;
        connect(
          conversationId: _lastConversationId!,
          token: _lastToken!,
        );
      }
    });
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'translation':
          final msg = ChatMessage(
            id: data['message_id'] as String? ?? '',
            conversationId: _lastConversationId ?? '',
            senderId: data['from_id'] as String? ?? '',
            text: data['text'] as String? ?? '',
            videoUrl: data['video_url'] as String?,
            audioUrl: data['audio_url'] as String?,
            confidenceScore: (data['confidence_score'] as num?)?.toDouble(),
            messageType: 'translation',
            createdAt: data['created_at'] != null
                ? DateTime.parse(data['created_at'] as String)
                : DateTime.now(),
          );
          if (!_messageController.isClosed) {
            _messageController.add(msg);
          }
          break;

        case 'translation_sent':
          break;

        case 'user_joined':
        case 'user_left':
          if (!_userEventController.isClosed) {
            _userEventController.add(data);
          }
          break;

        case 'joined':
          break;

        case 'pong':
          break;

        case 'error':
          if (!_errorController.isClosed) {
            _errorController.add(data);
          }
          break;

        case 'offer':
        case 'answer':
        case 'ice_candidate':
          if (!_signalingController.isClosed) {
            _signalingController.add(data);
          }
          break;

        default:
          debugPrint('[SignalWS] Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('[SignalWS] Parse error: $e');
    }
  }

  void _onError(dynamic error) {
    if (_isDisconnecting) return;
    _isConnected = false;
    _isConnecting = false;
    _subscription?.cancel();
    _subscription = null;
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
    _stopPingTimer();
    if (!_isDisconnecting) _scheduleReconnect();
  }

  void _onDone() {
    if (_isDisconnecting) return;
    _isConnected = false;
    _isConnecting = false;
    _stopPingTimer();
    _subscription?.cancel();
    _subscription = null;
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
    if (!_isDisconnecting) _scheduleReconnect();
  }

  void sendTranslation({
    required String text,
    String? videoUrl,
    String? audioUrl,
    double? confidenceScore,
  }) {
    if (_channel == null || !_isConnected) return;
    _channel!.sink.add(jsonEncode({
      'type': 'translation',
      'text': text,
      if (videoUrl != null) 'video_url': videoUrl,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (confidenceScore != null) 'confidence_score': confidenceScore,
    }));
  }

  void sendOffer(String targetId, String sdp) {
    if (_channel == null || !_isConnected) return;
    _channel!.sink.add(jsonEncode({
      'type': 'offer',
      'target_id': targetId,
      'sdp': sdp,
    }));
  }

  void sendAnswer(String targetId, String sdp) {
    if (_channel == null || !_isConnected) return;
    _channel!.sink.add(jsonEncode({
      'type': 'answer',
      'target_id': targetId,
      'sdp': sdp,
    }));
  }

  void sendIceCandidate(String targetId, Map<String, dynamic> candidate) {
    if (_channel == null || !_isConnected) return;
    _channel!.sink.add(jsonEncode({
      'type': 'ice_candidate',
      'target_id': targetId,
      'candidate': candidate,
    }));
  }

  Future<void> disconnect() async {
    _isDisconnecting = true;
    _reconnectTimer?.cancel();
    _stopPingTimer();

    if (_channel != null) {
      try {
        await _subscription?.cancel();
        _subscription = null;
        await _channel!.sink.close();
      } catch (_) {}
    }
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    _reconnectAttempts = 0;
    _lastConversationId = null;
    _lastToken = null;

    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
    _isDisconnecting = false;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _userEventController.close();
    _signalingController.close();
    _connectionController.close();
    _errorController.close();
  }
}
