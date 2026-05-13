import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/activity_goal_policy.dart';
import '../../domain/entities/activity_monitor_settings.dart';
import '../../domain/entities/activity_threshold.dart';
import '../../domain/entities/emergency_contact.dart';
import '../../domain/repositories/settings_repository.dart';

class LocalSettingsRepository implements SettingsRepository {
  static const _minimumStepsKey = 'activity.minimum_steps';
  static const _minimumDistanceMetersKey = 'activity.minimum_distance_meters';
  static const _minimumElevationGainMetersKey =
      'activity.minimum_elevation_gain_meters';
  static const _goalPolicyMetricsKey = 'activity.goal_policy.metrics';
  static const _goalPolicyMatchModeKey = 'activity.goal_policy.match_mode';
  static const _goalPolicySchemaVersionKey =
      'activity.goal_policy.schema_version';
  static const _contactNameKey = 'activity.contact_name';
  static const _contactPhoneKey = 'activity.contact_phone';
  static const _alertMessageTemplateKey = 'activity.alert_message_template';

  @override
  Future<ActivityMonitorSettings> loadSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final goalMetrics = _loadGoalMetrics(preferences);
    final matchMode = _loadMatchMode(preferences);
    if (_shouldMigrateLegacyDefaultGoalPolicy(preferences)) {
      await preferences.setString(
        _goalPolicyMetricsKey,
        ActivityGoalPolicy.defaults.orderedMetrics
            .map((metric) => metric.name)
            .join(','),
      );
      await preferences.setString(
        _goalPolicyMatchModeKey,
        ActivityGoalPolicy.defaults.matchMode.name,
      );
      await preferences.setInt(_goalPolicySchemaVersionKey, 2);
    }
    return ActivityMonitorSettings(
      threshold: ActivityThreshold(
        minimumSteps:
            preferences.getInt(_minimumStepsKey) ??
            ActivityThreshold.defaults.minimumSteps,
        minimumDistanceMeters:
            preferences.getDouble(_minimumDistanceMetersKey) ??
            ActivityThreshold.defaults.minimumDistanceMeters,
        minimumElevationGainMeters:
            preferences.getDouble(_minimumElevationGainMetersKey) ??
            ActivityThreshold.defaults.minimumElevationGainMeters,
      ),
      goalPolicy: ActivityGoalPolicy(
        metrics: goalMetrics,
        matchMode: matchMode,
      ),
      emergencyContact: EmergencyContact(
        name: preferences.getString(_contactNameKey) ?? '',
        phoneNumber: preferences.getString(_contactPhoneKey) ?? '',
      ),
      alertMessageTemplate:
          preferences.getString(_alertMessageTemplateKey) ??
          ActivityMonitorSettings.defaultAlertMessageTemplate,
    );
  }

  @override
  Future<void> saveSettings(ActivityMonitorSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_minimumStepsKey, settings.threshold.minimumSteps);
    await preferences.setDouble(
      _minimumDistanceMetersKey,
      settings.threshold.minimumDistanceMeters,
    );
    await preferences.setDouble(
      _minimumElevationGainMetersKey,
      settings.threshold.minimumElevationGainMeters,
    );
    final metricNames = settings.goalPolicy.orderedMetrics
        .map((metric) => metric.name)
        .toList();
    await preferences.setString(_goalPolicyMetricsKey, metricNames.join(','));
    await preferences.setString(
      _goalPolicyMatchModeKey,
      settings.goalPolicy.matchMode.name,
    );
    await preferences.setInt(_goalPolicySchemaVersionKey, 2);
    await preferences.setString(
      _contactNameKey,
      settings.emergencyContact.name.trim(),
    );
    await preferences.setString(
      _contactPhoneKey,
      settings.emergencyContact.phoneNumber.trim(),
    );
    await preferences.setString(
      _alertMessageTemplateKey,
      settings.resolvedAlertMessageTemplate,
    );
  }

  Set<ActivityGoalMetric> _loadGoalMetrics(SharedPreferences preferences) {
    final raw = preferences.getString(_goalPolicyMetricsKey);
    if (raw == null || raw.trim().isEmpty) {
      return ActivityGoalPolicy.defaults.metrics;
    }
    if (_shouldMigrateLegacyDefaultGoalPolicy(preferences)) {
      return ActivityGoalPolicy.defaults.metrics;
    }
    final names = raw.split(',');
    final metrics = names
        .map(
          (name) => ActivityGoalMetric.values
              .where((metric) => metric.name == name)
              .firstOrNull,
        )
        .whereType<ActivityGoalMetric>()
        .toSet();
    return metrics.isEmpty ? ActivityGoalPolicy.defaults.metrics : metrics;
  }

  ActivityGoalMatchMode _loadMatchMode(SharedPreferences preferences) {
    final name = preferences.getString(_goalPolicyMatchModeKey);
    return ActivityGoalMatchMode.values
            .where((mode) => mode.name == name)
            .firstOrNull ??
        ActivityGoalPolicy.defaults.matchMode;
  }

  bool _shouldMigrateLegacyDefaultGoalPolicy(SharedPreferences preferences) {
    return (preferences.getInt(_goalPolicySchemaVersionKey) ?? 1) < 2 &&
        preferences.getString(_goalPolicyMetricsKey)?.trim() ==
            'steps,distance,elevation' &&
        (preferences.getDouble(_minimumElevationGainMetersKey) ??
                ActivityThreshold.defaults.minimumElevationGainMeters) ==
            ActivityThreshold.defaults.minimumElevationGainMeters &&
        _loadMatchMode(preferences) == ActivityGoalPolicy.defaults.matchMode;
  }
}
