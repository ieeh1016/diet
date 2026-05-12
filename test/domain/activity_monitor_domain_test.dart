import 'package:flutter_test/flutter_test.dart';

import 'package:diet/core/time/activity_window.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_monitor_settings.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_threshold.dart';
import 'package:diet/features/activity_monitor/domain/entities/gps_point.dart';
import 'package:diet/features/activity_monitor/domain/use_cases/build_alert_message.dart';
import 'package:diet/features/activity_monitor/domain/use_cases/calculate_distance.dart';
import 'package:diet/features/activity_monitor/domain/use_cases/evaluate_activity.dart';
import 'package:diet/features/activity_monitor/domain/use_cases/next_monitoring_window.dart';

void main() {
  test('activity window is weekday 11:00 inclusive to 13:00 exclusive', () {
    const window = ActivityWindow();

    expect(window.isWithin(DateTime(2026, 5, 11, 10, 59)), isFalse);
    expect(window.isWithin(DateTime(2026, 5, 11, 11)), isTrue);
    expect(window.isWithin(DateTime(2026, 5, 11, 12, 59)), isTrue);
    expect(window.isWithin(DateTime(2026, 5, 11, 13)), isFalse);
    expect(window.isEvaluationTime(DateTime(2026, 5, 11, 13)), isTrue);
    expect(window.isWithin(DateTime(2026, 5, 10, 11)), isFalse);
  });

  test('distance calculator accumulates only reliable GPS samples', () {
    const calculator = CalculateDistance();
    final now = DateTime(2026, 5, 11, 11);
    final distance = calculator([
      GpsPoint(
        latitude: 37,
        longitude: 127,
        accuracyMeters: 10,
        timestamp: now,
      ),
      GpsPoint(
        latitude: 37,
        longitude: 127.001,
        accuracyMeters: 100,
        timestamp: now.add(const Duration(minutes: 1)),
      ),
      GpsPoint(
        latitude: 37,
        longitude: 127.002,
        accuracyMeters: 10,
        timestamp: now.add(const Duration(minutes: 2)),
      ),
    ]);

    expect(distance, greaterThan(170));
    expect(distance, lessThan(190));
  });

  test('evaluation requires alert when steps or distance are at threshold', () {
    const evaluate = EvaluateActivity();
    final evaluation = evaluate(
      steps: 2000,
      distanceMeters: 1500,
      threshold: const ActivityThreshold(
        minimumSteps: 2000,
        minimumDistanceMeters: 1000,
      ),
      evaluatedAt: DateTime(2026, 5, 11, 13),
    );

    expect(evaluation.isStepBelowThreshold, isTrue);
    expect(evaluation.isDistanceBelowThreshold, isFalse);
    expect(evaluation.requiresAlert, isTrue);
  });

  test('alert message includes measured and configured values', () {
    const buildMessage = BuildAlertMessage();
    final evaluation = const EvaluateActivity()(
      steps: 1200,
      distanceMeters: 350,
      threshold: ActivityThreshold.defaults,
      evaluatedAt: DateTime(2026, 5, 11, 13),
    );

    final message = buildMessage(
      settings: ActivityMonitorSettings.defaults,
      evaluation: evaluation,
    );

    expect(message, contains('1200/2000'));
    expect(message, contains('0.35km/1.0km'));
  });

  test('next monitoring window skips weekends and passed windows', () {
    const nextWindow = NextMonitoringWindow();

    final mondayMorning = nextWindow(DateTime(2026, 5, 11, 9));
    expect(mondayMorning.start, DateTime(2026, 5, 11, 11));
    expect(mondayMorning.end, DateTime(2026, 5, 11, 13));

    final fridayAfterWindow = nextWindow(DateTime(2026, 5, 15, 14));
    expect(fridayAfterWindow.start, DateTime(2026, 5, 18, 11));
    expect(fridayAfterWindow.end, DateTime(2026, 5, 18, 13));
  });
}
