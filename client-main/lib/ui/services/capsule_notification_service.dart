import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class CapsuleNotificationService {
  CapsuleNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'capsule_opening_channel',
    'Capsule Opening Alerts',
    description: 'Scheduled alerts when your capsule can be opened',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    if (_isInitialized) return;

    tzdata.initializeTimeZones();
    final timezoneName = await FlutterTimezone.getLocalTimezone();
    final timezoneLocation = tz.getLocation(timezoneName);
    tz.setLocalLocation(timezoneLocation);

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(initializationSettings);

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.createNotificationChannel(_channel);
    _isInitialized = true;
  }

  static Future<void> scheduleCapsuleOpeningAlert({
    required String capsuleId,
    required DateTime openAtUtc,
    required bool isGroupCapsule,
  }) async {
    await initialize();
    await _requestNotificationPermissions();

    final nowUtc = DateTime.now().toUtc();
    if (!openAtUtc.isAfter(nowUtc)) return;

    final scheduledAt = tz.TZDateTime.from(openAtUtc, tz.local);
    final notificationId = _notificationId(capsuleId);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      notificationId,
      isGroupCapsule ? '그룹 캡슐 열람 가능' : '캡슐 열람 가능',
      isGroupCapsule
          ? '설정한 시간이 되어 그룹 캡슐을 열어볼 수 있어요.'
          : '설정한 시간이 되어 캡슐을 열어볼 수 있어요.',
      scheduledAt,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: capsuleId,
    );
  }

  static Future<void> showImmediateAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );

    final id = (DateTime.now().millisecondsSinceEpoch ~/ 1000) & 0x7fffffff;
    await _plugin.show(
      id == 0 ? 1 : id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  static Future<void> _requestNotificationPermissions() async {
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.requestNotificationsPermission();

    final iosImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static int _notificationId(String capsuleId) {
    final hash = capsuleId.hashCode & 0x7fffffff;
    return hash == 0 ? 1 : hash;
  }
}
