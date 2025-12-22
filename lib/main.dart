import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'core/app_theme.dart';
import 'features/home/presentation/home_shell.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Supabase (sanitized)
  await supa.Supabase.initialize(
    url: 'SUPABASE_PROJECT_URL',
    anonKey: 'SUPABASE_ANON_PUBLIC_KEY',
  );

  runApp(const KritunApp());
}

class KritunApp extends StatelessWidget {
  const KritunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kritun',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,

      home: const AuthGate(),

      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeShell(),
      },
    );
  }
}

/// ----------------------------------------------------------
/// AUTH GATE
/// ----------------------------------------------------------
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        } else {
          return const HomeShell();
        }
      },
    );
  }
}
