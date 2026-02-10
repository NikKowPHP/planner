import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_page.dart';

import 'utils/ui_utils.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  UIUtils.configureSystemUI();
  runApp(const GlassyApp());
}

class GlassyApp extends StatelessWidget {
  const GlassyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Glassy App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, // Using our custom dark glass theme
      themeMode: ThemeMode.dark,
      home: const HomePage(),
    );
  }
}
