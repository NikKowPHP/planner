import 'dart:io';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/task.dart';
import '../providers/app_providers.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  ProviderContainer? _container;
  
  // Track Linux timers to allow cancellation
  final Map<String, Timer> _linuxReminders = {};

  Future<void> init(ProviderContainer container) async {
    _container = container;
    
    tz.initializeTimeZones();
    
    try {
      // Use flutter_timezone with a robust fallback
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      // FALLBACK: If plugin fails on Linux/Desktop, default to UTC
      // This prevents the MissingPluginException crash
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const InitializationSettings initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        _handleTap(details);
      },
    );

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

  void _handleTap(NotificationResponse details) {
    if (details.payload != null && _container != null) {
      // Find the task in the current list
      final tasks = _container!.read(tasksProvider).value ?? [];
      try {
        final task = tasks.firstWhere((t) => t.id == details.payload);
        // Set active tab to tasks and select the task
        _container!.read(homeViewProvider.notifier).setActiveTab(AppTab.tasks);
        _container!.read(homeViewProvider.notifier).selectTask(task);
      } catch (e) {
        // Task might have been deleted
      }
    }
  }

  // Schedule a notification for a specific task
  Future<void> scheduleTaskReminder(Task task) async {
    if (task.dueDate == null || task.isCompleted || task.deletedAt != null) return;
    
    final now = DateTime.now();
    if (task.dueDate!.isBefore(now)) return;

    // PLATFORM SPECIFIC LOGIC
    if (Platform.isLinux) {
      _scheduleLinuxReminder(task);
    } else {
      // Android / iOS
      final androidDetails = const AndroidNotificationDetails(
        'task_reminders',
        'Task Reminders',
        channelDescription: 'Notifications for upcoming tasks',
        importance: Importance.max,
        priority: Priority.high,
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      // We use task.id.hashCode as the notification ID to ensure uniqueness per task
      await _plugin.zonedSchedule(
        task.id.hashCode,
        'Task Reminder',
        task.title,
        tz.TZDateTime.from(task.dueDate!, tz.local),
        notificationDetails,
        payload: task.id, // CRITICAL: For identification on tap
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // Linux specific in-memory scheduler
  void _scheduleLinuxReminder(Task task) {
    _cancelLinuxReminder(task.id);
    
    final duration = task.dueDate!.difference(DateTime.now());
    _linuxReminders[task.id] = Timer(duration, () {
      showNotification(
        title: "Task Reminder",
        body: task.title,
        payload: task.id,
      );
      _linuxReminders.remove(task.id);
    });
  }

  Future<void> cancelTaskReminder(String taskId) async {
    if (Platform.isLinux) {
      _cancelLinuxReminder(taskId);
    } else {
      await _plugin.cancel(taskId.hashCode);
    }
  }

  void _cancelLinuxReminder(String taskId) {
    _linuxReminders[taskId]?.cancel();
    _linuxReminders.remove(taskId);
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
