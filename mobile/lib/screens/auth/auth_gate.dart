import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../main_navigation_screen.dart';
import 'login_screen.dart';
import 'splash_auth_screen.dart';

/// Central AuthGate: listens to Authentication state and smoothly
/// routes between [LoginScreen] and [MainNavigationScreen] without auth flashes.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        // Initializing / checking persistent session
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashAuthScreen(message: 'Checking existing session...');
        }

        // Authenticated user session found
        if (snapshot.hasData && snapshot.data != null) {
          return const MainNavigationScreen();
        }

        // Unauthenticated -> Login
        return const LoginScreen();
      },
    );
  }
}
