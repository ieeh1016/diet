class ActivityThreshold {
  const ActivityThreshold({
    required this.minimumSteps,
    required this.minimumDistanceMeters,
    this.minimumElevationGainMeters = 50,
  });

  static const defaults = ActivityThreshold(
    minimumSteps: 2000,
    minimumDistanceMeters: 1000,
    minimumElevationGainMeters: 50,
  );

  final int minimumSteps;
  final double minimumDistanceMeters;
  final double minimumElevationGainMeters;

  double get minimumDistanceKilometers => minimumDistanceMeters / 1000;

  ActivityThreshold copyWith({
    int? minimumSteps,
    double? minimumDistanceMeters,
    double? minimumElevationGainMeters,
  }) {
    return ActivityThreshold(
      minimumSteps: minimumSteps ?? this.minimumSteps,
      minimumDistanceMeters:
          minimumDistanceMeters ?? this.minimumDistanceMeters,
      minimumElevationGainMeters:
          minimumElevationGainMeters ?? this.minimumElevationGainMeters,
    );
  }
}
