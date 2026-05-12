import '../entities/activity_evaluation.dart';
import '../entities/activity_monitor_settings.dart';

class BuildAlertMessage {
  const BuildAlertMessage();

  String call({
    required ActivityMonitorSettings settings,
    required ActivityEvaluation evaluation,
  }) {
    final distanceKm = (evaluation.distanceMeters / 1000).toStringAsFixed(2);
    final thresholdKm = settings.threshold.minimumDistanceKilometers
        .toStringAsFixed(1);

    return '활동 안전 알림: 평일 11:00-13:00 활동이 점심 시간 최소 활동 목표보다 낮아요. '
        '걸음수 ${evaluation.steps}/${settings.threshold.minimumSteps}, '
        '이동거리 ${distanceKm}km/${thresholdKm}km입니다. 확인해 주세요.';
  }
}
