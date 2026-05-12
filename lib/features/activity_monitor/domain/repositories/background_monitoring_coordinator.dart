import '../entities/activity_monitor_settings.dart';
import '../entities/activity_session.dart';
import '../entities/background_monitoring_status.dart';

abstract interface class BackgroundMonitoringCoordinator {
  Stream<BackgroundMonitoringStatus> get statuses;

  Future<BackgroundMonitoringStatus> currentStatus();

  Future<BackgroundMonitoringStatus> scheduleWeekdayMonitoring();

  Future<ActivitySession> startWindow(ActivityMonitorSettings settings);

  Future<ActivitySession> stopAndEvaluate(ActivityMonitorSettings settings);

  Future<bool> openExactAlarmSettings();

  Future<void> cancelSchedule();

  Future<void> dispose();
}
