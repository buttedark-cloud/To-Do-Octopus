import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';

/// Локальные push-уведомления: по задачам (дата + время на карточке) и по
/// заметкам (дата + время напоминания).
///
/// Синглтон, инициализируется один раз в main.dart до runApp().
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz.identifier));
    } catch (e) {
      // Не удалось определить часовой пояс — не роняем приложение, остаёмся
      // на UTC (уведомления придут, но время может отличаться).
      debugPrint('NotificationService: не удалось определить часовой пояс: $e');
    }

    // Отдельная бело-прозрачная силуэтная иконка для статус-бара: Android
    // не умеет превращать цветной ярлык приложения в силуэт.
    const androidInit = AndroidInitializationSettings('ic_stat_logo_octopus');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, // разрешение спрашиваем отдельно, явно
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );

    _initialized = true;
  }

  /// На Android 13+ и iOS без этого разрешения уведомления не приходят.
  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// На Android 12+ точные будильники требуют отдельного разрешения
  /// SCHEDULE_EXACT_ALARM — без него уведомление может опоздать на минуты.
  Future<void> requestExactAlarmPermissionIfNeeded() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canSchedule = await android?.canScheduleExactNotifications();
    if (canSchedule == false) {
      await android?.requestExactAlarmsPermission();
    }
  }

  // Стабильный числовой id из строкового ключа. Префикс "task_"/"note_"
  // гарантирует, что задача и заметка с одинаковым "сырым" id не затрут
  // уведомления друг друга.
  int _notificationIdFor(String key) => key.hashCode & 0x7fffffff;

  NotificationDetails _details({
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        // Маленькая иконка в статус-баре всегда бело-серая (требование
        // Android), а большая внутри уведомления может быть цветной.
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  // ---------- ЗАДАЧИ ----------

  Future<void> scheduleTaskNotification({
    required String taskId,
    required String taskTitle,
    required DateTime dueDate,
  }) async {
    if (!_initialized) return;
    if (dueDate.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id: _notificationIdFor('task_$taskId'),
      title: 'Время задачи подошло',
      body: taskTitle,
      scheduledDate: tz.TZDateTime.from(dueDate, tz.local),
      notificationDetails: _details(
        channelId: 'todo_due_channel',
        channelName: 'Напоминания о задачах',
        channelDescription: 'Уведомление приходит в момент дедлайна задачи',
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
    );
  }

  Future<void> cancelTaskNotification(String taskId) async {
    if (!_initialized) return;
    await _plugin.cancel(id: _notificationIdFor('task_$taskId'));
  }

  // ---------- ЗАМЕТКИ ----------

  Future<void> scheduleNoteNotification({
    required String noteId,
    required String noteTitle,
    required DateTime remindAt,
  }) async {
    if (!_initialized) return;
    if (remindAt.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id: _notificationIdFor('note_$noteId'),
      title: 'Напоминание по заметке',
      body: noteTitle.isEmpty ? 'Без названия' : noteTitle,
      scheduledDate: tz.TZDateTime.from(remindAt, tz.local),
      notificationDetails: _details(
        channelId: 'notes_reminder_channel',
        channelName: 'Напоминания о заметках',
        channelDescription:
            'Уведомление приходит в момент напоминания по заметке',
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
    );
  }

  Future<void> cancelNoteNotification(String noteId) async {
    if (!_initialized) return;
    await _plugin.cancel(id: _notificationIdFor('note_$noteId'));
  }
}
