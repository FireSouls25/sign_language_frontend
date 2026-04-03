import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../models/translation.dart';

typedef TranslationCallback = void Function(TranslationResult result);
typedef ErrorCallback = void Function(String message, String? code);
typedef ConnectionCallback = void Function();

class TranslationWebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  final _translationController =
      StreamController<TranslationResult>.broadcast();
  final _errorController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<TranslationResult> get translationStream =>
      _translationController.stream;
  Stream<Map<String, dynamic>> get errorStream => _errorController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isDisconnecting = false;
  String? _lastToken;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _pingInterval = Duration(seconds: 20);
  static const Duration _reconnectDelay = Duration(seconds: 3);

  Future<void> connect({String? token}) async {
    if (_isDisconnecting) {
      debugPrint('[WebSocket] Currently disconnecting, waiting...');
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (_isConnected && _channel != null) {
      debugPrint('[WebSocket] Already connected');
      return;
    }

    if (_isConnecting) {
      debugPrint('[WebSocket] Already connecting, waiting...');
      await Future.delayed(const Duration(milliseconds: 500));
      if (_isConnected) {
        debugPrint('[WebSocket] Connection completed while waiting');
        return;
      }
    }

    await disconnect();

    _lastToken = token;
    final wsUrl = token != null
        ? ApiConfig.buildWsUrlWithToken(token)
        : ApiConfig.wsUrl;

    _isConnecting = true;
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }

    try {
      debugPrint('[WebSocket] Connecting to: $wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      await _channel!.ready;
      debugPrint('[WebSocket] Channel ready');

      _subscription = _channel!.stream.listen(
        (message) {
          debugPrint('[WebSocket] Received message');
          _onMessage(message);
        },
        onError: (error) {
          debugPrint('[WebSocket] Stream error: $error');
          _onError(error);
        },
        onDone: () {
          debugPrint('[WebSocket] Stream done/closed');
          _onDone();
        },
        cancelOnError: false,
      );

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      if (!_connectionController.isClosed) {
        _connectionController.add(true);
      }
      debugPrint('[WebSocket] Connected successfully');

      _startPingTimer();
    } catch (e) {
      debugPrint('[WebSocket] Connection error: $e');
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
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      _sendPing();
    });
    debugPrint(
      '[WebSocket] Ping timer started, interval: ${_pingInterval.inSeconds}s',
    );
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
    debugPrint('[WebSocket] Ping timer stopped');
  }

  void _sendPing() {
    if (_channel == null || !_isConnected) {
      debugPrint('[WebSocket] Cannot send ping: not connected');
      return;
    }

    try {
      _channel!.sink.add(jsonEncode({'type': 'ping'}));
      debugPrint('[WebSocket] Ping sent');
    } catch (e) {
      debugPrint('[WebSocket] Error sending ping: $e');
    }
  }

  void _scheduleReconnect() {
    if (_isDisconnecting || _reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint(
        '[WebSocket] Not scheduling reconnect: disconnecting or max attempts reached',
      );
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_isDisconnecting) {
        debugPrint(
          '[WebSocket] Skipping reconnect - intentionally disconnecting',
        );
        return;
      }
      if (!_isConnected &&
          !_isConnecting &&
          _lastToken != null &&
          !_isDisconnecting) {
        _reconnectAttempts++;
        debugPrint(
          '[WebSocket] Attempting reconnect $_reconnectAttempts/$_maxReconnectAttempts',
        );
        connect(token: _lastToken);
      }
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _onMessage(dynamic message) {
    debugPrint('[WebSocket] Raw message received: $message');

    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String;

      debugPrint('[WebSocket] Message type: $type, data: $data');

      switch (type) {
        case 'translation':
          debugPrint('[WebSocket] Parsing translation response...');
          final result = TranslationResult.fromJson(data);
          debugPrint(
            '[WebSocket] Translation result: text="${result.text}", confidence=${result.confidence}',
          );
          _translationController.add(result);
          break;
        case 'error':
          debugPrint('[WebSocket] Error received: ${data['message']}');
          _errorController.add({
            'message': data['message'] as String,
            'code': data['code'] as String?,
          });
          break;
        case 'pong':
          debugPrint('[WebSocket] Pong received');
          break;
        case 'reset':
          debugPrint('[WebSocket] Reset acknowledged');
          break;
        default:
          debugPrint('[WebSocket] Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('[WebSocket] Failed to parse message: $e');
      _errorController.add({
        'message': 'Failed to parse message',
        'code': 'PARSE_ERROR',
      });
    }
  }

  void _onError(dynamic error) {
    debugPrint('[WebSocket] _onError called: $error');

    if (_isDisconnecting) {
      debugPrint('[WebSocket] Ignoring onError - intentional disconnect');
      return;
    }

    _isConnected = false;
    _isConnecting = false;

    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
      debugPrint('[WebSocket] Subscription cancelled in _onError');
    }

    try {
      if (!_connectionController.isClosed) {
        _connectionController.add(false);
      }
    } catch (e) {
      debugPrint('[WebSocket] Error in _onError: $e');
    }

    _errorController.add({
      'message': 'Error de conexión: Verifica tu internet o el servidor',
      'code': 'CONNECTION_ERROR',
    });

    _stopPingTimer();

    if (!_isDisconnecting) {
      _scheduleReconnect();
    }
  }

  void _onDone() {
    debugPrint(
      '[WebSocket] _onDone called, _isDisconnecting: $_isDisconnecting',
    );

    if (_isDisconnecting) {
      debugPrint('[WebSocket] Ignoring onDone - intentional disconnect');
      return;
    }

    _isConnected = false;
    _isConnecting = false;
    _stopPingTimer();

    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
      debugPrint('[WebSocket] Subscription cancelled in _onDone');
    }

    try {
      if (!_connectionController.isClosed) {
        _connectionController.add(false);
      }
    } catch (e) {
      debugPrint('[WebSocket] Error in onDone: $e');
    }

    if (!_isDisconnecting) {
      _scheduleReconnect();
    }
  }

  void sendLandmarks(Map<String, List<List<double>>> landmarks) {
    debugPrint(
      '[WebSocket] sendLandmarks called, isConnected: $_isConnected, channel exists: ${_channel != null}',
    );

    if (_channel == null) {
      debugPrint('[WebSocket] Cannot send landmarks: channel is null');
      return;
    }

    if (!_isConnected) {
      debugPrint(
        '[WebSocket] Cannot send landmarks: not connected (isConnecting: $_isConnecting)',
      );
      return;
    }

    try {
      final message = jsonEncode({
        'type': 'landmarks',
        'data': landmarks,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint(
        '[WebSocket] Sending landmarks message (${message.length} chars)...',
      );
      _channel!.sink.add(message);
      debugPrint(
        '[WebSocket] Landmarks sent successfully: left=${landmarks['left_hand']?.length ?? 0} points, right=${landmarks['right_hand']?.length ?? 0} points',
      );
    } catch (e) {
      debugPrint('[WebSocket] Error sending landmarks: $e');
    }
  }

  void sendReset() {
    if (_channel == null || !_isConnected) {
      throw Exception('WebSocket not connected');
    }

    _channel!.sink.add(jsonEncode({'type': 'reset'}));
  }

  Future<void> disconnect() async {
    _isDisconnecting = true;
    _cancelReconnectTimer();
    _stopPingTimer();
    debugPrint('[WebSocket] Starting intentional disconnect');

    if (_channel != null) {
      try {
        await _subscription?.cancel();
        _subscription = null;

        await _channel!.sink.close();
      } catch (e) {
        debugPrint('[WebSocket] Error closing channel: $e');
      }
    }
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    _reconnectAttempts = 0;

    try {
      if (!_connectionController.isClosed) {
        _connectionController.add(false);
      }
    } catch (e) {
      debugPrint('[WebSocket] Error notifying disconnect: $e');
    }

    _isDisconnecting = false;
    debugPrint('[WebSocket] Disconnect completed');
  }

  void dispose() {
    disconnect();
    _translationController.close();
    _errorController.close();
    _connectionController.close();
  }
}
