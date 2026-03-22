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

  factory Translation.fromMap(Map<String, dynamic> map) {
    return Translation(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      textResult: map['text_result'] as String,
      audioUrl: map['audio_url'] as String?,
      confidenceScore: (map['confidence_score'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'text_result': textResult,
      'audio_url': audioUrl,
      'confidence_score': confidenceScore,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Translation copyWith({
    String? id,
    String? userId,
    String? textResult,
    String? audioUrl,
    double? confidenceScore,
    DateTime? createdAt,
  }) {
    return Translation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      textResult: textResult ?? this.textResult,
      audioUrl: audioUrl ?? this.audioUrl,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      createdAt: createdAt ?? this.createdAt,
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
