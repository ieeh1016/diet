import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/activity_monitor_settings.dart';
import '../../domain/entities/activity_threshold.dart';
import '../../domain/entities/emergency_contact.dart';
import '../../domain/repositories/settings_repository.dart';

class LocalSettingsRepository implements SettingsRepository {
  static const _minimumStepsKey = 'activity.minimum_steps';
  static const _minimumDistanceMetersKey = 'activity.minimum_distance_meters';
  static const _minimumElevationGainMetersKey =
      'activity.minimum_elevation_gain_meters';
  static const _contactNameKey = 'activity.contact_name';
  static const _contactPhoneKey = 'activity.contact_phone';
  static const _alertMessageTemplateKey = 'activity.alert_message_template';

  @override
  Future<ActivityMonitorSettings> loadSettings() async {
    final preferences = await SharedPreferences.getInstance();
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
}
