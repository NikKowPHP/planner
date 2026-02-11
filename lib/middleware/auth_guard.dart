import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../screens/auth/login_page.dart';
import '../theme/glass_theme.dart';

class AuthGuard extends ConsumerWidget {
  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authUserProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const LoginPage();
        }
        return child;
      },
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0F0F0F), // Match liquid background base
        body: Center(child: CircularProgressIndicator(color: GlassTheme.accentColor))
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, color: Colors.white38, size: 48),
              const SizedBox(height: 16),
              Text('Connection Error: $err', style: const TextStyle(color: Colors.white70)),
              TextButton(
                onPressed: () => ref.invalidate(authUserProvider),
                child: const Text('Retry Connection'),
              )
            ],
          )
        )
      ),
    );
  }
}
