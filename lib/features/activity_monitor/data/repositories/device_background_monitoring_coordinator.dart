import 'dart:async';
import 'dart:math' as math;

import '../../../../core/time/activity_window.dart';
import '../../../../core/time/clock.dart';
import '../../../../platform/background/background_monitoring_platform_service.dart';
import '../../domain/entities/activity_monitor_settings.dart';
import '../../domain/entities/activity_session.dart';
import '../../domain/entities/background_monitoring_status.dart';
import '../../domain/entities/gps_point.dart';
import '../../domain/entities/monitoring_window.dart';
import '../../domain/repositories/activity_sensor_repository.dart';
import '../../domain/repositories/activity_session_store.dart';
import '../../domain/repositories/alert_repository.dart';
import '../../domain/repositories/background_monitoring_coordinator.dart';
import '../../domain/use_cases/calculate_distance.dart';
import '../../domain/use_cases/classify_walking_sample.dart';
import '../../domain/use_cases/evaluate_activity.dart';
import '../../domain/use_cases/next_monitoring_window.dart';

class DeviceBackgroundMonitoringCoordinator
    implements BackgroundMonitoringCoordinator {
  DeviceBackgroundMonitoringCoordinator({
    required Clock clock,
    required ActivitySensorRepository sensorRepository,
    required ActivitySessionStore sessionStore,
    required AlertRepository alertRepository,
    required BackgroundMonitoringPlatformService platformService,
  }) : _clock = clock,
       _sensorRepository = sensorRepository,
       _sessionStore = sessionStore,
       _alertRepository = alertRepository,
       _platformService = platformService {
    _statusTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_emitCurrentStatus()),
    );
  }

  final Clock _clock;
  final ActivitySensorRepository _sensorRepository;
  final ActivitySessionStore _sessionStore;
  final AlertRepository _alertRepository;
  final BackgroundMonitoringPlatformService _platformService;
  final _window = const ActivityWindow();
  final _nextMonitoringWindow = const NextMonitoringWindow();
  final _calculateDistance = const CalculateDistance();
  final _classifyWalkingSample = const ClassifyWalkingSample();
  final _evaluateActivity = const EvaluateActivity();
  final _statusController =
      StreamController<BackgroundMonitoringStatus>.broadcast();

  Timer? _statusTimer;
  StreamSubscription<int>? _stepSubscription;
  StreamSubscription<GpsPoint>? _gpsSubscription;
  int? _stepBaseline;
  int? _latestCumulativeSteps;
  GpsPoint? _lastReliablePoint;
  double? _baselineAltitudeMeters;
  double _baselineAltitudeSum = 0;
  int _baselineAltitudeSampleCount = 0;
  var _disposed = false;

  @override
  Stream<BackgroundMonitoringStatus> get statuses => _statusController.stream;

  @override
  Future<BackgroundMonitoringStatus> currentStatus() async {
    final localSession = await _sessionStore.loadSession();
    final nativeStatus = await _platformService.currentStatus();
    final session = _mergeSessions(localSession, nativeStatus.lastSession);
    return nativeStatus.copyWith(lastSession: session);
  }

  @override
  Future<BackgroundMonitoringStatus> scheduleWeekdayMonitoring() async {
    final window = _nextMonitoringWindow(_clock.now());
    final nativeStatus = await _platformService.scheduleWeekdayMonitoring(
      window,
    );
    final status = nativeStatus.copyWith(
      isScheduled: true,
      lastSession: await _sessionStore.loadSession(),
    );
    _emit(status);
    return status;
  }

  @override
  Future<ActivitySession> startWindow(ActivityMonitorSettings settings) async {
    final now = _clock.now();
    final window = _window.isWithin(now)
        ? _windowForDate(now)
        : _nextMonitoringWindow(now);
    await _alertRepository.initialize();
    await _platformService.startWindow(window);
    await _cancelSensorSubscriptions();

    _stepBaseline = await _sessionStore.loadStepBaseline();
    _latestCumulativeSteps = _stepBaseline;
    _lastReliablePoint = await _sessionStore.loadLastReliablePoint();

    final existing = await _sessionStore.loadSession();
    _baselineAltitudeMeters = existing.baselineAltitudeMeters;
    _baselineAltitudeSum = 0;
    _baselineAltitudeSampleCount = 0;
    final startedAt = existing.startedAt ?? now;
    var session = existing.isActive
        ? existing
        : ActivitySession.active(startedAt);

    if (!_window.isWithin(now) &&
        existing.status == ActivitySessionStatus.idle) {
      session = ActivitySession.active(now);
    }

    await _sessionStore.saveSession(session);
    _stepSubscription = _sensorRepository.cumulativeStepCounts.listen(
      (steps) => unawaited(_handleStepCount(steps)),
      onError: _handleSensorError,
    );
    _gpsSubscription = _sensorRepository.gpsPoints.listen(
      (point) => unawaited(_handleGpsPoint(point)),
      onError: _handleSensorError,
    );
    await _emitCurrentStatus();
    return session;
  }

  @override
  Future<ActivitySession> stopAndEvaluate(
    ActivityMonitorSettings settings,
  ) async {
    final now = _clock.now();
    final todayKey = _dateKey(now);
    final shouldLockToday = _window.isEvaluationTime(now);
    final alreadyEvaluatedToday =
        shouldLockToday &&
        await _sessionStore.loadEvaluatedDateKey() == todayKey;
    final alertAlreadyAttemptedToday =
        shouldLockToday &&
        await _sessionStore.loadAlertAttemptedDateKey() == todayKey;
    final window = _windowForDate(now);
    final nativeSession = await _platformService.stopAndEvaluate(window);
    await _cancelSensorSubscriptions();

    final localSession = await _sessionStore.loadSession();
    final mergedSession = _mergeSessions(localSession, nativeSession);
    final evaluation = _evaluateActivity(
      steps: mergedSession.steps,
      distanceMeters: mergedSession.distanceMeters,
      elevationGainMeters: mergedSession.elevationGainMeters,
      threshold: settings.threshold,
      goalPolicy: settings.goalPolicy,
      evaluatedAt: now,
    );
    final evaluatedSession = mergedSession.copyWith(
      status: ActivitySessionStatus.evaluated,
      endedAt: now,
      evaluation: evaluation,
    );

    await _sessionStore.saveSession(evaluatedSession);
    if (shouldLockToday) {
      await _sessionStore.saveEvaluatedDateKey(todayKey);
    }
    await _sessionStore.clearActiveTracking();

    if (shouldLockToday &&
        evaluation.requiresAlert &&
        alreadyEvaluatedToday &&
        !alertAlreadyAttemptedToday) {
      await _sessionStore.saveAlertAttemptedDateKey(todayKey);
    }

    if (shouldLockToday &&
        evaluation.requiresAlert &&
        !alreadyEvaluatedToday &&
        !alertAlreadyAttemptedToday) {
      await _sessionStore.saveAlertAttemptedDateKey(todayKey);
      await _alertRepository.deliverEmergencyAlert(
        settings: settings,
        evaluation: evaluation,
      );
    }

    await scheduleWeekdayMonitoring();
    await _emitCurrentStatus();
    return evaluatedSession;
  }

  @override
  Future<bool> openExactAlarmSettings() =>
      _platformService.openExactAlarmSettings();

  @override
  Future<void> cancelSchedule() async {
    await _platformService.cancelSchedule();
    await _cancelSensorSubscriptions();
    _emit(
      (await currentStatus()).copyWith(
        mode: BackgroundMonitoringMode.foregroundOnly,
        isScheduled: false,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _statusTimer?.cancel();
    await _cancelSensorSubscriptions();
    await _statusController.close();
  }

  Future<void> _handleStepCount(int cumulativeSteps) async {
    final session = await _sessionStore.loadSession();
    if (!session.isActive) {
      return;
    }

    _latestCumulativeSteps = cumulativeSteps;
    _stepBaseline ??= cumulativeSteps;
    await _sessionStore.saveStepBaseline(_stepBaseline!);
  }

  Future<void> _handleGpsPoint(GpsPoint point) async {
    final session = await _sessionStore.loadSession();
    if (!session.isActive) {
      return;
    }
    if (!point.isReliable) {
      await _sessionStore.saveSession(
        session.copyWith(
          rejectedPoorAccuracySampleCount:
              session.rejectedPoorAccuracySampleCount + 1,
          ignoredStepCount: session.ignoredStepCount + _pendingSteps(),
        ),
      );
      await _advanceStepCheckpoint();
      await _emitCurrentStatus();
      return;
    }

    var updatedSession = _applyElevationSample(session, point);
    final lastPoint = _lastReliablePoint;
    _lastReliablePoint = point;
    await _sessionStore.saveLastReliablePoint(point);
    if (lastPoint == null) {
      await _sessionStore.saveSession(updatedSession);
      await _advanceStepCheckpoint();
      await _emitCurrentStatus();
      return;
    }

    final addedMeters = _calculateDistance.distanceBetween(lastPoint, point);
    final decision = _classifyWalkingSample(
      distanceMeters: addedMeters,
      elapsed: point.timestamp.difference(lastPoint.timestamp),
    );
    final pendingSteps = _pendingSteps();
    await _advanceStepCheckpoint();
    if (decision != WalkingSampleDecision.accepted) {
      updatedSession = switch (decision) {
        WalkingSampleDecision.tooLittleMovement => updatedSession.copyWith(
          rejectedStationarySegmentCount:
              updatedSession.rejectedStationarySegmentCount + 1,
          ignoredStepCount: updatedSession.ignoredStepCount + pendingSteps,
        ),
        WalkingSampleDecision.tooFastForWalking => updatedSession.copyWith(
          rejectedFastSegmentCount: updatedSession.rejectedFastSegmentCount + 1,
          ignoredStepCount: updatedSession.ignoredStepCount + pendingSteps,
        ),
        WalkingSampleDecision.accepted => updatedSession,
      };
      await _sessionStore.saveSession(updatedSession);
      await _emitCurrentStatus();
      return;
    }

    updatedSession = updatedSession.copyWith(
      steps: updatedSession.steps + pendingSteps,
      distanceMeters: updatedSession.distanceMeters + addedMeters,
      acceptedGpsSegmentCount: updatedSession.acceptedGpsSegmentCount + 1,
    );
    await _sessionStore.saveSession(updatedSession);
    await _emitCurrentStatus();
  }

  void _handleSensorError(Object error) {
    _emit(
      const BackgroundMonitoringStatus.initial().copyWith(
        mode: BackgroundMonitoringMode.degraded,
        degradedReason: '센서 스트림에 문제가 발생했어요: $error',
      ),
    );
  }

  Future<void> _cancelSensorSubscriptions() async {
    await _stepSubscription?.cancel();
    await _gpsSubscription?.cancel();
    _stepSubscription = null;
    _gpsSubscription = null;
  }

  int _pendingSteps() {
    final latest = _latestCumulativeSteps;
    final baseline = _stepBaseline;
    if (latest == null || baseline == null) {
      return 0;
    }
    return math.max(0, latest - baseline);
  }

  ActivitySession _applyElevationSample(
    ActivitySession session,
    GpsPoint point,
  ) {
    final altitude = point.altitudeMeters;
    final startedAt = session.startedAt;
    if (altitude == null || startedAt == null || !point.hasReliableAltitude) {
      return session;
    }

    final baselineEndsAt = startedAt.add(const Duration(minutes: 30));
    if (point.timestamp.isBefore(baselineEndsAt)) {
      _baselineAltitudeSum += altitude;
      _baselineAltitudeSampleCount += 1;
      _baselineAltitudeMeters =
          _baselineAltitudeSum / _baselineAltitudeSampleCount;
      return session.copyWith(baselineAltitudeMeters: _baselineAltitudeMeters);
    }

    final baseline =
        _baselineAltitudeMeters ?? session.baselineAltitudeMeters ?? altitude;
    _baselineAltitudeMeters = baseline;
    final elevationGain = math.max<double>(
      session.elevationGainMeters,
      math.max<double>(0, altitude - baseline),
    );
    return session.copyWith(
      baselineAltitudeMeters: baseline,
      elevationGainMeters: elevationGain,
    );
  }

  Future<void> _advanceStepCheckpoint() async {
    final latest = _latestCumulativeSteps;
    if (latest == null) {
      return;
    }
    _stepBaseline = latest;
    await _sessionStore.saveStepBaseline(latest);
  }

  Future<void> _emitCurrentStatus() async {
    if (_disposed) {
      return;
    }
    _emit(await currentStatus());
  }

  void _emit(BackgroundMonitoringStatus status) {
    if (!_disposed && !_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  ActivitySession _mergeSessions(
    ActivitySession local,
    ActivitySession native,
  ) {
    if (native.status == ActivitySessionStatus.idle) {
      return local;
    }
    if (local.status == ActivitySessionStatus.idle) {
      return native;
    }

    return local.copyWith(
      status: native.status == ActivitySessionStatus.evaluated
          ? ActivitySessionStatus.evaluated
          : local.status,
      startedAt: local.startedAt ?? native.startedAt,
      endedAt: local.endedAt ?? native.endedAt,
      steps: math.max(local.steps, native.steps),
      distanceMeters: math.max(local.distanceMeters, native.distanceMeters),
      elevationGainMeters: math.max(
        local.elevationGainMeters,
        native.elevationGainMeters,
      ),
      baselineAltitudeMeters:
          native.baselineAltitudeMeters ?? local.baselineAltitudeMeters,
      acceptedGpsSegmentCount: math.max(
        local.acceptedGpsSegmentCount,
        native.acceptedGpsSegmentCount,
      ),
      rejectedStationarySegmentCount: math.max(
        local.rejectedStationarySegmentCount,
        native.rejectedStationarySegmentCount,
      ),
      rejectedFastSegmentCount: math.max(
        local.rejectedFastSegmentCount,
        native.rejectedFastSegmentCount,
      ),
      rejectedPoorAccuracySampleCount: math.max(
        local.rejectedPoorAccuracySampleCount,
        native.rejectedPoorAccuracySampleCount,
      ),
      ignoredStepCount: math.max(
        local.ignoredStepCount,
        native.ignoredStepCount,
      ),
      evaluation: local.evaluation ?? native.evaluation,
    );
  }

  String _dateKey(DateTime dateTime) =>
      '${dateTime.year}-${dateTime.month}-${dateTime.day}';

  MonitoringWindow _windowForDate(DateTime dateTime) {
    return MonitoringWindow(
      start: _window.startFor(dateTime),
      end: _window.endFor(dateTime),
    );
  }
}
