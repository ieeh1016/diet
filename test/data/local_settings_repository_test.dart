import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diet/features/activity_monitor/data/repositories/local_settings_repository.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_goal_policy.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_monitor_settings.dart';

void main() {
  test('goal policy defaults to steps and distance only', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalSettingsRepository();

    final settings = await repository.loadSettings();

    expect(settings.goalPolicy.matchMode, ActivityGoalMatchMode.all);
    expect(settings.goalPolicy.normalizedMetrics, {
      ActivityGoalMetric.steps,
      ActivityGoalMetric.distance,
    });
  });

  test('goal policy can be saved and restored', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalSettingsRepository();
    const policy = ActivityGoalPolicy(
      metrics: {ActivityGoalMetric.steps, ActivityGoalMetric.distance},
      matchMode: ActivityGoalMatchMode.any,
    );

    await repository.saveSettings(
      ActivityMonitorSettings.defaults.copyWith(goalPolicy: policy),
    );
    final restored = await repository.loadSettings();

    expect(restored.goalPolicy.matchMode, ActivityGoalMatchMode.any);
    expect(restored.goalPolicy.normalizedMetrics, {
      ActivityGoalMetric.steps,
      ActivityGoalMetric.distance,
    });
  });

  test('legacy default goal policy is migrated away from elevation', () async {
    SharedPreferences.setMockInitialValues({
      'activity.minimum_elevation_gain_meters': 50.0,
      'activity.goal_policy.metrics': 'steps,distance,elevation',
      'activity.goal_policy.match_mode': 'all',
    });
    final repository = LocalSettingsRepository();

    final restored = await repository.loadSettings();

    expect(restored.goalPolicy.normalizedMetrics, {
      ActivityGoalMetric.steps,
      ActivityGoalMetric.distance,
    });
  });
}
