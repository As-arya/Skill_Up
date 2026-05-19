import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    _initialized = true;
  }

  // Called from main.dart — ensures init happens at app start
  Future<void> init() => _ensureInitialized();

  Future<bool> requestPermission() async {
    // Request standard notification permission
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      status = await Permission.notification.request();
    }

    // Explicitly request exact alarms permission on Android 12+ 
    // to ensure exact scheduling is not blocked by Doze mode restrictions
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestExactAlarmsPermission();
    }

    return status.isGranted;
  }

  Future<void> scheduleLearningReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await _ensureInitialized();

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // If the time has already passed today, schedule for tomorrow
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Debug: print to terminal so we can verify the scheduled time
    // ignore: avoid_print
    print('[NotificationService] Scheduling notification id=$id '
        'for $scheduledDate (local timezone: ${tz.local.name})');

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'learning_reminders',
      'Learning Reminders',
      channelDescription: 'Notifications to remind you to learn your skills',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> showImmediateTestNotification() async {
    await _ensureInitialized();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'learning_reminders',
      'Learning Reminders',
      channelDescription: 'Notifications to remind you to learn your skills',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: 'Notifications Active!',
      body: 'Your SkillUp reminders have been successfully set up.',
      notificationDetails: platformDetails,
    );
  }

  Future<void> cancelAllNotifications() async {
    await _ensureInitialized();
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
