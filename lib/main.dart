// --- Code für die aktualisierte Datei: lib/main.dart ---

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Deine Konfigurationen bleiben
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';

// Wir importieren jetzt ALLE unsere möglichen Start-Bildschirme
import 'screens/login_screen.dart';
import 'screens/update_password_screen.dart'; // <-- Unser neuer Raum

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const NestApp());
}

class NestApp extends StatelessWidget {
  const NestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEST Hamburg',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,

      // HIER IST DAS NEUE GEHIRN DER APP:
      home: StreamBuilder<AuthState>(
        // Wir lauschen auf den Authentifizierungs-Strom von Supabase
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {

          // Solange wir auf ein Signal warten, zeigen wir einen Ladekreis
          if (!snapshot.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          final event = snapshot.data!.event;
          final session = snapshot.data!.session;

          // SIGNAL 1: "PASSWORT-RESET-LINK GEKLICKT!"
          // Wenn Supabase dieses Signal sendet, zeigen wir unseren neuen Raum an.
          if (event == AuthChangeEvent.passwordRecovery) {
            return const UpdatePasswordScreen();
          }

          // SIGNAL 2: "NUTZER IST EINGELOGGT!"
          // Wenn es eine aktive Sitzung gibt, gehen wir direkt zum Home Screen.
          if (session != null) {
            return const HomeScreen();
          }

          // KEIN SIGNAL:
          // In allen anderen Fällen (Nutzer ist ausgeloggt), zeigen wir den Login Screen.
          return const LoginScreen();
        },
      ),
    );
  }
}
