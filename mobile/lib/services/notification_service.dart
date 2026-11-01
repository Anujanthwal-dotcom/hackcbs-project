import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Manages local push notifications using flutter_local_notifications.
///
/// FCM server-side sending can be added on top of this service later.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'krishi_alerts';
  static const _channelName = 'Agricultural Alerts';
  static const _channelDesc = 'Weather and disease risk alerts from KisaanBandhu';

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('[NotificationService] Initialized.');
  }

  void _onNotificationTap(NotificationResponse details) {
    debugPrint('[NotificationService] Notification tapped: ${details.payload}');
    // Navigation to AssistantScreen can be triggered here via a global navigator key
  }

  /// Show an agricultural alert notification.
  Future<void> showAlert({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(id, title, body, details, payload: payload);
    debugPrint('[NotificationService] Showed notification: "$title"');
  }

  Future<void> cancelAll() async => _plugin.cancelAll();
}
