import '../entities/activity_goal_policy.dart';
import '../entities/activity_evaluation.dart';
import '../entities/activity_threshold.dart';

class EvaluateActivity {
  const EvaluateActivity();

  ActivityEvaluation call({
    required int steps,
    required double distanceMeters,
    required double elevationGainMeters,
    required ActivityThreshold threshold,
    ActivityGoalPolicy goalPolicy = ActivityGoalPolicy.defaults,
    required DateTime evaluatedAt,
  }) {
    return ActivityEvaluation(
      steps: steps,
      distanceMeters: distanceMeters,
      elevationGainMeters: elevationGainMeters,
      threshold: threshold,
      goalPolicy: goalPolicy,
      evaluatedAt: evaluatedAt,
    );
  }
}
