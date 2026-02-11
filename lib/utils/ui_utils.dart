import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io'; // Add import
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;

class UIUtils {
  static void configureSystemUI() {
    // System UI overlay is mainly for Mobile
    if (Platform.isAndroid || Platform.isIOS) {
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
}
