import '../entities/activity_monitor_settings.dart';

abstract interface class SettingsRepository {
  Future<ActivityMonitorSettings> loadSettings();

  Future<void> saveSettings(ActivityMonitorSettings settings);
}
