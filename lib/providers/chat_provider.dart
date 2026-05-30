import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/signal_websocket_service.dart';
import '../services/error_translator.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _apiService;
  final DatabaseService _db = DatabaseService();
  final SignalWebSocketService signalWs = SignalWebSocketService();

  StreamSubscription<ChatMessage>? _messageSub;

  List<ConversationModel> _conversations = [];
  List<ContactModel> _contacts = [];
  List<ChatMessage> _messages = [];
  final Map<String, List<ChatMessage>> _messagesCache = {};
  List<UserBrief> _searchResults = [];
  Map<String, dynamic>? _myId;
  ConversationModel? _selfConversation;

  double _fontSize = 16.0;

  bool _isLoadingConversations = false;
  bool _isLoadingContacts = false;
  bool _isLoadingMessages = false;
  bool _isSearching = false;
  String? _error;

  String? _activeConversationId;
  bool _isSignalConnected = false;

  ChatProvider(this._apiService);

  List<ConversationModel> get conversations => _conversations;
  List<ContactModel> get contacts => _contacts;
  List<ChatMessage> get messages => _messages;
  List<UserBrief> get searchResults => _searchResults;
  Map<String, dynamic>? get myId => _myId;
  ConversationModel? get selfConversation => _selfConversation;
  double get fontSize => _fontSize;
  bool get isSignalConnected => _isSignalConnected;

  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingContacts => _isLoadingContacts;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isSearching => _isSearching;
  String? get error => _error;

  void setFontSize(double size) {
    _fontSize = size;
    notifyListeners();
  }

  Future<void> ensureSelfChat() async {
    final id = _myId?['id'] as String?;
    if (id == null) return;
    if (_selfConversation != null) return;

    try {
      _selfConversation = await _apiService.createConversation(id);
      notifyListeners();
    } catch (e) {
      debugPrint('[ChatProvider] ensureSelfChat error: $e');
    }
  }

  void setPreloadedData({
    required List<ConversationModel> conversations,
    required List<ContactModel> contacts,
    ConversationModel? selfConversation,
  }) {
    _conversations = conversations.where((c) => !c.isSelf).toList();
    _contacts = contacts;
    if (selfConversation != null) {
      _selfConversation = selfConversation;
    }
    notifyListeners();
  }

  Future<void> preloadMessages(List<ConversationModel> conversations) async {
    final futures = conversations.take(3).map((c) async {
      try {
        final history = await _apiService.getMessages(c.id);
        _messagesCache[c.id] = history.items;
      } catch (_) {}
    });
    await Future.wait(futures);
  }

  void clear() {
    disconnectSignal();
    _conversations = [];
    _contacts = [];
    _messages = [];
    _messagesCache.clear();
    _searchResults = [];
    _myId = null;
    _selfConversation = null;
    _error = null;
    _isLoadingConversations = false;
    _isLoadingContacts = false;
    _isLoadingMessages = false;
    _isSearching = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadMyId() async {
    try {
      _myId = await _apiService.getMyId();
      notifyListeners();
    } catch (e) {
      debugPrint('[ChatProvider] Failed to load my id: $e');
    }
  }

  Future<void> loadConversations() async {
    _isLoadingConversations = true;
    _error = null;
    notifyListeners();

    try {
      _conversations = (await _apiService.getConversations())
          .where((c) => !c.isSelf)
          .toList();
    } catch (e) {
      _error = 'Failed to load conversations';
      ErrorTranslator.translate(e);
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  Future<ConversationModel?> createConversation(String participantId) async {
    try {
      final conv = await _apiService.createConversation(participantId);
      await loadConversations();
      return conv;
    } catch (e) {
      _error = 'Failed to create conversation';
      notifyListeners();
      return null;
    }
  }

  Future<void> loadContacts() async {
    _isLoadingContacts = true;
    _error = null;
    notifyListeners();

    try {
      _contacts = await _apiService.getContacts();
    } catch (e) {
      _error = 'Failed to load contacts';
    } finally {
      _isLoadingContacts = false;
      notifyListeners();
    }
  }

  Future<bool> addContact(String contactId, {String? displayName}) async {
    try {
      await _apiService.addContact(contactId, displayName: displayName);
      await loadContacts();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeContact(String contactId) async {
    try {
      await _apiService.removeContact(contactId);
      await loadContacts();

      _conversations.removeWhere(
        (c) => c.otherUser.id == contactId,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to remove contact';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeConversation(String conversationId) async {
    try {
      await _apiService.deleteConversation(conversationId);
      _conversations.removeWhere((c) => c.id == conversationId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete conversation';
      notifyListeners();
      return false;
    }
  }

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    _isSearching = true;
    notifyListeners();
    try {
      _searchResults = await _apiService.searchUsers(query);
    } catch (e) {
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(String conversationId) async {
    _activeConversationId = conversationId;
    _isLoadingMessages = true;
    notifyListeners();

    if (_messagesCache.containsKey(conversationId)) {
      _messages = _messagesCache[conversationId]!;
      _isLoadingMessages = false;
      notifyListeners();
      return;
    }

    try {
      final local = await _db.getMessages(conversationId);
      if (local.isNotEmpty) {
        _messages = local;
        notifyListeners();
      }

      final history = await _apiService.getMessages(conversationId);
      _messages = history.items;
      _messagesCache[conversationId] = history.items;
      await _db.saveMessages(history.items);
    } catch (e) {
      if (_messages.isEmpty) {
        final local = await _db.getMessages(conversationId);
        _messages = local;
      }
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage(
    String conversationId, {
    required String text,
    String? videoUrl,
    String? audioUrl,
    double? confidenceScore,
  }) async {
    final senderId = _myId?['id'] as String? ?? '';

    final localMsg = ChatMessage(
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: senderId,
      text: text,
      videoUrl: videoUrl,
      audioUrl: audioUrl,
      confidenceScore: confidenceScore,
      messageType: 'translation',
      createdAt: DateTime.now(),
    );

    if (_activeConversationId == conversationId) {
      _messages.add(localMsg);
      notifyListeners();
    }

    try {
      final msg = await _apiService.sendMessage(
        conversationId,
        text: text,
        videoUrl: videoUrl,
        audioUrl: audioUrl,
        confidenceScore: confidenceScore,
      );
      final index = _messages.indexOf(localMsg);
      if (index != -1) {
        _messages[index] = msg;
      } else {
        _messages.add(msg);
      }
      await _db.saveMessage(msg);
      notifyListeners();
      return true;
    } catch (e) {
      await _db.saveMessage(localMsg);
      return false;
    }
  }

  void connectSignal(String conversationId, String token) {
    signalWs.connect(conversationId: conversationId, token: token);

    _messageSub?.cancel();
    _messageSub = signalWs.messageStream.listen((msg) {
      if (msg.conversationId == _activeConversationId) {
        _messages.add(msg);
        _db.saveMessage(msg);
        notifyListeners();
      }
    });
  }

  void disconnectSignal() {
    _messageSub?.cancel();
    _messageSub = null;
    signalWs.disconnect();
    _activeConversationId = null;
    _isSignalConnected = false;
    notifyListeners();
  }

  void sendViaSignal(String conversationId, String text, {String? videoUrl, String? audioUrl, double? confidenceScore}) {
    final senderId = _myId?['id'] as String? ?? '';

    final localMsg = ChatMessage(
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: senderId,
      text: text,
      videoUrl: videoUrl,
      audioUrl: audioUrl,
      confidenceScore: confidenceScore,
      messageType: 'translation',
      createdAt: DateTime.now(),
    );

    if (_activeConversationId == conversationId) {
      _messages.add(localMsg);
      _db.saveMessage(localMsg);
      notifyListeners();
    }

    signalWs.sendTranslation(
      text: text,
      videoUrl: videoUrl,
      audioUrl: audioUrl,
      confidenceScore: confidenceScore,
    );
  }

  @override
  void dispose() {
    disconnectSignal();
    signalWs.dispose();
    super.dispose();
  }
}
