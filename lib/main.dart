// VOLLSTÄNDIG ERSETZEN: lib/main.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/main/main_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'screens/update_password_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  runApp(const NestApp());
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices =>
      {PointerDeviceKind.touch, PointerDeviceKind.mouse};
}

class NestApp extends StatelessWidget {
  const NestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEST Hamburg',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      home: const AuthRedirect(),
    );
  }
}

class AuthRedirect extends StatefulWidget {
  const AuthRedirect({super.key});
  @override
  State<AuthRedirect> createState() => _AuthRedirectState();
}

class _AuthRedirectState extends State<AuthRedirect> {
  bool? _showOnboarding;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    setState(() {
      _showOnboarding = !hasSeenOnboarding;
    });
  }

  void _onOnboardingFinished() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_showOnboarding!) {
      // HIER WIRD DIE onFinished FUNKTION NUN KORREKT ÜBERGEBEN
      return OnboardingScreen(onFinished: _onOnboardingFinished);
    }

    return StreamBuilder<AuthState>(
      stream: _supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data?.session != null) {
          return const MainScreen(); // Wir benutzen immer noch den Dummy-Screen
        }
        return const LoginScreen();
      },
    );
  }
}
// This is a test to see if Git tracks my changes.
