import 'activity_session.dart';

enum BackgroundMonitoringMode { foregroundOnly, scheduled, running, degraded }

class BackgroundMonitoringStatus {
  const BackgroundMonitoringStatus({
    required this.mode,
    required this.isScheduled,
    required this.isNativeAvailable,
    required this.exactAlarmAvailable,
    required this.locationAlwaysGranted,
    required this.lastSession,
    this.degradedReason,
  });

  const BackgroundMonitoringStatus.initial()
    : mode = BackgroundMonitoringMode.foregroundOnly,
      isScheduled = false,
      isNativeAvailable = false,
      exactAlarmAvailable = false,
      locationAlwaysGranted = false,
      lastSession = const ActivitySession.idle(),
      degradedReason = null;

  final BackgroundMonitoringMode mode;
  final bool isScheduled;
  final bool isNativeAvailable;
  final bool exactAlarmAvailable;
  final bool locationAlwaysGranted;
  final ActivitySession lastSession;
  final String? degradedReason;

  bool get isDegraded =>
      degradedReason != null || mode == BackgroundMonitoringMode.degraded;

  BackgroundMonitoringStatus copyWith({
    BackgroundMonitoringMode? mode,
    bool? isScheduled,
    bool? isNativeAvailable,
    bool? exactAlarmAvailable,
    bool? locationAlwaysGranted,
    ActivitySession? lastSession,
    String? degradedReason,
    bool clearDegradedReason = false,
  }) {
    return BackgroundMonitoringStatus(
      mode: mode ?? this.mode,
      isScheduled: isScheduled ?? this.isScheduled,
      isNativeAvailable: isNativeAvailable ?? this.isNativeAvailable,
      exactAlarmAvailable: exactAlarmAvailable ?? this.exactAlarmAvailable,
      locationAlwaysGranted:
          locationAlwaysGranted ?? this.locationAlwaysGranted,
      lastSession: lastSession ?? this.lastSession,
      degradedReason: clearDegradedReason
          ? null
          : degradedReason ?? this.degradedReason,
    );
  }
}
