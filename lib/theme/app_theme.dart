import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'glass_theme.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: GlassTheme.scaffoldBackground,
      primaryColor: GlassTheme.accentColor,
      
      // Typography
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),

      // App Bar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      
      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: GlassTheme.accentColor,
        secondary: GlassTheme.primaryGradientEnd,
        surface: Colors.transparent, // Important for glass
      ),

      useMaterial3: true,
    );
  }
}
