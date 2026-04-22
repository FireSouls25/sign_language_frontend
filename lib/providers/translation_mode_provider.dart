import 'package:flutter/material.dart';

enum TranslationInputMode { landmarks, frames }

class TranslationModeProvider extends ChangeNotifier {
  TranslationInputMode _inputMode = TranslationInputMode.landmarks;

  TranslationInputMode get inputMode => _inputMode;

  bool get isFrameMode => _inputMode == TranslationInputMode.frames;

  bool get isLandmarksMode => _inputMode == TranslationInputMode.landmarks;

  void setInputMode(TranslationInputMode mode) {
    if (_inputMode != mode) {
      _inputMode = mode;
      notifyListeners();
    }
  }

  void toggleInputMode() {
    _inputMode = _inputMode == TranslationInputMode.landmarks
        ? TranslationInputMode.frames
        : TranslationInputMode.landmarks;
    notifyListeners();
  }
}
