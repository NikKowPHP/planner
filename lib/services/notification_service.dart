import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const LinuxInitializationSettings linuxSettings = 
        LinuxInitializationSettings(defaultActionName: 'Open');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(initSettings);

    // Create Android Channel (Required for Android 8.0+)
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            'glassy_updates',
            'Glassy App Updates',
            description: 'Notifications for tasks and habits',
            importance: Importance.high,
          ));
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'glassy_updates',
      'Glassy App Updates',
      importance: Importance.high,
      priority: Priority.high,
    );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _plugin.show(
      DateTime.now().millisecond, // Random ID
      title,
      body,
      details,
      payload: payload,
    );
  }
}
