import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isEnabled = true;
  bool _isInitialized = false;

  bool get isEnabled => _isEnabled;

  Future<void> initialize(String localeCode) async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setLanguage(localeCode == 'es' ? 'es-CO' : 'en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  Future<void> speak(String text) async {
    if (!_isEnabled || text.isEmpty) return;
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error speaking: $e');
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  void toggle() {
    _isEnabled = !_isEnabled;
  }
}
