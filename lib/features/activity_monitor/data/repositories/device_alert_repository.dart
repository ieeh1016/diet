import '../../../../platform/notifications/activity_notification_service.dart';
import '../../../../platform/sms/sms_service.dart';
import '../../domain/entities/activity_evaluation.dart';
import '../../domain/entities/activity_monitor_settings.dart';
import '../../domain/entities/alert_delivery_result.dart';
import '../../domain/repositories/alert_repository.dart';
import '../../domain/use_cases/build_alert_message.dart';

class DeviceAlertRepository implements AlertRepository {
  DeviceAlertRepository({
    required ActivityNotificationService notificationService,
    required SmsService smsService,
    BuildAlertMessage buildAlertMessage = const BuildAlertMessage(),
  }) : _notificationService = notificationService,
       _smsService = smsService,
       _buildAlertMessage = buildAlertMessage;

  final ActivityNotificationService _notificationService;
  final SmsService _smsService;
  final BuildAlertMessage _buildAlertMessage;

  @override
  Future<void> initialize() => _notificationService.initialize();

  @override
  Future<AlertDeliveryResult> deliverEmergencyAlert({
    required ActivityMonitorSettings settings,
    required ActivityEvaluation evaluation,
  }) async {
    final message = _buildAlertMessage(
      settings: settings,
      evaluation: evaluation,
    );

    var notificationShown = false;
    var smsAttempted = false;
    var smsSent = false;
    var smsFallbackOpened = false;
    String? errorMessage;

    try {
      await _notificationService.showActivityAlert(
        title: '다이어트 프로젝트 알림',
        body: message,
      );
      notificationShown = true;
    } on Object catch (error) {
      errorMessage = '알림 전송에 실패했어요: $error';
    }

    if (settings.emergencyContact.isComplete) {
      smsAttempted = true;
      try {
        final result = await _smsService.sendEmergencySms(
          phoneNumber: settings.emergencyContact.phoneNumber,
          message: message,
        );
        smsSent = result.sent;
        smsFallbackOpened = result.fallbackOpened;
      } on Object catch (error) {
        errorMessage = [?errorMessage, '문자 전송에 실패했어요: $error'].join(' / ');
      }
    }

    return AlertDeliveryResult(
      notificationShown: notificationShown,
      smsAttempted: smsAttempted,
      smsSent: smsSent,
      smsFallbackOpened: smsFallbackOpened,
      errorMessage: errorMessage,
    );
  }

  @override
  Future<AlertDeliveryResult> sendGuardianTestMessage({
    required ActivityMonitorSettings settings,
  }) async {
    if (!settings.emergencyContact.isComplete) {
      return const AlertDeliveryResult(
        notificationShown: false,
        smsAttempted: false,
        smsSent: false,
        smsFallbackOpened: false,
        errorMessage: '보호자 연락처를 먼저 입력해 주세요.',
      );
    }

    var smsSent = false;
    var smsFallbackOpened = false;
    String? errorMessage;
    try {
      final result = await _smsService.sendEmergencySms(
        phoneNumber: settings.emergencyContact.phoneNumber,
        message: _buildAlertMessage(
          settings: settings,
          evaluation: ActivityEvaluation(
            steps: settings.threshold.minimumSteps > 500
                ? settings.threshold.minimumSteps - 500
                : 0,
            distanceMeters: settings.threshold.minimumDistanceMeters * 0.7,
            elevationGainMeters:
                settings.threshold.minimumElevationGainMeters * 0.7,
            threshold: settings.threshold,
            evaluatedAt: DateTime.now(),
          ),
        ),
      );
      smsSent = result.sent;
      smsFallbackOpened = result.fallbackOpened;
    } on Object catch (error) {
      errorMessage = '미리보기 문자 전송에 실패했어요: $error';
    }

    return AlertDeliveryResult(
      notificationShown: false,
      smsAttempted: true,
      smsSent: smsSent,
      smsFallbackOpened: smsFallbackOpened,
      errorMessage: errorMessage,
    );
  }
}
