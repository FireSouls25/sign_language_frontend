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
    
    if (errorStr.contains('format_exception') || errorStr.contains('jsondecode')) {
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
}
