# Sign Language Frontend

Aplicación móvil Flutter para traducción de Lengua de Señas Colombiana (LSC) en tiempo real.

## Requisitos

- Flutter 3.x
- Dart 3.x
- Dispositivo Android o iOS

## Estructura del Proyecto

```
lib/
├── main.dart                    # Punto de entrada
├── config/                     # Configuración
│   ├── api_config.dart       # URLs del backend
│   └── theme_config.dart    # Temas y colores
├── providers/                # Estado (Provider)
│   ├── auth_provider.dart   # Autenticación
│   ├── locale_provider.dart # Idioma
│   ├── theme_provider.dart # Tema oscuro
│   └── translation_mode_provider.dart # Modo de envío
├── screens/                 # Pantallas
│   ├── home_screen.dart    # Pantalla principal de traducción
│   ├── login_screen.dart  # Inicio de sesión
│   ├── register_screen.dart # Registro
│   ├── profile_screen.dart # Configuración
│   ├── history_screen.dart # Historial
│   └── favorites_screen.dart # Favoritos
├── services/                # Servicios
│   ├── api_service.dart    # API REST
│   ├── translation_websocket_service.dart # WebSocket
│   └── database_service.dart # SQLite local
├── models/                   # Modelos de datos
├── widgets/                  # Componentes reutilizables
└── l10n/                   # Traducciones
    └── app_translations.dart # Textos multilingüe
```

## Configuración

### API

Editar `lib/config/api_config.dart` para configurar las URLs del backend:

- `ApiConfig.baseUrl` - URL del servidor
- `ApiConfig.wsUrl` - WebSocket para traducción

### Variables de Entorno

El archivo `main.dart` contiene las variables de entorno:

```dart
class EnvVars {
  static const String backendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:8000');
  static const String backendWsUrl = String.fromEnvironment('BACKEND_WS_URL', defaultValue: 'ws://localhost:8000');
}
```

Ejecutar con:
```bash
flutter run --dart-define=BACKEND_URL=http://tu-servidor
```

## Modos de Envío

### Landmarks (Predeterminado)

Envía solo los puntos de landmarks detectados de las manos.

- **Ventaja:** Menor ancho de banda, más rápido
- **Uso:** Análisis de lenguaje de señas

### Frames Completos

Envía la imagen completa de la cámara.

- **Ventaja:** El backend procesa la imagen
- **Uso:** Cuando se necesita procesamiento en servidor

Cambiar en: **Settings > Modo de envío**

## Funcionalidades

- Traducción en tiempo real de LSC
- Modo Handshape (configuraciones de mano)
- Modo Fingerspelling (deletreo)
- Historial de traducciones
- Favoritos
- Voz (TTS)
- Modo oscuro
- Soporte Multiidioma (ES/EN)

## Build

```bash
# Debug
flutter build apk --debug

# Release
flutter build apk --release

# iOS
flutter build ios --release
```

## Dependencias Principales

- `provider` - Gestión de estado
- `camera` - Cámara
- `hand_detection` - Detección de manos
- `opencv_dart` - Procesamiento de imagen
- `web_socket_channel` - WebSocket
- `flutter_tts` - Texto a voz