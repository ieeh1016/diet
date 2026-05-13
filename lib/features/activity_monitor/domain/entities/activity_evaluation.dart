import 'activity_goal_policy.dart';
import 'activity_threshold.dart';

class ActivityEvaluation {
  const ActivityEvaluation({
    required this.steps,
    required this.distanceMeters,
    required this.threshold,
    this.goalPolicy = ActivityGoalPolicy.defaults,
    required this.evaluatedAt,
    this.elevationGainMeters = 0,
  });

  final int steps;
  final double distanceMeters;
  final double elevationGainMeters;
  final ActivityThreshold threshold;
  final ActivityGoalPolicy goalPolicy;
  final DateTime evaluatedAt;

  bool get isStepBelowThreshold => steps <= threshold.minimumSteps;

  bool get isDistanceBelowThreshold =>
      distanceMeters <= threshold.minimumDistanceMeters;

  bool get isElevationGainBelowThreshold =>
      elevationGainMeters <= threshold.minimumElevationGainMeters;

  bool get requiresAlert {
    final checks = goalPolicy.normalizedMetrics.map(_isBelowThreshold).toList();
    return switch (goalPolicy.matchMode) {
      ActivityGoalMatchMode.all => checks.any((isBelow) => isBelow),
      ActivityGoalMatchMode.any => checks.every((isBelow) => isBelow),
    };
  }

  List<String> get alertReasons {
    final reasons = <String>[];
    if (goalPolicy.includes(ActivityGoalMetric.steps) && isStepBelowThreshold) {
      reasons.add('steps');
    }
    if (goalPolicy.includes(ActivityGoalMetric.distance) &&
        isDistanceBelowThreshold) {
      reasons.add('distance');
    }
    if (goalPolicy.includes(ActivityGoalMetric.elevation) &&
        isElevationGainBelowThreshold) {
      reasons.add('elevation');
    }
    return reasons;
  }

  bool _isBelowThreshold(ActivityGoalMetric metric) {
    return switch (metric) {
      ActivityGoalMetric.steps => isStepBelowThreshold,
      ActivityGoalMetric.distance => isDistanceBelowThreshold,
      ActivityGoalMetric.elevation => isElevationGainBelowThreshold,
    };
  }
}
