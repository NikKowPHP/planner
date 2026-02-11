import 'dart:io';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/task.dart';
import '../models/habit.dart';
import '../providers/app_providers.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  ProviderContainer? _container;
  
  // Linux Timers
  final Map<String, Timer> _activeTimers = {};

  Future<void> init(ProviderContainer container) async {
    _container = container;
    tz.initializeTimeZones();
    
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const InitializationSettings initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) => _handleTap(details),
    );

    if (Platform.isAndroid) {
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
          
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            'glassy_reminders',
            'Reminders',
            description: 'Task and Habit Reminders',
            importance: Importance.max,
            sound: RawResourceAndroidNotificationSound('notification'),
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

  // --- TASK REMINDERS (One-time) ---

  Future<void> scheduleTaskReminder(Task task) async {
    cancelReminder(task.id); // Clear old
    if (task.dueDate == null || task.isCompleted || task.deletedAt != null) return;
    
    final now = DateTime.now();
    if (task.dueDate!.isBefore(now)) return;

    if (Platform.isLinux) {
      _scheduleLinuxTimer(task.id, task.dueDate!, "Task Due", task.title);
    } else {
      await _plugin.zonedSchedule(
        task.id.hashCode,
        'Task Reminder',
        task.title,
        tz.TZDateTime.from(task.dueDate!, tz.local),
        const NotificationDetails(android: AndroidNotificationDetails(
          'glassy_reminders', 'Reminders', importance: Importance.max, priority: Priority.high,
        )),
        payload: task.id,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // --- HABIT REMINDERS (Daily) ---

  Future<void> scheduleHabitReminder(Habit habit) async {
    cancelReminder(habit.id);
    if (habit.reminderTime == null || habit.deletedAt != null) return;

    final parts = habit.reminderTime!.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    if (Platform.isLinux) {
      _scheduleLinuxDaily(habit.id, hour, minute, "Habit Reminder", "Time for: ${habit.name}");
    } else {
      // Calculate next instance
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        habit.id.hashCode,
        'Habit Reminder',
        'Time for: ${habit.name}',
        scheduledDate,
        const NotificationDetails(android: AndroidNotificationDetails(
          'glassy_reminders', 'Reminders', importance: Importance.max, priority: Priority.high,
        )),
        payload: habit.id,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // REPEATS DAILY
      );
    }
  }

  Future<void> cancelReminder(String id) async {
    if (Platform.isLinux) {
      _activeTimers[id]?.cancel();
      _activeTimers.remove(id);
    } else {
      await _plugin.cancel(id.hashCode);
    }
  }

  Future<void> cancelTaskReminder(String id) async {
    await cancelReminder(id);
  }

  // --- LINUX SPECIFIC IMPLEMENTATION ---

  void _scheduleLinuxTimer(String id, DateTime date, String title, String body) {
    final duration = date.difference(DateTime.now());
    if (duration.isNegative) return;

    _activeTimers[id] = Timer(duration, () {
      showNotification(title: title, body: body, payload: id);
      _activeTimers.remove(id);
    });
  }

  void _scheduleLinuxDaily(String id, int hour, int minute, String title, String body) {
    var target = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, hour, minute);
    if (target.isBefore(DateTime.now())) {
      target = target.add(const Duration(days: 1));
    }

    final initialDelay = target.difference(DateTime.now());
    if (initialDelay.isNegative) return;

    _activeTimers[id] = Timer(initialDelay, () {
      showNotification(title: title, body: body, payload: id);
      
      // Reschedule for 24 hours later (Recurring)
      _activeTimers[id] = Timer.periodic(const Duration(days: 1), (_) {
         showNotification(title: title, body: body, payload: id);
      });
    });
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
