import '../services/api_service.dart';
import '../services/database_service.dart';
import '../models/log.dart';

class ErrorTranslator {
  static String translate(dynamic error) {
    // Guardar el log técnico en la base de datos local
    _saveLog(error);

    if (error is ApiException) {
      switch (error.statusCode) {
        case 400:
          return 'Petición inválida. Por favor, revisa los datos.';
        case 401:
          return 'Usuario o contraseña incorrectos.';
        case 403:
          return 'No tienes permisos para realizar esta acción.';
        case 404:
          return 'El recurso solicitado no fue encontrado.';
        case 409:
          return 'El usuario o correo electrónico ya se encuentra registrado.';
        case 422:
          return 'Datos de entrada no válidos. Verifica los campos.';
        case 500:
          return 'Ocurrió un error en el servidor. Intenta más tarde.';
        case 502:
        case 503:
        case 504:
          return 'El servidor no está disponible en este momento.';
        default:
          if (error.message.toLowerCase().contains('failed host lookup') ||
              error.message.toLowerCase().contains('semaphore timeout')) {
            return 'No se pudo conectar con el servidor. Revisa tu conexión a internet.';
          }
          return error.message;
      }
    }

    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('socketexception') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('network is unreachable')) {
      return 'Problema de conexión: Revisa tu internet.';
    }

    if (errorStr.contains('timeout')) {
      return 'La conexión tardó demasiado. Intenta de nuevo.';
    }

    if (errorStr.contains('format_exception') ||
        errorStr.contains('jsondecode')) {
      return 'Error al procesar la respuesta del servidor.';
    }

    return 'Ocurrió un error inesperado. Intenta de nuevo.';
  }

  static void _saveLog(dynamic error) {
    try {
      final log = Log(
        message: 'Error en la aplicación',
        technicalDetails: error.toString(),
        timestamp: DateTime.now(),
      );
      DatabaseService().insertLog(log);
    } catch (e) {
      // Ignoramos fallos al guardar logs para no afectar al usuario
    }
  }

  static void saveUnhandledError({
    required dynamic exception,
    required StackTrace stackTrace,
  }) {
    try {
      final log = Log(
        message: _extractMessage(exception),
        technicalDetails: 'Excepción: $exception\n\nStackTrace:\n$stackTrace',
        timestamp: DateTime.now(),
      );
      DatabaseService().insertLog(log);
    } catch (e) {
      // Ignoramos fallos al guardar logs
    }
  }

  static String _extractMessage(dynamic exception) {
    if (exception is Exception) {
      return exception.toString().replaceAll('Exception: ', '');
    }
    return exception.toString();
  }

  static String translateWithContext(String errorType, String message) {
    final errorStr = '${errorType.toLowerCase()} ${message.toLowerCase()}';

    // Errores de cámara
    if (errorStr.contains('camera') || errorStr.contains('camara')) {
      return 'No se pudo acceder a la cámara. Verifica los permisos.';
    }

    // Errores de microphone
    if (errorStr.contains('microphone') ||
        errorStr.contains('microfono') ||
        errorStr.contains('mic')) {
      return 'No se pudo acceder al micrófono. Verifica los permisos.';
    }

    // Errores de almacenamiento
    if (errorStr.contains('storage') || errorStr.contains('permiso')) {
      return 'No se pudo acceder al almacenamiento.';
    }

    // Errores de base de datos
    if (errorStr.contains('database') ||
        errorStr.contains('sqlite') ||
        errorStr.contains('sqflite')) {
      return 'Error al guardar datos locally.';
    }

    // Errores de JSON
    if (errorStr.contains('json') || errorStr.contains('format')) {
      return 'Error al procesar datos.';
    }

    // Errores de audio/TTS
    if (errorStr.contains('audio') ||
        errorStr.contains('tts') ||
        errorStr.contains('speech')) {
      return 'Error al reproducir audio.';
    }

    // Errores de red
    if (errorStr.contains('network') ||
        errorStr.contains('internet') ||
        errorStr.contains('wifi')) {
      return 'Sin conexión a internet.';
    }

    // Errores de permisos
    if (errorStr.contains('permission') || errorStr.contains('permiso')) {
      return 'Permiso denegado.';
    }

    // Errores de archivo
    if (errorStr.contains('file') ||
        errorStr.contains('archivo') ||
        errorStr.contains('path')) {
      return 'Error al acceder a un archivo.';
    }

    // Errores de formato de número
    if (errorStr.contains('formatexception') || errorStr.contains('number')) {
      return 'Error en el formato de datos.';
    }

    // Errores de índice
    if (errorStr.contains('index') || errorStr.contains('range')) {
      return 'Error interno de la aplicación.';
    }

    // Errores de nulo (Null check)
    if (errorStr.contains('null') || errorStr.contains('nullcheck')) {
      return 'Error interno de la aplicación.';
    }

    // Error genérico
    return 'Ocurrió un error inesperado. Intenta de nuevo.';
  }
}
