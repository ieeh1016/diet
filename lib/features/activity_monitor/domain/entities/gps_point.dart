class GpsPoint {
  const GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;

  bool get isReliable => accuracyMeters > 0 && accuracyMeters <= 65;
}
