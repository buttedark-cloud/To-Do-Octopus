import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'core/config/supabase_config.dart';
import 'package:to_do/auth_gate.dart';
import 'package:to_do/auth_provider.dart';
import 'package:to_do/core/services/notification_service.dart';
import 'package:to_do/core/services/sync_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/providers/todo_provider.dart';
import 'core/providers/user_profile_provider.dart';
import 'core/providers/settings_provider.dart';
import 'package:flutter/services.dart';
import 'core/providers/notes_provider.dart';
import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AppBootstrap());
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  bool _ready = false;

  ThemeProvider? _themeProvider;
  TodoProvider? _todoProvider;
  UserProfileProvider? _userProfileProvider;
  SettingsProvider? _settingsProvider;
  NotesProvider? _notesProvider;
  AuthProvider? _authProvider;
  SyncManager? _syncManager;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  static const _minimumLoadingScreenDuration = Duration(seconds: 3);

  Future<void> _bootstrap() async {
    final minimumDelay = Future<void>.delayed(_minimumLoadingScreenDuration);

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Supabase нужен только для картинок. Анонимный вход даёт каждому
    // телефону свою папку в хранилище (чужие файлы изменить нельзя).
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    try {
      final supaAuth = Supabase.instance.client.auth;
      if (supaAuth.currentSession == null) {
        await supaAuth.signInAnonymously();
      }
    } catch (_) {
      // Нет сети — повторим попытку при первой загрузке картинки.
    }

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    await NotificationService.instance.initialize();
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.requestExactAlarmPermissionIfNeeded();

    final themeProvider = ThemeProvider();
    final todoProvider = TodoProvider();
    final userProfileProvider = UserProfileProvider();
    final settingsProvider = SettingsProvider();
    final notesProvider = NotesProvider();
    final authProvider = AuthProvider();

    await Future.wait([
      themeProvider.loadFromPrefs(),
      todoProvider.loadFromPrefs(),
      userProfileProvider.loadFromPrefs(),
      settingsProvider.loadFromPrefs(),
      notesProvider.loadFromPrefs(),
    ]);

    final syncManager = SyncManager(
      todoProvider: todoProvider,
      notesProvider: notesProvider,
      userProfileProvider: userProfileProvider,
      settingsProvider: settingsProvider,
    );

    await minimumDelay;

    if (!mounted) return;
    setState(() {
      _themeProvider = themeProvider;
      _todoProvider = todoProvider;
      _userProfileProvider = userProfileProvider;
      _settingsProvider = settingsProvider;
      _notesProvider = notesProvider;
      _authProvider = authProvider;
      _syncManager = syncManager;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _LoadingScreen(),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _themeProvider!),
        ChangeNotifierProvider.value(value: _todoProvider!),
        ChangeNotifierProvider.value(value: _userProfileProvider!),
        ChangeNotifierProvider.value(value: _settingsProvider!),
        ChangeNotifierProvider.value(value: _notesProvider!),
        ChangeNotifierProvider.value(value: _authProvider!),
        Provider<SyncManager>.value(value: _syncManager!),
      ],
      child: const MyApp(),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFDA0F),
      body: Center(
        child: Image.asset(
          'assets/intro_1.gif',
          width: double.infinity,
          height: double.infinity,
          // Если файла нет/имя не совпало — не роняем приложение с чёрным экраном, показываем индикатор загрузки.
          errorBuilder: (context, error, stackTrace) =>
              const CircularProgressIndicator(color: Color(0xFFFF9800)),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'To-Do Octopus',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}
