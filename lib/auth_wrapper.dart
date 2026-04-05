import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/admin/questionnaire_list_screen.dart';
import 'screens/user/questionnaire_list_screen.dart' as user;

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authSnapshot.data == null) {
          return const LoginScreen();
        }

        return FutureBuilder<String?>(
          future: authService.getUserRole(authSnapshot.data!.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            switch (roleSnapshot.data) {
              case 'admin':
                return AdminQuestionnaireListScreen();
              case 'approved':
                return user.UserQuestionnaireListScreen();
              case 'rejected':
                return PendingScreen(isRejected: true);
              default:
                return PendingScreen();
            }
          },
        );
      },
    );
  }
}