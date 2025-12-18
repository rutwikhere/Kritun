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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Supabase
  await supa.Supabase.initialize(
    url: 'https://bzvbdagelpnvxuxslxyx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ6dmJkYWdlbHBudnh1eHNseHl4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5NDY3NDMsImV4cCI6MjA4MDUyMjc0M30.kmd7rIhNIrgLlK1T_LLgJPBJCZb8q-K0DTNUDF8AYeI',
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

      // ✅ Directly show AuthGate as first Flutter screen
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
///  AUTH GATE
///  - If user logged in  -> HomeShell
///  - If not logged in   -> LoginScreen
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
