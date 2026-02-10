import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_page.dart';

class AuthGuard extends StatelessWidget {
  final Widget child;

  const AuthGuard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!authProvider.isAuthenticated) {
          return const LoginPage();
        }

        return child;
      },
    );
  }
}
