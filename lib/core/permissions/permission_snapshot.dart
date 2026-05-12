class PermissionSnapshot {
  const PermissionSnapshot({
    required this.locationGranted,
    required this.activityGranted,
    required this.notificationGranted,
    required this.smsGranted,
    required this.smsRequired,
  });

  const PermissionSnapshot.unknown()
    : locationGranted = false,
      activityGranted = false,
      notificationGranted = false,
      smsGranted = false,
      smsRequired = false;

  final bool locationGranted;
  final bool activityGranted;
  final bool notificationGranted;
  final bool smsGranted;
  final bool smsRequired;

  bool get requiredPermissionsGranted =>
      locationGranted &&
      activityGranted &&
      notificationGranted &&
      (!smsRequired || smsGranted);

  List<String> get missingLabels {
    final labels = <String>[];
    if (!locationGranted) {
      labels.add('위치');
    }
    if (!activityGranted) {
      labels.add('활동');
    }
    if (!notificationGranted) {
      labels.add('알림');
    }
    if (smsRequired && !smsGranted) {
      labels.add('문자');
    }
    return labels;
  }

  PermissionSnapshot copyWith({
    bool? locationGranted,
    bool? activityGranted,
    bool? notificationGranted,
    bool? smsGranted,
    bool? smsRequired,
  }) {
    return PermissionSnapshot(
      locationGranted: locationGranted ?? this.locationGranted,
      activityGranted: activityGranted ?? this.activityGranted,
      notificationGranted: notificationGranted ?? this.notificationGranted,
      smsGranted: smsGranted ?? this.smsGranted,
      smsRequired: smsRequired ?? this.smsRequired,
    );
  }
}
