class Translation {
  final String id;
  final String userId;
  final String textResult;
  final String? audioUrl;
  final double confidenceScore;
  final DateTime createdAt;
  bool isFavorite;

  Translation({
    required this.id,
    required this.userId,
    required this.textResult,
    this.audioUrl,
    required this.confidenceScore,
    required this.createdAt,
    this.isFavorite = false,
  });

  factory Translation.fromJson(Map<String, dynamic> json) {
    return Translation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      textResult: json['text_result'] as String,
      audioUrl: json['audio_url'] as String?,
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      isFavorite: json['is_favorite'] == 1 || json['is_favorite'] == true,
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
      isFavorite: map['is_favorite'] == 1 || map['is_favorite'] == true,
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
      'is_favorite': isFavorite ? 1 : 0,
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
  final String phrase;
  final bool isRecording;
  final String candidate;
  final double candidateConfidence;
  final String? audio;
  final String mode;
  final bool isFinalized;
  final String sequence;

  TranslationResult({
    required this.text,
    required this.confidence,
    required this.hasKeypoints,
    this.phrase = '',
    this.isRecording = false,
    this.candidate = '',
    this.candidateConfidence = 0.0,
    this.audio,
    this.mode = 'handshape',
    this.isFinalized = false,
    this.sequence = '',
  });

  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    return TranslationResult(
      text: json['text'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      hasKeypoints: json['has_keypoints'] as bool? ?? false,
      phrase: json['phrase'] as String? ?? '',
      isRecording: json['is_recording'] as bool? ?? false,
      candidate: json['candidate'] as String? ?? '',
      candidateConfidence:
          (json['candidate_confidence'] as num?)?.toDouble() ?? 0.0,
      audio: json['audio'] as String?,
      mode: json['mode'] as String? ?? 'handshape',
      isFinalized: json['is_finalized'] as bool? ?? false,
      sequence: json['sequence'] as String? ?? '',
    );
  }
}
