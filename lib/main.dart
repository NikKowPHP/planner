import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_page.dart';
import 'utils/ui_utils.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'middleware/auth_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseConfig.initialize();
  
  UIUtils.configureSystemUI();
  runApp(const GlassyApp());
}

class GlassyApp extends StatelessWidget {
  const GlassyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Glassy App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const AuthGuard(
          child: HomePage(),
        ),
      ),
    );
  }
}
