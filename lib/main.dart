import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'screens/home_page.dart';
import 'utils/ui_utils.dart';
import 'config/supabase_config.dart';
import 'middleware/auth_guard.dart';
import 'services/system_tray_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseConfig.initialize();
  
  // Create ProviderContainer for service access
  final container = ProviderContainer();
  
  // Initialize Notification Service with container for tap handling
  await NotificationService().init(container);
  
  UIUtils.configureSystemUI();
  
  // Initialize System Tray / Window Manager for Desktop
  await SystemTrayService().init(container);

  // Wrap app in UncontrolledProviderScope to share the container
  runApp(UncontrolledProviderScope(
    container: container,
    child: const GlassyApp(),
  ));
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
