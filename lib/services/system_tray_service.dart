import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../providers/focus_provider.dart';
import '../providers/app_providers.dart';
import 'logger.dart';

class SystemTrayService with WindowListener, TrayListener {
  static final SystemTrayService _instance = SystemTrayService._internal();
  factory SystemTrayService() => _instance;
  SystemTrayService._internal();

  late ProviderContainer _container;
  final FileLogger _logger = FileLogger();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  FocusState? _lastState; // NEW: Track state to detect transitions for notifications

  Future<void> init(ProviderContainer container) async {
    _container = container;
    // Only run on Desktop platforms
    if (!isDesktop) return;

    try {
      await windowManager.ensureInitialized();
      await _initNotifications();
      
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

      // NEW: Listen to focus state changes to update tooltip
      _container.listen<AsyncValue<FocusState>>(
        focusProvider,
        (previous, next) {
          next.whenData((state) {
            _updateTrayTooltip(state);
            
            // NEW: Notification Logic based on state transitions
            if (_lastState != null) {
              _handleFocusNotifications(_lastState!, state);
            }
            _lastState = state;
          });
        },
        fireImmediately: true,
      );

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

  Future<void> _initNotifications() async {
    const LinuxInitializationSettings linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');
    const InitializationSettings initSettings = InitializationSettings(linux: linuxSettings);
    await _notifications.initialize(initSettings);
  }

  bool get isDesktop => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  Future<void> _setupTray({FocusState? state}) async {
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

      // Create dynamic label based on state
      String timerLabel = 'Start Pomodoro';
      if (state != null && state.remainingSeconds > 0) {
        final minutes = state.remainingSeconds ~/ 60;
        final seconds = state.remainingSeconds % 60;
        final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        timerLabel = state.isRunning ? 'Focusing: $timeStr' : 'Paused: $timeStr';
      }

      Menu menu = Menu(
        items: [
          MenuItem(
            key: 'start_pomo',
            label: timerLabel,
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'show_window',
            label: 'Show App',
          ),
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
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'start_pomo') {
      _handleTrayStartPomo();
    } else if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      // Actually close the app
      windowManager.destroy();
    }
  }

  void _handleTrayStartPomo() async {
    final focusNotifier = _container.read(focusProvider.notifier);
    final focusState = _container.read(focusProvider).value;
    
    if (focusState == null) return;

    // 1. Logic: If no target, try to find the last one from history
    if (focusState.selectedTargetId == null) {
      final history = await _container.read(focusHistoryProvider.future);
      if (history.isNotEmpty) {
        final last = history.first;
        focusNotifier.setTarget(
          last.taskId ?? last.habitId, 
          last.taskId != null ? 'task' : 'habit'
        );
      }
    }

    // 2. Start Timer
    if (!focusState.isRunning) {
      focusNotifier.toggleTimer();
      _sendNotification("Focus Started", "Timer is now running.");
    }
  }

  void _sendNotification(String title, String body) async {
    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();
    const NotificationDetails details = NotificationDetails(linux: linuxDetails);
    await _notifications.show(0, title, body, details);
  }

  @override
  void onWindowClose() async {
    // Intercept close event
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      windowManager.hide();
    }
  }

  // NEW METHOD: Update tray tooltip based on focus state
  Future<void> _updateTrayTooltip(FocusState state) async {
    if (!isDesktop) return;

    final minutes = state.remainingSeconds ~/ 60;
    final seconds = state.remainingSeconds % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    // 1. Update Menu (Works on Linux)
    // Only update menu every 5 seconds or when paused/started to avoid DBus spam
    if (state.remainingSeconds % 5 == 0 || !state.isRunning) {
      await _setupTray(state: state);
    }

    // 2. Update Tooltip (Safe Check)
    try {
      // Tooltips are not supported on Linux app indicators
      if (Platform.isLinux) return; 

      String tooltip = state.isRunning 
          ? (state.isStopwatch ? 'Stopwatch: $timeStr' : 'Focus Remaining: $timeStr')
          : 'Glassy Focus (Paused)';
      
      await trayManager.setToolTip(tooltip);
    } catch (e) {
      // Silently catch MissingPluginException on platforms that don't support tooltips
    }
  }

  // NEW METHOD: Handle CRUD notifications for Focus
  void _handleFocusNotifications(FocusState prev, FocusState next) {
    if (!isDesktop) return;

    // 1. Started
    if (!prev.isRunning && next.isRunning) {
      _sendNotification("Focus Started", "Timer is now running.");
    }
    // 2. Paused or Finished
    else if (prev.isRunning && !next.isRunning) {
      if (!next.isStopwatch && next.remainingSeconds == 0) {
        _sendNotification("Session Finished", "Great job! Time for a break.");
      } else {
        _sendNotification("Focus Paused", "Timer has been paused.");
      }
    }
    // 3. Reset
    else if (!prev.isRunning && !next.isRunning && 
             prev.remainingSeconds != next.remainingSeconds && 
             next.remainingSeconds == (next.isStopwatch ? 0 : 25 * 60)) {
      _sendNotification("Timer Reset", "The focus session has been reset.");
    }
  }
}
