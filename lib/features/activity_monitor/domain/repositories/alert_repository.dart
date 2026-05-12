import '../entities/activity_evaluation.dart';
import '../entities/activity_monitor_settings.dart';
import '../entities/alert_delivery_result.dart';

abstract interface class AlertRepository {
  Future<void> initialize();

  Future<AlertDeliveryResult> deliverEmergencyAlert({
    required ActivityMonitorSettings settings,
    required ActivityEvaluation evaluation,
  });

  Future<AlertDeliveryResult> sendGuardianTestMessage({
    required ActivityMonitorSettings settings,
  });
}
