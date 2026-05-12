import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/activity_session.dart';
import '../../domain/entities/gps_point.dart';
import '../../domain/repositories/activity_session_store.dart';

class SharedPreferencesActivitySessionStore implements ActivitySessionStore {
  static const _statusKey = 'background.session.status';
  static const _startedAtKey = 'background.session.started_at';
  static const _endedAtKey = 'background.session.ended_at';
  static const _stepsKey = 'background.session.steps';
  static const _distanceMetersKey = 'background.session.distance_meters';
  static const _lastLatitudeKey = 'background.session.last_latitude';
  static const _lastLongitudeKey = 'background.session.last_longitude';
  static const _lastAccuracyKey = 'background.session.last_accuracy';
  static const _lastTimestampKey = 'background.session.last_timestamp';
  static const _stepBaselineKey = 'background.session.step_baseline';
  static const _evaluatedDateKey = 'background.session.evaluated_date_key';

  @override
  Future<ActivitySession> loadSession() async {
    final preferences = await SharedPreferences.getInstance();
    final statusName = preferences.getString(_statusKey);
    final status = ActivitySessionStatus.values
        .where((value) => value.name == statusName)
        .firstOrNull;

    if (status == null || status == ActivitySessionStatus.idle) {
      return const ActivitySession.idle();
    }

    return ActivitySession(
      status: status,
      startedAt: _parseDate(preferences.getString(_startedAtKey)),
      endedAt: _parseDate(preferences.getString(_endedAtKey)),
      steps: preferences.getInt(_stepsKey) ?? 0,
      distanceMeters: preferences.getDouble(_distanceMetersKey) ?? 0,
      evaluation: null,
    );
  }

  @override
  Future<void> saveSession(ActivitySession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_statusKey, session.status.name);
    await preferences.setInt(_stepsKey, session.steps);
    await preferences.setDouble(_distanceMetersKey, session.distanceMeters);

    if (session.startedAt case final startedAt?) {
      await preferences.setString(_startedAtKey, startedAt.toIso8601String());
    } else {
      await preferences.remove(_startedAtKey);
    }

    if (session.endedAt case final endedAt?) {
      await preferences.setString(_endedAtKey, endedAt.toIso8601String());
    } else {
      await preferences.remove(_endedAtKey);
    }
  }

  @override
  Future<GpsPoint?> loadLastReliablePoint() async {
    final preferences = await SharedPreferences.getInstance();
    final latitude = preferences.getDouble(_lastLatitudeKey);
    final longitude = preferences.getDouble(_lastLongitudeKey);
    final accuracy = preferences.getDouble(_lastAccuracyKey);
    final timestamp = _parseDate(preferences.getString(_lastTimestampKey));

    if (latitude == null ||
        longitude == null ||
        accuracy == null ||
        timestamp == null) {
      return null;
    }

    return GpsPoint(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracy,
      timestamp: timestamp,
    );
  }

  @override
  Future<void> saveLastReliablePoint(GpsPoint point) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_lastLatitudeKey, point.latitude);
    await preferences.setDouble(_lastLongitudeKey, point.longitude);
    await preferences.setDouble(_lastAccuracyKey, point.accuracyMeters);
    await preferences.setString(
      _lastTimestampKey,
      point.timestamp.toIso8601String(),
    );
  }

  @override
  Future<int?> loadStepBaseline() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_stepBaselineKey);
  }

  @override
  Future<void> saveStepBaseline(int baseline) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_stepBaselineKey, baseline);
  }

  @override
  Future<String?> loadEvaluatedDateKey() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_evaluatedDateKey);
  }

  @override
  Future<void> saveEvaluatedDateKey(String dateKey) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_evaluatedDateKey, dateKey);
  }

  @override
  Future<void> clearActiveTracking() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_lastLatitudeKey);
    await preferences.remove(_lastLongitudeKey);
    await preferences.remove(_lastAccuracyKey);
    await preferences.remove(_lastTimestampKey);
    await preferences.remove(_stepBaselineKey);
  }

  DateTime? _parseDate(String? value) =>
      value == null ? null : DateTime.tryParse(value);
}
