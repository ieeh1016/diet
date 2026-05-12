class GpsPoint {
  const GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
    this.altitudeMeters,
    this.altitudeAccuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;
  final double? altitudeMeters;
  final double? altitudeAccuracyMeters;

  bool get isReliable => accuracyMeters > 0 && accuracyMeters <= 50;

  bool get hasReliableAltitude {
    final altitude = altitudeMeters;
    if (altitude == null) {
      return false;
    }
    if (altitude == 0 && (altitudeAccuracyMeters ?? 0) == 0) {
      return false;
    }
    final accuracy = altitudeAccuracyMeters;
    return accuracy == null || accuracy == 0 || accuracy <= 30;
  }
}
