import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'logger.dart';

class SystemTrayService with WindowListener, TrayListener {
  static final SystemTrayService _instance = SystemTrayService._internal();
  factory SystemTrayService() => _instance;
  SystemTrayService._internal();

  final FileLogger _logger = FileLogger();

  Future<void> init() async {
    // Only run on Desktop platforms
    if (!isDesktop) return;

    try {
      await windowManager.ensureInitialized();
      
      // Setup Window Options
      WindowOptions windowOptions = const WindowOptions(
        size: Size(1280, 720),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden, // Custom glass frame
      );
      
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      // Setup Tray
      await _setupTray();

      // Listeners
      windowManager.addListener(this);
      trayManager.addListener(this);

      // Prevent app from closing when X is clicked (Minimize to tray instead)
      await windowManager.setPreventClose(true);
      
      await _logger.log('SystemTrayService: Initialized successfully');
    } catch (e, s) {
      await _logger.error('SystemTrayService: Initialization failed', e, s);
    }
  }

  bool get isDesktop => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  Future<void> _setupTray() async {
    try {
      // Extract asset to file for tray icon (required on some desktop platforms)
      String iconPath = 'assets/app_icon.png';
      
      // Attempt to use a temporary file if asset exists
      try {
         final byteData = await rootBundle.load(iconPath);
         final tempDir = await getTemporaryDirectory();
         final file = File('${tempDir.path}/app_icon_tray.png');
         await file.writeAsBytes(byteData.buffer.asUint8List());
         iconPath = file.path;
      } catch (e) {
         // Fallback or ignore if asset missing, tray icon might fail or show default
         _logger.log('SystemTrayService: Icon asset missing, using default path string');
      }

      await trayManager.setIcon(iconPath);

      Menu menu = Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: 'Show App',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'Exit',
          ),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (e) {
      _logger.log('SystemTrayService: Tray setup warning: $e');
    }
  }

  @override
  void onTrayIconMouseDown() {
    // Restore window on tray click
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      // Actually close the app
      windowManager.destroy();
    }
  }

  @override
  void onWindowClose() async {
    // Intercept close event
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      windowManager.hide();
    }
  }
}
