import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UIUtils {
  static void configureSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, 
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    
    // Enable edge-to-edge on Android 10+
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
