class ActivityThreshold {
  const ActivityThreshold({
    required this.minimumSteps,
    required this.minimumDistanceMeters,
  });

  static const defaults = ActivityThreshold(
    minimumSteps: 2000,
    minimumDistanceMeters: 1000,
  );

  final int minimumSteps;
  final double minimumDistanceMeters;

  double get minimumDistanceKilometers => minimumDistanceMeters / 1000;

  ActivityThreshold copyWith({
    int? minimumSteps,
    double? minimumDistanceMeters,
  }) {
    return ActivityThreshold(
      minimumSteps: minimumSteps ?? this.minimumSteps,
      minimumDistanceMeters:
          minimumDistanceMeters ?? this.minimumDistanceMeters,
    );
  }
}
