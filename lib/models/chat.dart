class UserBrief {
  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;

  UserBrief({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
  });

  factory UserBrief.fromJson(Map<String, dynamic> json) {
    return UserBrief(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  String get displayName => fullName ?? username;
}

class ConversationModel {
  final String id;
  final UserBrief otherUser;
  final bool isSelf;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  ConversationModel({
    required this.id,
    required this.otherUser,
    required this.isSelf,
    this.lastMessageText,
    this.lastMessageAt,
    required this.createdAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      otherUser: UserBrief.fromJson(json['other_user'] as Map<String, dynamic>),
      isSelf: json['is_self'] as bool? ?? false,
      lastMessageText: json['last_message_text'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ContactModel {
  final String id;
  final String userId;
  final UserBrief contact;
  final String? displayName;
  final DateTime createdAt;

  ContactModel({
    required this.id,
    required this.userId,
    required this.contact,
    this.displayName,
    required this.createdAt,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      contact: UserBrief.fromJson(json['contact'] as Map<String, dynamic>),
      displayName: json['display_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get effectiveName => displayName ?? contact.displayName;
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final String? videoUrl;
  final String? audioUrl;
  final double? confidenceScore;
  final String messageType;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    this.videoUrl,
    this.audioUrl,
    this.confidenceScore,
    this.messageType = 'translation',
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      text: json['text'] as String,
      videoUrl: json['video_url'] as String?,
      audioUrl: json['audio_url'] as String?,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      messageType: json['message_type'] as String? ?? 'translation',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class MessageHistory {
  final List<ChatMessage> items;
  final int total;
  final int page;
  final int size;
  final int pages;

  MessageHistory({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
    required this.pages,
  });

  factory MessageHistory.fromJson(Map<String, dynamic> json) {
    return MessageHistory(
      items: (json['items'] as List<dynamic>)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      size: json['size'] as int,
      pages: json['pages'] as int,
    );
  }
}
