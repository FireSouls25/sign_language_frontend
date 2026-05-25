import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:piper_tts_plugin/piper_tts_plugin.dart';

class TtsService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  PiperTtsPlugin? _tts;
  bool _isEnabled = true;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  int _sampleRate = 22050;
  late String _modelDir;

  bool get isEnabled => _isEnabled;

  Future<void> initialize(String localeCode) async {
    if (_isInitialized) return;
    try {
      debugPrint('TTS: Starting initialization...');
      await _audioPlayer.setVolume(1.0);
      _audioPlayer.playerStateStream.listen((state) {
        debugPrint('TTS: Player state: ${state.processingState}');
        if (state.processingState == ProcessingState.completed) {
          _isSpeaking = false;
        }
      });

      final appDir = await getApplicationSupportDirectory();
      final modelDir = Directory(p.join(appDir.path, 'tts-model', 'es_ES'));

      if (!modelDir.existsSync()) {
        modelDir.createSync(recursive: true);
      }

      final files = ['es_ES-davefx-medium.onnx', 'es_ES-davefx-medium.onnx.json'];

      for (final fileName in files) {
        final assetPath = 'assets/piper_models/es_ES/$fileName';
        final destPath = p.join(modelDir.path, fileName);

        if (!File(destPath).existsSync()) {
          final assetData = await rootBundle.load(assetPath);
          final bytes = assetData.buffer.asUint8List();
          await File(destPath).writeAsBytes(bytes);
          debugPrint('TTS: Copied $fileName (${bytes.length} bytes)');
        } else {
          debugPrint('TTS: $fileName already exists at $destPath');
        }
      }

      _modelDir = modelDir.path;

      final configPath = p.join(_modelDir, 'es_ES-davefx-medium.onnx.json');
      final configFile = File(configPath);
      if (configFile.existsSync()) {
        final config = jsonDecode(configFile.readAsStringSync());
        _sampleRate = config['audio']?['sample_rate'] ?? 22050;
        debugPrint('TTS: Model sample rate: $_sampleRate Hz');
      }

      final modelPath = p.join(_modelDir, 'es_ES-davefx-medium.onnx');

      _tts = PiperTtsPlugin();
      await _tts!.loadViaPath(modelPath: modelPath, configPath: configPath);
      _isInitialized = true;
      debugPrint('TTS: Piper initialized');
    } catch (e, stack) {
      debugPrint('Error initializing TTS: $e');
      debugPrint('Stack: $stack');
    }
  }

  Future<void> speak(String text) async {
    debugPrint('TTS speak called: text=$text');
    if (!_isEnabled || text.isEmpty) {
      debugPrint('TTS: Skipped - not enabled or empty');
      return;
    }

    if (_isSpeaking) {
      debugPrint('TTS: Already speaking, skipping');
      return;
    }

    if (!_isInitialized || _tts == null) {
      debugPrint('TTS: Not initialized, initializing now...');
      await initialize('es_ES');
      if (!_isInitialized || _tts == null) {
        debugPrint('TTS: Failed to initialize');
        return;
      }
    }

    try {
      await _audioPlayer.stop();
      debugPrint('TTS: Generating speech for: $text');

      final tempDir = await getTemporaryDirectory();
      final wavPath = p.join(tempDir.path, 'tts_output.wav');

      final file = await _tts!.synthesizeToFile(text: text, outputPath: wavPath);
      debugPrint('TTS: Generated audio file: ${file.path} (${await file.length()} bytes)');

      if (await file.length() < 100) {
        debugPrint('TTS: Audio file too small, skipping playback');
        return;
      }

      await _fixWavSampleRate(file, _sampleRate);

      await _audioPlayer.setAudioSource(
        AudioSource.file(file.path),
        preload: false,
      );
      _isSpeaking = true;
      await _audioPlayer.play();
      debugPrint('TTS: Playing audio');
    } catch (e, stack) {
      _isSpeaking = false;
      debugPrint('Error speaking: $e');
      debugPrint('Stack: $stack');
    }
  }

  Future<void> _fixWavSampleRate(File file, int correctSampleRate) async {
    final bytes = await file.readAsBytes();
    if (bytes.length < 44) return;

    final headerSampleRate = bytes.buffer.asByteData().getUint32(24, Endian.little);
    if (headerSampleRate == correctSampleRate) return;

    debugPrint('TTS: Fixing WAV sample rate: $headerSampleRate -> $correctSampleRate');

    final byteData = bytes.buffer.asByteData();
    byteData.setUint32(24, correctSampleRate, Endian.little);
    byteData.setUint32(28, correctSampleRate * 2, Endian.little);

    await file.writeAsBytes(byteData.buffer.asUint8List());
  }

  Future<void> stop() async {
    _isSpeaking = false;
    await _audioPlayer.stop();
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  void toggle() {
    _isEnabled = !_isEnabled;
  }

  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
