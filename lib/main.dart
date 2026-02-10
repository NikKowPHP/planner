import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'screens/home_page.dart';
import 'utils/ui_utils.dart';
import 'config/supabase_config.dart';
import 'middleware/auth_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseConfig.initialize();
  
  UIUtils.configureSystemUI();
  // Wrap app in ProviderScope for Riverpod
  runApp(const ProviderScope(child: GlassyApp()));
}

class GlassyApp extends StatelessWidget {
  const GlassyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glassy App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const AuthGuard(child: HomePage(),
      ),
    );
  }
}
