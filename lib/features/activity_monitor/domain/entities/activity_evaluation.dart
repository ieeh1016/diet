import 'activity_threshold.dart';

class ActivityEvaluation {
  const ActivityEvaluation({
    required this.steps,
    required this.distanceMeters,
    required this.threshold,
    required this.evaluatedAt,
    this.elevationGainMeters = 0,
  });

  final int steps;
  final double distanceMeters;
  final double elevationGainMeters;
  final ActivityThreshold threshold;
  final DateTime evaluatedAt;

  bool get isStepBelowThreshold => steps <= threshold.minimumSteps;

  bool get isDistanceBelowThreshold =>
      distanceMeters <= threshold.minimumDistanceMeters;

  bool get isElevationGainBelowThreshold =>
      elevationGainMeters <= threshold.minimumElevationGainMeters;

  bool get requiresAlert =>
      isStepBelowThreshold ||
      isDistanceBelowThreshold ||
      isElevationGainBelowThreshold;

  List<String> get alertReasons {
    final reasons = <String>[];
    if (isStepBelowThreshold) {
      reasons.add('steps');
    }
    if (isDistanceBelowThreshold) {
      reasons.add('distance');
    }
    if (isElevationGainBelowThreshold) {
      reasons.add('elevation');
    }
    return reasons;
  }
}
