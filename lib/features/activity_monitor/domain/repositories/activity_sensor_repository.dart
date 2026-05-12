import '../entities/gps_point.dart';

abstract interface class ActivitySensorRepository {
  Stream<int> get cumulativeStepCounts;

  Stream<GpsPoint> get gpsPoints;
}
