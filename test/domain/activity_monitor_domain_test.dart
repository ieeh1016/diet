import 'package:flutter_test/flutter_test.dart';

import 'package:diet/core/time/activity_window.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_goal_policy.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_monitor_settings.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_threshold.dart';
import 'package:diet/features/activity_monitor/domain/entities/gps_point.dart';
import 'package:diet/features/activity_monitor/domain/use_cases/build_alert_message.dart';
import 'package:diet/features/activity_monitor/domain/use_cases/calculate_distance.dart';
import 'package:diet/features/activity_monitor/domain/use_cases/classify_walking_sample.dart';
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

  test(
    'walking sample classifier rejects stationary and too-fast intervals',
    () {
      const classifier = ClassifyWalkingSample();
      const elapsed = Duration(seconds: 30);

      expect(
        classifier(distanceMeters: 10, elapsed: elapsed),
        WalkingSampleDecision.tooLittleMovement,
      );
      expect(
        classifier(distanceMeters: 42, elapsed: elapsed),
        WalkingSampleDecision.accepted,
      );
      expect(
        classifier(distanceMeters: 90, elapsed: elapsed),
        WalkingSampleDecision.tooFastForWalking,
      );
    },
  );

  test('evaluation requires alert when steps or distance are at threshold', () {
    const evaluate = EvaluateActivity();
    final evaluation = evaluate(
      steps: 2000,
      distanceMeters: 1500,
      elevationGainMeters: 80,
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

  test('evaluation can require only selected goals', () {
    const evaluate = EvaluateActivity();
    final evaluation = evaluate(
      steps: 2500,
      distanceMeters: 300,
      elevationGainMeters: 10,
      threshold: ActivityThreshold.defaults,
      goalPolicy: const ActivityGoalPolicy(metrics: {ActivityGoalMetric.steps}),
      evaluatedAt: DateTime(2026, 5, 11, 13),
    );

    expect(evaluation.requiresAlert, isFalse);
    expect(evaluation.alertReasons, isEmpty);
  });

  test('default evaluation does not require elevation gain', () {
    const evaluate = EvaluateActivity();
    final evaluation = evaluate(
      steps: 2500,
      distanceMeters: 1300,
      elevationGainMeters: 0,
      threshold: ActivityThreshold.defaults,
      evaluatedAt: DateTime(2026, 5, 11, 13),
    );

    expect(evaluation.isElevationGainBelowThreshold, isTrue);
    expect(evaluation.requiresAlert, isFalse);
    expect(evaluation.alertReasons, isEmpty);
  });

  test('evaluation can pass when any selected goal is achieved', () {
    const evaluate = EvaluateActivity();
    final evaluation = evaluate(
      steps: 1200,
      distanceMeters: 1300,
      elevationGainMeters: 10,
      threshold: ActivityThreshold.defaults,
      goalPolicy: const ActivityGoalPolicy(
        metrics: {
          ActivityGoalMetric.steps,
          ActivityGoalMetric.distance,
          ActivityGoalMetric.elevation,
        },
        matchMode: ActivityGoalMatchMode.any,
      ),
      evaluatedAt: DateTime(2026, 5, 11, 13),
    );

    expect(evaluation.requiresAlert, isFalse);
  });

  test('alert message includes measured and configured values', () {
    const buildMessage = BuildAlertMessage();
    final evaluation = const EvaluateActivity()(
      steps: 1200,
      distanceMeters: 350,
      elevationGainMeters: 20,
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

  test('alert message applies custom template placeholders', () {
    const buildMessage = BuildAlertMessage();
    final evaluation = const EvaluateActivity()(
      steps: 900,
      distanceMeters: 420,
      elevationGainMeters: 15,
      threshold: ActivityThreshold.defaults,
      evaluatedAt: DateTime(2026, 5, 11, 13),
    );

    final message = buildMessage(
      settings: ActivityMonitorSettings.defaults.copyWith(
        alertMessageTemplate:
            '[{appName}] {contactName} 확인 필요: {steps}/{minimumSteps}, {distanceKm}/{minimumDistanceKm}',
      ),
      evaluation: evaluation,
    );

    expect(message, '[다이어트 프로젝트] 보호자 확인 필요: 900/2000, 0.42/1.0');
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
