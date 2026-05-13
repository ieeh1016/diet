import 'activity_goal_policy.dart';
import 'activity_threshold.dart';
import 'emergency_contact.dart';

class ActivityMonitorSettings {
  const ActivityMonitorSettings({
    required this.threshold,
    this.goalPolicy = ActivityGoalPolicy.defaults,
    required this.emergencyContact,
    this.alertMessageTemplate = defaultAlertMessageTemplate,
  });

  static const appName = '다이어트 프로젝트';
  static const defaultAlertMessageTemplate =
      '{appName} 알림: 평일 11:00-13:00 점심 활동이 설정한 기준 이하예요. '
      '판정 기준: {goalPolicy}. 걸음수 {steps}/{minimumSteps}, 이동거리 {distanceKm}km/{minimumDistanceKm}km, '
      '획득고도 {elevationGainMeters}m/{minimumElevationGainMeters}m입니다. 확인해 주세요.';
  static const legacyDefaultAlertMessageTemplate =
      '{appName} 알림: 평일 11:00-13:00 점심 활동이 최소 활동 목표보다 낮아요. '
      '걸음수 {steps}/{minimumSteps}, 이동거리 {distanceKm}km/{minimumDistanceKm}km입니다. 확인해 주세요.';

  static const defaults = ActivityMonitorSettings(
    threshold: ActivityThreshold.defaults,
    goalPolicy: ActivityGoalPolicy.defaults,
    emergencyContact: EmergencyContact.empty,
  );

  final ActivityThreshold threshold;
  final ActivityGoalPolicy goalPolicy;
  final EmergencyContact emergencyContact;
  final String alertMessageTemplate;

  String get resolvedAlertMessageTemplate {
    final trimmed = alertMessageTemplate.trim();
    return trimmed.isEmpty || trimmed == legacyDefaultAlertMessageTemplate
        ? defaultAlertMessageTemplate
        : trimmed;
  }

  ActivityMonitorSettings copyWith({
    ActivityThreshold? threshold,
    ActivityGoalPolicy? goalPolicy,
    EmergencyContact? emergencyContact,
    String? alertMessageTemplate,
  }) {
    return ActivityMonitorSettings(
      threshold: threshold ?? this.threshold,
      goalPolicy: goalPolicy ?? this.goalPolicy,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      alertMessageTemplate: alertMessageTemplate ?? this.alertMessageTemplate,
    );
  }
}
