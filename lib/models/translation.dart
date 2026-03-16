class Translation {
  final String id;
  final String userId;
  final String textResult;
  final String? audioUrl;
  final double confidenceScore;
  final DateTime createdAt;

  Translation({
    required this.id,
    required this.userId,
    required this.textResult,
    this.audioUrl,
    required this.confidenceScore,
    required this.createdAt,
  });

  factory Translation.fromJson(Map<String, dynamic> json) {
    return Translation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      textResult: json['text_result'] as String,
      audioUrl: json['audio_url'] as String?,
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class TranslationResult {
  final String text;
  final double confidence;
  final bool hasKeypoints;

  TranslationResult({
    required this.text,
    required this.confidence,
    required this.hasKeypoints,
  });

  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    return TranslationResult(
      text: json['text'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      hasKeypoints: json['has_keypoints'] as bool,
    );
  }
}
