import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'config/api_config.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/translation_mode_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/deep_link_service.dart';
import 'services/error_translator.dart';

class EnvVars {
  static String backendUrl = 'https://sign-language-backend-vqq1.onrender.com';
  static String backendWsUrl = 'wss://sign-language-backend-vqq1.onrender.com';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _loadEnvFromAssets();

  FlutterError.onError = (FlutterErrorDetails details) {
    ErrorTranslator.saveUnhandledError(
      exception: details.exception,
      stackTrace: details.stack ?? StackTrace.current,
    );
  };

  runApp(const LSCTranslatorApp());
}

Future<void> _loadEnvFromAssets() async {
  try {
    final content = await rootBundle.loadString('.env');
    final lines = content.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split('=');
      if (parts.length == 2) {
        final key = parts[0].trim();
        final value = parts[1].trim();
        if (key == 'BACKEND_URL') {
          EnvVars.backendUrl = value;
        } else if (key == 'BACKEND_WS_URL') {
          EnvVars.backendWsUrl = value;
        }
      }
    }
    debugPrint('[main] Loaded env: BACKEND_URL=${EnvVars.backendUrl}');
  } catch (e) {
    debugPrint('[main] Could not load .env, using defaults: $e');
  }
}

class LSCTranslatorApp extends StatefulWidget {
  const LSCTranslatorApp({super.key});

  @override
  State<LSCTranslatorApp> createState() => _LSCTranslatorAppState();
}

class _LSCTranslatorAppState extends State<LSCTranslatorApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _appLinks.uriLinkStream.listen((uri) {
      DeepLinkService().handleUri(uri);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => TranslationModeProvider()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, child) {
          return MaterialApp(
            title: 'Traductor LSC',
            debugShowCheckedModeBanner: ApiConfig.isDevelopment,
            locale: localeProvider.locale,
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: themeProvider.seedColor,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: themeProvider.seedColor,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isInitialized) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Conectando...',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          );
        }

        if (auth.isAuthenticated) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class ConnectionErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const ConnectionErrorScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              Text(
                'Sin conexión',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No se pudo conectar al servidor.\nVerifica tu conexión a internet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
