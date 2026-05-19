import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_page.dart';
import 'main_shell.dart';
import 'notification_service.dart';
import 'user_session.dart';
import 'api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Init notification in background — don't block app startup
  NotificationService().init().catchError((_) {});
  runApp(const MyApp());
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

// ─── Design Tokens ────────────────────────────────────────────────
// Centralized color system: one dominant tone (cyan), one accent, one neutral.
// This is the single source of truth for all colors in the app.

class AppColors {
  // Brand
  static const cyan = Color(0xFF13B5EA);
  static const cyanDark = Color(0xFF2C6CFF);
  static const pink = Color(0xFFFF2E93);
  static const purple = Color(0xFF8A2BE2);
  static const green = Color(0xFF00C896);
  static const orange = Color(0xFFFF9800);

  // Light Mode
  static const lightBg = Color(0xFFF5F7FA);
  static const lightSurface = Colors.white;
  static const lightOnSurface = Color(0xFF1A1A2E);
  static const lightDivider = Color(0xFFE2E8F0);
  static const lightCard = Colors.white;
  static const lightSubtext = Color(0xFF64748B);
  static const lightMuted = Color(0xFF94A3B8);

  // Dark Mode
  static const darkBg = Color(0xFF0F141E);
  static const darkSurface = Color(0xFF151C2C);
  static const darkOnSurface = Colors.white;
  static const darkDivider = Color(0xFF1E293B);
  static const darkCard = Color(0xFF151C2C);
  static const darkSubtext = Color(0xFF94A3B8);
  static const darkMuted = Color(0xFF475569);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final restored = await UserSession.instance.restore();
    if (!restored) {
      if (mounted) setState(() { _isLoggedIn = false; _isLoading = false; });
      return;
    }

    // Validate the stored token against the backend.
    // Use a short timeout (5s) so startup doesn't hang on cold start.
    try {
      await ApiService.instance.getDashboard(
        UserSession.instance.userId,
        UserSession.instance.token,
      ).timeout(const Duration(seconds: 5));
      if (mounted) setState(() { _isLoggedIn = true; _isLoading = false; });
    } catch (e) {
      // Token invalid, server unreachable, or timeout — handle gracefully.
      final msg = e.toString();
      final isAuthError = msg.contains('401') || msg.contains('403') ||
          msg.contains('Unauthorized') || msg.contains('Forbidden');
      if (isAuthError) {
        await UserSession.instance.clear();
        if (mounted) setState(() { _isLoggedIn = false; _isLoading = false; });
      } else {
        // Network error or timeout — trust the stored session, let user in
        if (mounted) setState(() { _isLoggedIn = true; _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        title: 'SkillUp',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        // Set system UI overlay style based on theme
        final isLight = currentMode == ThemeMode.light;
        SystemChrome.setSystemUIOverlayStyle(
          isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
        );

        return MaterialApp(
          title: 'SkillUp',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,

          // ─── Light Theme ──────────────────────────────────
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: AppColors.lightBg,
            colorScheme: const ColorScheme.light(
              primary: AppColors.cyan,
              secondary: AppColors.cyanDark,
              surface: AppColors.lightSurface,
              onSurface: AppColors.lightOnSurface,
              outline: AppColors.lightDivider,
            ),
            dividerColor: AppColors.lightDivider,
            cardColor: AppColors.lightCard,
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.lightBg,
              foregroundColor: AppColors.lightOnSurface,
              elevation: 0,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: AppColors.lightBg,
              hintStyle: const TextStyle(color: AppColors.lightMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.lightDivider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.lightDivider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cyan, width: 2),
              ),
            ),
            useMaterial3: true,
          ),

          // ─── Dark Theme ───────────────────────────────────
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.darkBg,
            colorScheme: const ColorScheme.dark(
              primary: AppColors.cyan,
              secondary: AppColors.cyanDark,
              surface: AppColors.darkSurface,
              onSurface: AppColors.darkOnSurface,
              outline: AppColors.darkDivider,
            ),
            dividerColor: AppColors.darkDivider,
            cardColor: AppColors.darkCard,
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.darkBg,
              foregroundColor: AppColors.darkOnSurface,
              elevation: 0,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: AppColors.darkSurface,
              hintStyle: const TextStyle(color: AppColors.darkMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.darkDivider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.darkDivider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cyan, width: 2),
              ),
            ),
            useMaterial3: true,
          ),

          home: _isLoggedIn ? const MainShell() : const LoginPage(),
        );
      },
    );
  }
}
