# Login Loader, Stream Controllers & Chat Preloading

## Objective
Improve the login experience by adding a full-screen loader, removing Google login,
using stream controllers for parallel data loading, preloading chats on login,
and hiding the self-chat from the chat list.

## Changes

### 1. Remove Google Login
- **Files affected**: `lib/screens/login_screen.dart`, `lib/services/google_auth_service.dart`
- Remove the "Continue with Google" button, divider, `_loginWithGoogle` method,
  and import of `GoogleAuthService`
- Delete `lib/services/google_auth_service.dart`

### 2. Full-screen overlay loader
- **Files affected**: `lib/screens/login_screen.dart`
- On login button press: show a modal dialog (`showDialog` with `barrierDismissible: false`)
  containing a `CircularProgressIndicator` and status text
- The overlay blocks interaction until loading completes or errors
- On error: dismiss dialog and show error in form
- On success: dismiss dialog and navigate to MainScreen

### 3. DataLoaderService (stream controllers for parallel loading)
- **New file**: `lib/services/data_loader_service.dart`
- Defines `LoadStage` enum: `conversations`, `contacts`, `selfChat`, `done`
- Defines `LoadState` class with `stage`, `isError`, `error`
- Uses `StreamController<LoadState>` to emit loading progress

### 4. AuthProvider.loading stream
- **Files affected**: `lib/providers/auth_provider.dart`
- `login()` method returns `Stream<LoadState>` instead of `Future<bool>`:
  1. Authenticate (get tokens)
  2. Fetch current user
  3. Load conversations (via API)
  4. Load contacts (via API)
  5. Ensure self-chat exists
  6. Emit done
- Public stream getter for LoginScreen to listen

### 5. ChatProvider filter self-chat
- **Files affected**: `lib/providers/chat_provider.dart`
- `loadConversations()` filters out `isSelf == true`
- `conversations` getter only returns non-self conversations

### 6. MainScreen no longer needs initial data load
- **Files affected**: `lib/screens/main_screen.dart`
- Remove `_loadData()` from initState — data is preloaded during login

### 7. LoginScreen listens to stream
- **Files affected**: `lib/screens/login_screen.dart`
- Subscribe to `AuthProvider.loginStream`
- Update overlay text per stage: "Cargando conversaciones...", "Cargando contactos...",
  "Preparando traducción...", etc.
- On `done`: dismiss overlay, navigate to MainScreen
- On error: dismiss overlay, display error in form

## Files Created
- `lib/services/data_loader_service.dart`

## Files Deleted
- `lib/services/google_auth_service.dart`

## Files Modified
- `lib/screens/login_screen.dart`
- `lib/providers/auth_provider.dart`
- `lib/providers/chat_provider.dart`
- `lib/screens/main_screen.dart`

## Data Flow

```
User taps Login
  → LoginScreen shows overlay dialog
  → AuthProvider.login() called
    → API: POST /auth/login (tokens)
    → API: GET /auth/me (current user)
    → Stream emits conversations (API: GET /conversations) [parallel]
    → Stream emits contacts (API: GET /contacts) [parallel]
    → Stream emits selfChat (API: POST /conversations if needed) [parallel]
    → Stream emits done
  → LoginScreen receives done → dismiss overlay → navigate to MainScreen
  → MainScreen renders with data already loaded
```
