import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diet/features/activity_monitor/data/repositories/shared_preferences_activity_session_store.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_session.dart';
import 'package:diet/features/activity_monitor/domain/entities/gps_point.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('session store restores active session after app restart', () async {
    final store = SharedPreferencesActivitySessionStore();
    final startedAt = DateTime(2026, 5, 11, 11);

    await store.saveSession(
      ActivitySession.active(
        startedAt,
      ).copyWith(steps: 120, distanceMeters: 345),
    );

    final restored = await store.loadSession();

    expect(restored.status, ActivitySessionStatus.active);
    expect(restored.startedAt, startedAt);
    expect(restored.steps, 120);
    expect(restored.distanceMeters, 345);
  });

  test('session store persists tracking recovery fields', () async {
    final store = SharedPreferencesActivitySessionStore();
    final point = GpsPoint(
      latitude: 37,
      longitude: 127,
      accuracyMeters: 10,
      timestamp: DateTime(2026, 5, 11, 11, 30),
    );

    await store.saveStepBaseline(1000);
    await store.saveLastReliablePoint(point);
    await store.saveEvaluatedDateKey('2026-5-11');

    expect(await store.loadStepBaseline(), 1000);
    expect((await store.loadLastReliablePoint())?.latitude, 37);
    expect(await store.loadEvaluatedDateKey(), '2026-5-11');

    await store.clearActiveTracking();

    expect(await store.loadStepBaseline(), isNull);
    expect(await store.loadLastReliablePoint(), isNull);
  });
}
