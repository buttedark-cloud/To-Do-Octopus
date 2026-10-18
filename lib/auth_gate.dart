import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:to_do/features/navigation/navigation_screen.dart';
import 'auth_screen.dart';

/// Показывает экран входа/регистрации, если пользователь не авторизован,
/// и основное приложение — если уже вошёл. Слушает Firebase напрямую,
/// поэтому переключение происходит само, без ручной навигации.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFFFF8E1),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF9800)),
            ),
          );
        }
        if (snapshot.hasData) {
          return const MainNavigationScreen();
        }
        return const AuthScreen();
      },
    );
  }
}
