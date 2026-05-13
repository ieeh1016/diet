import 'package:flutter_test/flutter_test.dart';

import 'package:diet/core/time/clock.dart';
import 'package:diet/features/activity_monitor/data/repositories/device_background_monitoring_coordinator.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_monitor_settings.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_session.dart';
import 'package:diet/features/activity_monitor/domain/entities/background_monitoring_status.dart';
import 'package:diet/features/activity_monitor/domain/entities/gps_point.dart';
import 'package:diet/features/activity_monitor/domain/entities/monitoring_window.dart';
import 'package:diet/platform/background/background_monitoring_platform_service.dart';

import '../support/fakes.dart';

void main() {
  test('13시 전 수동 평가는 오늘 최종 평가로 잠그거나 문자를 보내지 않는다', () async {
    final clock = FakeClock(DateTime(2026, 5, 12, 12, 30));
    final sensors = FakeSensorRepository();
    final store = FakeSessionStore()
      ..session = ActivitySession.active(
        DateTime(2026, 5, 12, 11),
      ).copyWith(steps: 1200, distanceMeters: 900);
    final alerts = FakeAlertRepository();
    final platform = _FakeBackgroundMonitoringPlatformService(
      ActivitySession(
        status: ActivitySessionStatus.evaluated,
        startedAt: DateTime(2026, 5, 12, 11),
        endedAt: DateTime(2026, 5, 12, 12, 30),
        steps: 1200,
        distanceMeters: 900,
        evaluation: null,
      ),
    );
    final coordinator = DeviceBackgroundMonitoringCoordinator(
      clock: clock as Clock,
      sensorRepository: sensors,
      sessionStore: store,
      alertRepository: alerts,
      platformService: platform,
    );
    addTearDown(coordinator.dispose);
    addTearDown(sensors.dispose);

    final session = await coordinator.stopAndEvaluate(
      ActivityMonitorSettings.defaults,
    );

    expect(session.evaluation?.requiresAlert, isTrue);
    expect(store.evaluatedDateKey, isNull);
    expect(alerts.deliveryCount, 0);
  });

  test('GPS 이동이 너무 작으면 해당 구간 걸음수를 버린다', () async {
    final clock = FakeClock(DateTime(2026, 5, 12, 11));
    final sensors = FakeSensorRepository();
    final store = FakeSessionStore();
    final coordinator = DeviceBackgroundMonitoringCoordinator(
      clock: clock as Clock,
      sensorRepository: sensors,
      sessionStore: store,
      alertRepository: FakeAlertRepository(),
      platformService: _FakeBackgroundMonitoringPlatformService(
        ActivitySession.active(DateTime(2026, 5, 12, 11)),
      ),
    );
    addTearDown(coordinator.dispose);
    addTearDown(sensors.dispose);

    await coordinator.startWindow(ActivityMonitorSettings.defaults);
    final startedAt = DateTime(2026, 5, 12, 11);
    sensors.stepController.add(1000);
    sensors.gpsController.add(_gpsPoint(latitude: 37, timestamp: startedAt));
    await _flushEvents();
    sensors.stepController.add(1040);
    sensors.gpsController.add(
      _gpsPoint(
        latitude: 37.00005,
        timestamp: startedAt.add(const Duration(seconds: 30)),
      ),
    );
    await _flushEvents();

    final session = await store.loadSession();
    expect(session.steps, 0);
    expect(session.distanceMeters, 0);
    expect(session.rejectedStationarySegmentCount, 1);
    expect(session.ignoredStepCount, 40);
  });

  test('보행 가능한 GPS 이동일 때만 해당 구간 걸음수를 반영한다', () async {
    final clock = FakeClock(DateTime(2026, 5, 12, 11));
    final sensors = FakeSensorRepository();
    final store = FakeSessionStore();
    final coordinator = DeviceBackgroundMonitoringCoordinator(
      clock: clock as Clock,
      sensorRepository: sensors,
      sessionStore: store,
      alertRepository: FakeAlertRepository(),
      platformService: _FakeBackgroundMonitoringPlatformService(
        ActivitySession.active(DateTime(2026, 5, 12, 11)),
      ),
    );
    addTearDown(coordinator.dispose);
    addTearDown(sensors.dispose);

    await coordinator.startWindow(ActivityMonitorSettings.defaults);
    final startedAt = DateTime(2026, 5, 12, 11);
    sensors.stepController.add(1000);
    sensors.gpsController.add(_gpsPoint(latitude: 37, timestamp: startedAt));
    await _flushEvents();
    sensors.stepController.add(1040);
    sensors.gpsController.add(
      _gpsPoint(
        latitude: 37.00038,
        timestamp: startedAt.add(const Duration(seconds: 30)),
      ),
    );
    await _flushEvents();

    final session = await store.loadSession();
    expect(session.steps, 40);
    expect(session.distanceMeters, greaterThan(40));
    expect(session.distanceMeters, lessThan(45));
    expect(session.acceptedGpsSegmentCount, 1);
    expect(session.rejectedGpsSegmentCount, 0);
  });

  test('GPS 이동이 너무 크면 탑승 등 이상 상태로 보고 걸음수를 버린다', () async {
    final clock = FakeClock(DateTime(2026, 5, 12, 11));
    final sensors = FakeSensorRepository();
    final store = FakeSessionStore();
    final coordinator = DeviceBackgroundMonitoringCoordinator(
      clock: clock as Clock,
      sensorRepository: sensors,
      sessionStore: store,
      alertRepository: FakeAlertRepository(),
      platformService: _FakeBackgroundMonitoringPlatformService(
        ActivitySession.active(DateTime(2026, 5, 12, 11)),
      ),
    );
    addTearDown(coordinator.dispose);
    addTearDown(sensors.dispose);

    await coordinator.startWindow(ActivityMonitorSettings.defaults);
    final startedAt = DateTime(2026, 5, 12, 11);
    sensors.stepController.add(1000);
    sensors.gpsController.add(_gpsPoint(latitude: 37, timestamp: startedAt));
    await _flushEvents();
    sensors.stepController.add(1040);
    sensors.gpsController.add(
      _gpsPoint(
        latitude: 37.001,
        timestamp: startedAt.add(const Duration(seconds: 30)),
      ),
    );
    await _flushEvents();

    final session = await store.loadSession();
    expect(session.steps, 0);
    expect(session.distanceMeters, 0);
    expect(session.rejectedFastSegmentCount, 1);
    expect(session.ignoredStepCount, 40);
  });

  test('GPS 정확도가 낮으면 해당 샘플과 걸음수를 제외한다', () async {
    final clock = FakeClock(DateTime(2026, 5, 12, 11));
    final sensors = FakeSensorRepository();
    final store = FakeSessionStore();
    final coordinator = DeviceBackgroundMonitoringCoordinator(
      clock: clock as Clock,
      sensorRepository: sensors,
      sessionStore: store,
      alertRepository: FakeAlertRepository(),
      platformService: _FakeBackgroundMonitoringPlatformService(
        ActivitySession.active(DateTime(2026, 5, 12, 11)),
      ),
    );
    addTearDown(coordinator.dispose);
    addTearDown(sensors.dispose);

    await coordinator.startWindow(ActivityMonitorSettings.defaults);
    sensors.stepController.add(1000);
    await _flushEvents();
    sensors.stepController.add(1030);
    sensors.gpsController.add(
      _gpsPoint(
        latitude: 37,
        timestamp: DateTime(2026, 5, 12, 11, 0, 30),
        accuracyMeters: 80,
      ),
    );
    await _flushEvents();

    final session = await store.loadSession();
    expect(session.rejectedPoorAccuracySampleCount, 1);
    expect(session.ignoredStepCount, 30);
    expect(session.steps, 0);
  });

  test('11시부터 30분 평균 고도를 기준으로 이후 획득고도를 계산한다', () async {
    final clock = FakeClock(DateTime(2026, 5, 12, 11));
    final sensors = FakeSensorRepository();
    final store = FakeSessionStore();
    final coordinator = DeviceBackgroundMonitoringCoordinator(
      clock: clock as Clock,
      sensorRepository: sensors,
      sessionStore: store,
      alertRepository: FakeAlertRepository(),
      platformService: _FakeBackgroundMonitoringPlatformService(
        ActivitySession.active(DateTime(2026, 5, 12, 11)),
      ),
    );
    addTearDown(coordinator.dispose);
    addTearDown(sensors.dispose);

    await coordinator.startWindow(ActivityMonitorSettings.defaults);
    final startedAt = DateTime(2026, 5, 12, 11);
    sensors.gpsController.add(
      _gpsPoint(latitude: 37, timestamp: startedAt, altitude: 100),
    );
    await _flushEvents();
    sensors.gpsController.add(
      _gpsPoint(
        latitude: 37.00038,
        timestamp: startedAt.add(const Duration(minutes: 20)),
        altitude: 110,
      ),
    );
    await _flushEvents();
    sensors.gpsController.add(
      _gpsPoint(
        latitude: 37.00076,
        timestamp: startedAt.add(const Duration(minutes: 35)),
        altitude: 160,
      ),
    );
    await _flushEvents();

    final session = await store.loadSession();
    expect(session.baselineAltitudeMeters, 105);
    expect(session.elevationGainMeters, 55);
  });

  test('13시 이후 최종 평가는 날짜를 저장하고 보호자 알림을 보낸다', () async {
    final clock = FakeClock(DateTime(2026, 5, 12, 13));
    final sensors = FakeSensorRepository();
    final store = FakeSessionStore()
      ..session = ActivitySession.active(
        DateTime(2026, 5, 12, 11),
      ).copyWith(steps: 1200, distanceMeters: 900);
    final alerts = FakeAlertRepository();
    final platform = _FakeBackgroundMonitoringPlatformService(
      ActivitySession(
        status: ActivitySessionStatus.evaluated,
        startedAt: DateTime(2026, 5, 12, 11),
        endedAt: DateTime(2026, 5, 12, 13),
        steps: 1200,
        distanceMeters: 900,
        evaluation: null,
      ),
    );
    final coordinator = DeviceBackgroundMonitoringCoordinator(
      clock: clock as Clock,
      sensorRepository: sensors,
      sessionStore: store,
      alertRepository: alerts,
      platformService: platform,
    );
    addTearDown(coordinator.dispose);
    addTearDown(sensors.dispose);

    final session = await coordinator.stopAndEvaluate(
      ActivityMonitorSettings.defaults,
    );

    expect(session.evaluation?.requiresAlert, isTrue);
    expect(store.evaluatedDateKey, '2026-5-12');
    expect(store.alertAttemptedDateKey, '2026-5-12');
    expect(alerts.deliveryCount, 1);
  });

  test('이미 최종 평가한 날에는 보호자 알림을 중복으로 보내지 않는다', () async {
    final clock = FakeClock(DateTime(2026, 5, 12, 13, 10));
    final sensors = FakeSensorRepository();
    final store = FakeSessionStore()
      ..evaluatedDateKey = '2026-5-12'
      ..session = ActivitySession.active(
        DateTime(2026, 5, 12, 11),
      ).copyWith(steps: 1200, distanceMeters: 900);
    final alerts = FakeAlertRepository();
    final platform = _FakeBackgroundMonitoringPlatformService(
      ActivitySession(
        status: ActivitySessionStatus.evaluated,
        startedAt: DateTime(2026, 5, 12, 11),
        endedAt: DateTime(2026, 5, 12, 13, 10),
        steps: 1200,
        distanceMeters: 900,
        evaluation: null,
      ),
    );
    final coordinator = DeviceBackgroundMonitoringCoordinator(
      clock: clock as Clock,
      sensorRepository: sensors,
      sessionStore: store,
      alertRepository: alerts,
      platformService: platform,
    );
    addTearDown(coordinator.dispose);
    addTearDown(sensors.dispose);

    await coordinator.stopAndEvaluate(ActivityMonitorSettings.defaults);

    expect(store.evaluatedDateKey, '2026-5-12');
    expect(store.alertAttemptedDateKey, '2026-5-12');
    expect(alerts.deliveryCount, 0);
  });
}

GpsPoint _gpsPoint({
  required double latitude,
  required DateTime timestamp,
  double? altitude,
  double accuracyMeters = 8,
}) {
  return GpsPoint(
    latitude: latitude,
    longitude: 127,
    accuracyMeters: accuracyMeters,
    timestamp: timestamp,
    altitudeMeters: altitude,
    altitudeAccuracyMeters: altitude == null ? null : 8,
  );
}

Future<void> _flushEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeBackgroundMonitoringPlatformService
    extends BackgroundMonitoringPlatformService {
  _FakeBackgroundMonitoringPlatformService(this.session);

  ActivitySession session;
  var scheduleCount = 0;
  var stopAndEvaluateCount = 0;

  @override
  Future<BackgroundMonitoringStatus> currentStatus() async {
    return const BackgroundMonitoringStatus.initial().copyWith(
      isNativeAvailable: true,
      lastSession: session,
    );
  }

  @override
  Future<BackgroundMonitoringStatus> scheduleWeekdayMonitoring(
    MonitoringWindow window,
  ) async {
    scheduleCount += 1;
    return const BackgroundMonitoringStatus.initial().copyWith(
      isScheduled: true,
      isNativeAvailable: true,
      lastSession: session,
    );
  }

  @override
  Future<ActivitySession> startWindow(MonitoringWindow window) async {
    return session;
  }

  @override
  Future<ActivitySession> stopAndEvaluate(
    MonitoringWindow window, {
    bool nativeEvaluate = false,
  }) async {
    stopAndEvaluateCount += 1;
    return session;
  }
}
