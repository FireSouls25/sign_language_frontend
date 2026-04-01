class Log {
  final int? id;
  final String message;
  final String technicalDetails;
  final DateTime timestamp;

  Log({
    this.id,
    required this.message,
    required this.technicalDetails,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message': message,
      'technical_details': technicalDetails,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Log.fromMap(Map<String, dynamic> map) {
    return Log(
      id: map['id'],
      message: map['message'],
      technicalDetails: map['technical_details'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
