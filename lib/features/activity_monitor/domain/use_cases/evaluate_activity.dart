import '../entities/activity_evaluation.dart';
import '../entities/activity_threshold.dart';

class EvaluateActivity {
  const EvaluateActivity();

  ActivityEvaluation call({
    required int steps,
    required double distanceMeters,
    required ActivityThreshold threshold,
    required DateTime evaluatedAt,
  }) {
    return ActivityEvaluation(
      steps: steps,
      distanceMeters: distanceMeters,
      threshold: threshold,
      evaluatedAt: evaluatedAt,
    );
  }
}
