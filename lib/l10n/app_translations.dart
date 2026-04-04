import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';

class AppTranslations {
  static final Map<String, Map<String, String>> _translations = {
    'es': {
      'appTitle': 'Traductor LSC',
      'login': 'Iniciar sesión',
      'register': 'Registrarse',
      'email': 'Correo',
      'password': 'Contraseña',
      'confirmPassword': 'Confirmar Contraseña',
      'name': 'Nombre',
      'logout': 'Cerrar sesión',
      'profile': 'Perfil',
      'history': 'Historial',
      'translation': 'Traducción',
      'startTranslating': 'Presiona el botón para empezar a traducir',
      'stopTranslating': 'Detener',
      'translateWord': 'Traducir',
      'confidence': 'Precisión',
      'reconnectServer': 'Reconectar Servidor',
      'selectLanguage': 'Seleccionar idioma',
      'spanish': 'Español',
      'english': 'Inglés',
      'settings': 'Configuración',
      'voiceEnabled': 'Voz activada',
      'darkMode': 'Modo oscuro',
      'dontHaveAccount': '¿No tienes cuenta?',
      'loginButton': 'Iniciar Sesión',
      'user': 'Usuario',
      'pleaseEnterUser': 'Por favor ingresa tu usuario',
      'pleaseEnterPassword': 'Por favor ingresa tu contraseña',
      'signInWithGoogle': 'Iniciar sesión con Google',
      'createAccount': 'Crear Cuenta',
      'colombianSignLanguage': 'Traductor de Lengua de Señas Colombiana',
      'continueWithGoogle': 'Continuar con Google',
      'or': 'O',
      'registerNow': 'Regístrate',
      'fullName': 'Nombre Completo',
      'pleaseEnterEmail': 'Por favor ingresa tu correo',
      'pleaseEnterValidEmail': 'Por favor ingresa un correo válido',
      'pleaseEnterUsername': 'Por favor ingresa un usuario',
      'pleaseEnterFullName': 'Por favor ingresa tu nombre completo',
      'passwordMinLength': 'La contraseña debe tener al menos 6 caracteres',
      'pleaseConfirmPassword': 'Por favor confirma tu contraseña',
      'passwordsDoNotMatch': 'Las contraseñas no coinciden',
      'alreadyHaveAccount': '¿Ya tienes cuenta?',
      'loginNow': 'Inicia Sesión',
    },
    'en': {
      'appTitle': 'LSC Translator',
      'login': 'Login',
      'register': 'Register',
      'email': 'Email',
      'password': 'Password',
      'confirmPassword': 'Confirm password',
      'name': 'Name',
      'logout': 'Logout',
      'profile': 'Profile',
      'history': 'History',
      'translation': 'Translation',
      'startTranslating': 'Press the button to start translating',
      'stopTranslating': 'Stop',
      'translateWord': 'Translate',
      'confidence': 'Accuracy',
      'reconnectServer': 'Reconnect Server',
      'selectLanguage': 'Select Language',
      'spanish': 'Spanish',
      'english': 'English',
      'settings': 'Settings',
      'voiceEnabled': 'Voice enabled',
      'darkMode': 'Dark mode',
      'dontHaveAccount': "Don't have an account?",
      'loginButton': 'Login',
      'user': 'User',
      'pleaseEnterUser': 'Please enter your user',
      'pleaseEnterPassword': 'Please enter your password',
      'signInWithGoogle': 'Sign in with Google',
      'createAccount': 'Create Account',
      'colombianSignLanguage': 'Colombian Sign Language Translator',
      'continueWithGoogle': 'Continue with Google',
      'or': 'Or',
      'registerNow': 'Register now',
      'fullName': 'Full Name',
      'pleaseEnterEmail': 'Please enter your email',
      'pleaseEnterValidEmail': 'Please enter a valid email',
      'pleaseEnterUsername': 'Please enter a username',
      'pleaseEnterFullName': 'Please enter your full name',
      'passwordMinLength': 'Password must be at least 6 characters',
      'pleaseConfirmPassword': 'Please confirm your password',
      'passwordsDoNotMatch': 'Passwords do not match',
      'alreadyHaveAccount': 'Already have an account?',
      'loginNow': 'Login',
    },
  };

  static String text(BuildContext context, String key) {
    final locale = context.read<LocaleProvider>().locale.languageCode;
    return _translations[locale]?[key] ?? key;
  }

  static String textStatic(String locale, String key) {
    return _translations[locale]?[key] ?? key;
  }
}

extension AppTranslationsExtension on BuildContext {
  String tr(String key) => AppTranslations.text(this, key);
}
