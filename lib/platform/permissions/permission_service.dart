import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../../core/permissions/permission_snapshot.dart';

class PermissionService {
  Permission get _activityPermission =>
      Platform.isIOS ? Permission.sensors : Permission.activityRecognition;

  Future<PermissionSnapshot> readPermissionSnapshot() async {
    final location = await Permission.locationWhenInUse.status;
    final locationAlways = await Permission.locationAlways.status;
    final activity = await _activityPermission.status;
    final notification = await Permission.notification.status;
    final sms = Platform.isAndroid
        ? await Permission.sms.status
        : PermissionStatus.granted;

    return PermissionSnapshot(
      locationGranted:
          location.isGranted || location.isLimited || locationAlways.isGranted,
      activityGranted: activity.isGranted || activity.isLimited,
      notificationGranted: notification.isGranted || notification.isLimited,
      smsGranted: sms.isGranted || sms.isLimited,
      smsRequired: Platform.isAndroid,
    );
  }

  Future<PermissionSnapshot> requestRequiredPermissions() async {
    final location = await Permission.locationWhenInUse.request();
    final locationAlways = location.isGranted || location.isLimited
        ? await Permission.locationAlways.request()
        : await Permission.locationAlways.status;
    final activity = await _activityPermission.request();
    final notification = await Permission.notification.request();
    final sms = Platform.isAndroid
        ? await Permission.sms.request()
        : PermissionStatus.granted;

    return PermissionSnapshot(
      locationGranted:
          location.isGranted || location.isLimited || locationAlways.isGranted,
      activityGranted: activity.isGranted || activity.isLimited,
      notificationGranted: notification.isGranted || notification.isLimited,
      smsGranted: sms.isGranted || sms.isLimited,
      smsRequired: Platform.isAndroid,
    );
  }
}
