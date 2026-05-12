import '../entities/activity_session.dart';
import '../entities/gps_point.dart';

abstract interface class ActivitySessionStore {
  Future<ActivitySession> loadSession();

  Future<void> saveSession(ActivitySession session);

  Future<GpsPoint?> loadLastReliablePoint();

  Future<void> saveLastReliablePoint(GpsPoint point);

  Future<int?> loadStepBaseline();

  Future<void> saveStepBaseline(int baseline);

  Future<String?> loadEvaluatedDateKey();

  Future<void> saveEvaluatedDateKey(String dateKey);

  Future<void> clearActiveTracking();
}
