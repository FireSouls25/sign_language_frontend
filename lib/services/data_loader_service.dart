import 'dart:async';
import '../models/chat.dart';
import '../services/api_service.dart';

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

class DataLoaderService {
  final ApiService _apiService;
  final StreamController<LoadState> _controller =
      StreamController<LoadState>.broadcast();

  Stream<LoadState> get stateStream => _controller.stream;

  DataLoaderService(this._apiService);

  Future<void> loadAll(String userId) async {
    try {
      _controller.add(const LoadState(stage: LoadStage.conversations));

      final results = await Future.wait([
        _apiService.getConversations(),
        _apiService.getContacts(),
      ]);

      final conversations = results[0] as List<ConversationModel>;
      final contacts = results[1] as List<ContactModel>;

      ConversationModel? selfConv;
      try {
        selfConv = await _apiService.createConversation(userId);
      } catch (_) {
        selfConv = conversations.where((c) => c.isSelf).firstOrNull;
      }

      _controller.add(LoadState(
        stage: LoadStage.done,
        conversations: conversations,
        contacts: contacts,
        selfConversation: selfConv,
      ));
    } catch (e) {
      _controller.add(LoadState(
        stage: LoadStage.done,
        isError: true,
        error: e.toString(),
      ));
    }
  }

  void dispose() {
    _controller.close();
  }
}
