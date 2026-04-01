import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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

  Future<void> connect({String? token}) async {
    await disconnect();

    final wsUrl = token != null
        ? ApiConfig.buildWsUrlWithToken(token)
        : ApiConfig.wsUrl;

    _isConnecting = true;
    _connectionController.add(false);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _isConnected = true;
      _isConnecting = false;
      _connectionController.add(true);
    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      _connectionController.add(false);
      rethrow;
    }
  }

  void _onMessage(dynamic message) {
    try {
      if (kDebugMode) {
        debugPrint('[WebSocket] Raw message received: $message');
      }

      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String;

      if (kDebugMode) {
        debugPrint('[WebSocket] Message type: $type, data: $data');
      }

      switch (type) {
        case 'translation':
          final result = TranslationResult.fromJson(data);
          if (kDebugMode) {
            debugPrint(
              '[WebSocket] Translation result: text="${result.text}", confidence=${result.confidence}',
            );
          }
          _translationController.add(result);
          break;
        case 'error':
          debugPrint('[WebSocket] Error received: ${data['message']}');
          _errorController.add({
            'message': data['message'] as String,
            'code': data['code'] as String?,
          });
          break;
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
    _isConnected = false;
    _isConnecting = false;
    _connectionController.add(false);
    _errorController.add({
      'message': 'Error de conexión: Verifica tu internet o el servidor',
      'code': 'CONNECTION_ERROR',
    });
  }

  void _onDone() {
    _isConnected = false;
    _isConnecting = false;
    _connectionController.add(false);
  }

  void sendFrame(String base64Image) {
    if (_channel == null || !_isConnected) {
      throw Exception('WebSocket not connected');
    }

    _channel!.sink.add(jsonEncode({'type': 'frame', 'data': base64Image}));
  }

  void sendFrameBinary(Uint8List imageBytes) {
    if (_channel == null || !_isConnected) {
      return;
    }

    _channel!.sink.add(imageBytes);
  }

  void sendLandmarks(Map<String, List<List<double>>> landmarks) {
    if (_channel == null || !_isConnected) {
      return;
    }

    try {
      final message = jsonEncode({
        'type': 'landmarks',
        'data': landmarks,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      _channel!.sink.add(message);

      debugPrint(
        '[WebSocket] Landmarks sent: left=${landmarks['left_hand']?.length ?? 0} points, right=${landmarks['right_hand']?.length ?? 0} points',
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
    await _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    _isConnected = false;
    _isConnecting = false;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _translationController.close();
    _errorController.close();
    _connectionController.close();
  }
}
