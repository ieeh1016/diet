import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ActivityNotificationService {
  ActivityNotificationService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _notificationsPlugin =
           notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  var _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _notificationsPlugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestFullScreenIntentPermission();

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> showActivityAlert({
    required String title,
    required String body,
  }) async {
    await initialize();

    await _notificationsPlugin.show(
      id: 1300,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'diet_project_alerts',
          '다이어트 프로젝트 알림',
          channelDescription: '점심시간 활동이 최소 활동 목표보다 낮을 때 보내는 높은 우선순위 알림입니다.',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          fullScreenIntent: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList(<int>[0, 1000, 500, 1000]),
          playSound: true,
          channelBypassDnd: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          presentBadge: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      payload: 'diet_project_alert',
    );
  }
}
