import '../models/chat.dart';

enum LoadStage { conversations, contacts, selfChat, done }

class LoadState {
  final LoadStage stage;
  final bool isError;
  final String? error;
  final List<ConversationModel>? conversations;
  final List<ContactModel>? contacts;
  final ConversationModel? selfConversation;

  LoadState({
    required this.stage,
    this.isError = false,
    this.error,
    this.conversations,
    this.contacts,
    this.selfConversation,
  });
}
