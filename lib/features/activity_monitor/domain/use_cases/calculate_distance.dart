import 'dart:math' as math;

import '../entities/gps_point.dart';

class CalculateDistance {
  const CalculateDistance();

  double call(Iterable<GpsPoint> points) {
    final reliablePoints = points.where((point) => point.isReliable).toList();
    if (reliablePoints.length < 2) {
      return 0;
    }

    var meters = 0.0;
    for (var i = 1; i < reliablePoints.length; i += 1) {
      meters += distanceBetween(reliablePoints[i - 1], reliablePoints[i]);
    }
    return meters;
  }

  double distanceBetween(GpsPoint from, GpsPoint to) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = _degreesToRadians(from.latitude);
    final lat2 = _degreesToRadians(to.latitude);
    final deltaLat = _degreesToRadians(to.latitude - from.latitude);
    final deltaLng = _degreesToRadians(to.longitude - from.longitude);

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;
}
