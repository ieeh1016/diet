import 'activity_threshold.dart';

class ActivityEvaluation {
  const ActivityEvaluation({
    required this.steps,
    required this.distanceMeters,
    required this.threshold,
    required this.evaluatedAt,
  });

  final int steps;
  final double distanceMeters;
  final ActivityThreshold threshold;
  final DateTime evaluatedAt;

  bool get isStepBelowThreshold => steps <= threshold.minimumSteps;

  bool get isDistanceBelowThreshold =>
      distanceMeters <= threshold.minimumDistanceMeters;

  bool get requiresAlert => isStepBelowThreshold || isDistanceBelowThreshold;

  List<String> get alertReasons {
    final reasons = <String>[];
    if (isStepBelowThreshold) {
      reasons.add('steps');
    }
    if (isDistanceBelowThreshold) {
      reasons.add('distance');
    }
    return reasons;
  }
}
