import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';

import '../../domain/entities/gps_point.dart';
import '../../domain/repositories/activity_sensor_repository.dart';

class DeviceActivitySensorRepository implements ActivitySensorRepository {
  @override
  Stream<int> get cumulativeStepCounts =>
      Pedometer.stepCountStream.map((event) => event.steps);

  @override
  Stream<GpsPoint> get gpsPoints {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    );

    return Geolocator.getPositionStream(locationSettings: settings).map(
      (position) => GpsPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
        altitudeMeters: position.altitude,
        altitudeAccuracyMeters: position.altitudeAccuracy,
      ),
    );
  }
}
