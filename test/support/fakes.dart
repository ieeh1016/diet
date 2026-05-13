import 'dart:async';

import 'package:diet/core/permissions/permission_snapshot.dart';
import 'package:diet/core/time/clock.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_evaluation.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_monitor_settings.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_session.dart';
import 'package:diet/features/activity_monitor/domain/entities/alert_delivery_result.dart';
import 'package:diet/features/activity_monitor/domain/entities/background_monitoring_status.dart';
import 'package:diet/features/activity_monitor/domain/entities/gps_point.dart';
import 'package:diet/features/activity_monitor/domain/entities/health_connect_step_status.dart';
import 'package:diet/features/activity_monitor/domain/repositories/activity_sensor_repository.dart';
import 'package:diet/features/activity_monitor/domain/repositories/activity_session_store.dart';
import 'package:diet/features/activity_monitor/domain/repositories/alert_repository.dart';
import 'package:diet/features/activity_monitor/domain/repositories/background_monitoring_coordinator.dart';
import 'package:diet/features/activity_monitor/domain/repositories/onboarding_repository.dart';
import 'package:diet/features/activity_monitor/domain/repositories/permission_repository.dart';
import 'package:diet/features/activity_monitor/domain/repositories/settings_repository.dart';
import 'package:diet/platform/health/health_connect_platform_service.dart';

class FakeClock implements Clock {
  FakeClock(this.value);

  DateTime value;

  @override
  DateTime now() => value;
}

class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository(this.settings);

  ActivityMonitorSettings settings;

  @override
  Future<ActivityMonitorSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(ActivityMonitorSettings settings) async {
    this.settings = settings;
  }
}

class FakeSensorRepository implements ActivitySensorRepository {
  final stepController = StreamController<int>.broadcast();
  final gpsController = StreamController<GpsPoint>.broadcast();

  @override
  Stream<int> get cumulativeStepCounts => stepController.stream;

  @override
  Stream<GpsPoint> get gpsPoints => gpsController.stream;

  Future<void> dispose() async {
    await stepController.close();
    await gpsController.close();
  }
}

class FakeOnboardingRepository implements OnboardingRepository {
  FakeOnboardingRepository({this.completed = false});

  bool completed;
  var markCompletedCount = 0;
  var resetCount = 0;

  @override
  Future<bool> isCompleted() async => completed;

  @override
  Future<void> markCompleted() async {
    completed = true;
    markCompletedCount += 1;
  }

  @override
  Future<void> reset() async {
    completed = false;
    resetCount += 1;
  }
}

class FakeSessionStore implements ActivitySessionStore {
  ActivitySession session = const ActivitySession.idle();
  GpsPoint? lastPoint;
  int? baseline;
  String? evaluatedDateKey;
  String? alertAttemptedDateKey;

  @override
  Future<void> clearActiveTracking() async {
    lastPoint = null;
    baseline = null;
  }

  @override
  Future<String?> loadEvaluatedDateKey() async => evaluatedDateKey;

  @override
  Future<String?> loadAlertAttemptedDateKey() async => alertAttemptedDateKey;

  @override
  Future<GpsPoint?> loadLastReliablePoint() async => lastPoint;

  @override
  Future<ActivitySession> loadSession() async => session;

  @override
  Future<int?> loadStepBaseline() async => baseline;

  @override
  Future<void> saveEvaluatedDateKey(String dateKey) async {
    evaluatedDateKey = dateKey;
  }

  @override
  Future<void> saveAlertAttemptedDateKey(String dateKey) async {
    alertAttemptedDateKey = dateKey;
  }

  @override
  Future<void> saveLastReliablePoint(GpsPoint point) async {
    lastPoint = point;
  }

  @override
  Future<void> saveSession(ActivitySession session) async {
    this.session = session;
  }

  @override
  Future<void> saveStepBaseline(int baseline) async {
    this.baseline = baseline;
  }
}

class FakeBackgroundMonitoringCoordinator
    implements BackgroundMonitoringCoordinator {
  final controller = StreamController<BackgroundMonitoringStatus>.broadcast();
  BackgroundMonitoringStatus status =
      const BackgroundMonitoringStatus.initial();
  ActivitySession startSession = ActivitySession.active(
    DateTime(2026, 5, 11, 11),
  );
  ActivitySession evaluationSession = ActivitySession(
    status: ActivitySessionStatus.evaluated,
    startedAt: DateTime(2026, 5, 11, 11),
    endedAt: DateTime(2026, 5, 11, 13),
    steps: 5,
    distanceMeters: 10,
    evaluation: null,
  );
  var scheduleCount = 0;
  var startCount = 0;
  var evaluateCount = 0;
  var cancelCount = 0;
  var openExactAlarmSettingsCount = 0;

  @override
  Stream<BackgroundMonitoringStatus> get statuses => controller.stream;

  @override
  Future<void> cancelSchedule() async {
    cancelCount += 1;
  }

  @override
  Future<BackgroundMonitoringStatus> currentStatus() async => status;

  @override
  Future<void> dispose() async {
    await controller.close();
  }

  @override
  Future<bool> openExactAlarmSettings() async {
    openExactAlarmSettingsCount += 1;
    return true;
  }

  @override
  Future<BackgroundMonitoringStatus> scheduleWeekdayMonitoring() async {
    scheduleCount += 1;
    controller.add(status);
    return status;
  }

  @override
  Future<ActivitySession> startWindow(ActivityMonitorSettings settings) async {
    startCount += 1;
    status = status.copyWith(lastSession: startSession);
    controller.add(status);
    return startSession;
  }

  @override
  Future<ActivitySession> stopAndEvaluate(
    ActivityMonitorSettings settings,
  ) async {
    evaluateCount += 1;
    final evaluation = ActivityEvaluation(
      steps: evaluationSession.steps,
      distanceMeters: evaluationSession.distanceMeters,
      threshold: settings.threshold,
      goalPolicy: settings.goalPolicy,
      evaluatedAt: evaluationSession.endedAt ?? DateTime(2026, 5, 11, 13),
    );
    evaluationSession = evaluationSession.copyWith(evaluation: evaluation);
    status = status.copyWith(lastSession: evaluationSession);
    controller.add(status);
    return evaluationSession;
  }
}

class FakePermissionRepository implements PermissionRepository {
  FakePermissionRepository([
    this.snapshot = const PermissionSnapshot(
      locationGranted: true,
      activityGranted: true,
      notificationGranted: true,
      smsGranted: true,
      smsRequired: true,
    ),
  ]);

  PermissionSnapshot snapshot;

  @override
  Future<PermissionSnapshot> readPermissionSnapshot() async => snapshot;

  @override
  Future<PermissionSnapshot> requestRequiredPermissions() async => snapshot;
}

class FakeHealthConnectPlatformService extends HealthConnectPlatformService {
  FakeHealthConnectPlatformService([
    this.status = const HealthConnectStepStatus(
      available: true,
      readPermissionGranted: true,
      lastReadSuccessful: true,
    ),
  ]);

  HealthConnectStepStatus status;
  var requestCount = 0;
  var openSettingsCount = 0;

  @override
  Future<HealthConnectStepStatus> currentStatus() async => status;

  @override
  Future<HealthConnectStepStatus> requestReadStepsPermission() async {
    requestCount += 1;
    return status;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCount += 1;
    return true;
  }
}

class FakeAlertRepository implements AlertRepository {
  var initializeCount = 0;
  var deliveryCount = 0;
  ActivityEvaluation? lastEvaluation;
  ActivityMonitorSettings? lastSettings;
  AlertDeliveryResult result = const AlertDeliveryResult(
    notificationShown: true,
    smsAttempted: true,
    smsSent: true,
    smsFallbackOpened: false,
  );

  @override
  Future<void> initialize() async {
    initializeCount += 1;
  }

  @override
  Future<AlertDeliveryResult> deliverEmergencyAlert({
    required ActivityMonitorSettings settings,
    required ActivityEvaluation evaluation,
  }) async {
    deliveryCount += 1;
    lastSettings = settings;
    lastEvaluation = evaluation;
    return result;
  }

  @override
  Future<AlertDeliveryResult> sendGuardianTestMessage({
    required ActivityMonitorSettings settings,
  }) async {
    deliveryCount += 1;
    lastSettings = settings;
    return result;
  }
}
