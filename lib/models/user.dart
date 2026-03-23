class User {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final int translationCount;
  final DateTime createdAt;
  final bool isVerified;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.translationCount,
    required this.createdAt,
    this.isVerified = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      translationCount: json['translation_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'translation_count': translationCount,
      'created_at': createdAt.toIso8601String(),
      'is_verified': isVerified,
    };
  }
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final String tokenType;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String,
    );
  }
}
