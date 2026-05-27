# Login Loader, Stream Controllers & Chat Preloading — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve login UX with full-screen overlay loader, remove Google login, add stream-based parallel data loading, preload chats on login, and hide self-chat from chat list.

**Architecture:** AuthProvider exposes a new `loginStream()` method returning `Stream<LoadState>` that loads conversations, contacts and self-chat in parallel using `Future.wait`. The final state carries the loaded data, which LoginScreen passes to ChatProvider via `setPreloadedData()`, eliminating duplicate API calls. ChatProvider filters out `isSelf` conversations.

**Tech Stack:** Flutter, Dart, Provider, StreamController

---

## Files

### Created
- `lib/services/data_loader_service.dart`

### Deleted
- `lib/services/google_auth_service.dart`

### Modified
- `lib/providers/auth_provider.dart`
- `lib/providers/chat_provider.dart`
- `lib/screens/login_screen.dart`
- `lib/screens/main_screen.dart`

---

### Task 1: Create DataLoaderService

**Files:** Create `lib/services/data_loader_service.dart`

- [ ] **Step 1: Write the file**

```dart
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/data_loader_service.dart
git commit -m "feat: add DataLoaderService with StreamController for parallel loading"
```

---

### Task 2: Update AuthProvider — add loginStream(), keep login() for register

**Files:** Modify `lib/providers/auth_provider.dart`

The original `login()` method is kept for `register()` which calls it. A new private `_loginInternal()` contains the actual auth logic. A new `loginStream()` method returns `Stream<LoadState>` for the login screen.

- [ ] **Step 1: Add imports**

Add:
```dart
import '../services/data_loader_service.dart';
```

- [ ] **Step 2: Rename existing login() to _loginInternal() and keep Future<bool> return**

Rename:
```dart
Future<bool> login({...}) async {
```
To:
```dart
Future<bool> _loginInternal({...}) async {
```

- [ ] **Step 3: Recreate public login() as wrapper for _loginInternal()**

```dart
Future<bool> login({
  required String username,
  required String password,
}) {
  return _loginInternal(username: username, password: password);
}
```

- [ ] **Step 4: Update register() to call _loginInternal()**

```dart
return await _loginInternal(username: username, password: password);
```

- [ ] **Step 5: Add loginStream() method**

```dart
Stream<LoadState> loginStream({
  required String username,
  required String password,
}) async* {
  _error = null;
  notifyListeners();

  try {
    final tokens = await apiService.login(
      username: username,
      password: password,
    );

    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    apiService.setToken(_accessToken!);

    await _saveTokens();
    await fetchCurrentUser();

    if (_user == null) {
      yield const LoadState(
        stage: LoadStage.done,
        isError: true,
        error: 'No se pudo obtener el usuario',
      );
      return;
    }

    final loader = DataLoaderService(apiService);
    loader.loadAll(_user!.id);
    yield* loader.stateStream;
  } on ApiException catch (e) {
    _error = e.message;
    notifyListeners();
    yield LoadState(stage: LoadStage.done, isError: true, error: e.message);
  } on SocketException {
    _error = 'No hay conexión a internet. Verifica tu red.';
    notifyListeners();
    yield LoadState(stage: LoadStage.done, isError: true, error: _error);
  } on TimeoutException {
    _error = 'El servidor no responde. Intenta más tarde.';
    notifyListeners();
    yield LoadState(stage: LoadStage.done, isError: true, error: _error);
  } catch (e) {
    ErrorTranslator.translate(e);
    _error = 'Error de conexión. Verifica tu internet.';
    notifyListeners();
    yield LoadState(stage: LoadStage.done, isError: true, error: _error);
  }
}
```

- [ ] **Step 6: Commit**

```bash
git add lib/providers/auth_provider.dart
git commit -m "feat: add loginStream() that returns Stream<LoadState> with preloaded data"
```

---

### Task 3: Update ChatProvider — filter self-chat, add setPreloadedData

**Files:** Modify `lib/providers/chat_provider.dart`

- [ ] **Step 1: Filter self-chat in loadConversations**

Change:
```dart
_conversations = await _apiService.getConversations();
```
To:
```dart
_conversations = (await _apiService.getConversations())
    .where((c) => !c.isSelf)
    .toList();
```

- [ ] **Step 2: Add setPreloadedData method**

```dart
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
```

- [ ] **Step 3: Commit**

```bash
git add lib/providers/chat_provider.dart
git commit -m "feat: filter self-chat from conversations, add setPreloadedData"
```

---

### Task 4: Update LoginScreen — remove Google login, add overlay + stream listener

**Files:** Modify `lib/screens/login_screen.dart`

- [ ] **Step 1: Replace imports**

Remove:
```dart
import '../services/google_auth_service.dart';
import '../services/deep_link_service.dart';
```

Add:
```dart
import 'dart:async';
import '../services/data_loader_service.dart';
```

- [ ] **Step 2: Remove _googleAuthService field and _loginWithGoogle method**

Delete `final _googleAuthService = GoogleAuthService();`
Delete entire `_loginWithGoogle()` method.

- [ ] **Step 3: Add stream subscription field and update dispose**

Add field:
```dart
StreamSubscription<LoadState>? _loginSub;
```

Update dispose:
```dart
@override
void dispose() {
  _usernameController.dispose();
  _passwordController.dispose();
  _loginSub?.cancel();
  super.dispose();
}
```

- [ ] **Step 4: Replace _login method**

```dart
Future<void> _login() async {
  if (!_formKey.currentState!.validate()) return;

  _loginSub?.cancel();

  final authProvider = context.read<AuthProvider>();
  final chatProvider = context.read<ChatProvider>();
  final l = (String key) => AppTranslations.text(context, key);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 24),
            const Expanded(child: Text('Iniciando sesión...')),
          ],
        ),
      ),
    ),
  );

  final stream = authProvider.loginStream(
    username: _usernameController.text.trim(),
    password: _passwordController.text,
  );

  _loginSub = stream.listen((state) {
    if (!mounted) return;
    if (state.stage == LoadStage.done) {
      Navigator.of(context).pop();
      if (state.isError) {
        setState(() {});
      } else {
        if (state.conversations != null && state.contacts != null) {
          chatProvider.setPreloadedData(
            conversations: state.conversations!,
            contacts: state.contacts!,
            selfConversation: state.selfConversation,
          );
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    }
  });
}
```

- [ ] **Step 5: Remove Google login button from build**

Delete from the Column in the build method:
- The divider + "or" text row
- The OutlinedButton.icon for Google
- The SizedBox(height: 24) above the divider

Keep only the TextButton for "don't have an account? register".

- [ ] **Step 6: Commit**

```bash
git add lib/screens/login_screen.dart
git commit -m "feat: remove Google login, add full-screen overlay loader with stream"
```

---

### Task 5: Update MainScreen — remove initial data load

**Files:** Modify `lib/screens/main_screen.dart`

- [ ] **Step 1: Remove _loadData call and method**

In `initState`, remove:
```dart
WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
```

Remove the entire `_loadData()` method.

- [ ] **Step 2: Commit**

```bash
git add lib/screens/main_screen.dart
git commit -m "refactor: remove initial data load from MainScreen (preloaded during login)"
```

---

### Task 6: Delete GoogleAuthService file

**Files:** Delete `lib/services/google_auth_service.dart`

- [ ] **Step 1: Check for remaining references**

```bash
rg "google_auth_service" lib/
```

Expected: no results.

- [ ] **Step 2: Delete the file**

```bash
rm lib/services/google_auth_service.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/services/google_auth_service.dart
git commit -m "chore: remove Google auth service"
```

---

### Task 7: Verify the build compiles

- [ ] **Step 1: Run flutter analyze**

```bash
flutter analyze
```

Expected: no errors.

- [ ] **Step 2: Fix any issues**

- [ ] **Step 3: Run tests**

```bash
flutter test
```
