import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../models/translation.dart';

typedef TranslationCallback = void Function(TranslationResult result);
typedef ErrorCallback = void Function(String message, String? code);
typedef ConnectionCallback = void Function();

class TranslationWebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

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

    String wsUrl = ApiConfig.wsUrl;
    if (token != null) {
      wsUrl += '?token=$token';
    }

    _isConnecting = true;
    _connectionController.add(false); // Estamos en proceso de conectar

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
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
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String;

      switch (type) {
        case 'translation':
          final result = TranslationResult.fromJson(data);
          _translationController.add(result);
          break;
        case 'error':
          _errorController.add({
            'message': data['message'] as String,
            'code': data['code'] as String?,
          });
          break;
      }
    } catch (e) {
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

  void sendReset() {
    if (_channel == null || !_isConnected) {
      throw Exception('WebSocket not connected');
    }

    _channel!.sink.add(jsonEncode({'type': 'reset'}));
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _subscription = null;
    _isConnected = false;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _translationController.close();
    _errorController.close();
    _connectionController.close();
  }
}
