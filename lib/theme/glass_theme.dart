import 'package:flutter/material.dart';
import 'dart:ui';

class GlassTheme {
  // Colors
  static const Color scaffoldBackground = Color(0xFF0F0F0F); // Deep dark background
  static const Color primaryGradientStart = Color(0xFF8E2DE2);
  static const Color primaryGradientEnd = Color(0xFF4A00E0);
  
  static const Color accentColor = Color(0xFF00C6FB);

  // Glass Colors (White with opacity)
  static const Color glassWhite10 = Color.fromRGBO(255, 255, 255, 0.1);
  static const Color glassWhite20 = Color.fromRGBO(255, 255, 255, 0.2);
  static const Color glassWhite05 = Color.fromRGBO(255, 255, 255, 0.05);

  // Borders
  static final BorderSide glassBorder = BorderSide(
    color: Colors.white.withOpacity(0.2),
    width: 1.5,
  );

  // Gradients
  static const LinearGradient liquidGradient = LinearGradient(
    colors: [primaryGradientStart, primaryGradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Blur
  static const double blurAmount = 15.0;
  static const double borderRadius = 24.0;
}
