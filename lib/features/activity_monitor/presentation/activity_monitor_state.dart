import '../../../../core/permissions/permission_snapshot.dart';
import '../../../../core/time/activity_window.dart';
import '../domain/entities/activity_monitor_settings.dart';
import '../domain/entities/activity_session.dart';
import '../domain/entities/alert_delivery_result.dart';
import '../domain/entities/background_monitoring_status.dart';
import '../domain/entities/health_connect_step_status.dart';

class ActivityMonitorState {
  const ActivityMonitorState({
    required this.settings,
    required this.session,
    required this.permissions,
    required this.now,
    required this.isLoading,
    required this.isSaving,
    required this.isInitialized,
    required this.isOnboardingVisible,
    required this.isOnboardingCompleted,
    required this.lastDeliveryResult,
    required this.backgroundStatus,
    required this.healthConnectStepStatus,
    this.statusMessage,
    this.errorMessage,
  });

  factory ActivityMonitorState.initial({required DateTime now}) {
    return ActivityMonitorState(
      settings: ActivityMonitorSettings.defaults,
      session: const ActivitySession.idle(),
      permissions: const PermissionSnapshot.unknown(),
      now: now,
      isLoading: true,
      isSaving: false,
      isInitialized: false,
      isOnboardingVisible: false,
      isOnboardingCompleted: false,
      lastDeliveryResult: const AlertDeliveryResult.none(),
      backgroundStatus: const BackgroundMonitoringStatus.initial(),
      healthConnectStepStatus: const HealthConnectStepStatus.unavailable(),
    );
  }

  final ActivityMonitorSettings settings;
  final ActivitySession session;
  final PermissionSnapshot permissions;
  final DateTime now;
  final bool isLoading;
  final bool isSaving;
  final bool isInitialized;
  final bool isOnboardingVisible;
  final bool isOnboardingCompleted;
  final AlertDeliveryResult lastDeliveryResult;
  final BackgroundMonitoringStatus backgroundStatus;
  final HealthConnectStepStatus healthConnectStepStatus;
  final String? statusMessage;
  final String? errorMessage;

  ActivityWindowPhase get windowPhase => const ActivityWindow().phaseFor(now);

  ActivityMonitorState copyWith({
    ActivityMonitorSettings? settings,
    ActivitySession? session,
    PermissionSnapshot? permissions,
    DateTime? now,
    bool? isLoading,
    bool? isSaving,
    bool? isInitialized,
    bool? isOnboardingVisible,
    bool? isOnboardingCompleted,
    AlertDeliveryResult? lastDeliveryResult,
    BackgroundMonitoringStatus? backgroundStatus,
    HealthConnectStepStatus? healthConnectStepStatus,
    String? statusMessage,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ActivityMonitorState(
      settings: settings ?? this.settings,
      session: session ?? this.session,
      permissions: permissions ?? this.permissions,
      now: now ?? this.now,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isInitialized: isInitialized ?? this.isInitialized,
      isOnboardingVisible: isOnboardingVisible ?? this.isOnboardingVisible,
      isOnboardingCompleted:
          isOnboardingCompleted ?? this.isOnboardingCompleted,
      lastDeliveryResult: lastDeliveryResult ?? this.lastDeliveryResult,
      backgroundStatus: backgroundStatus ?? this.backgroundStatus,
      healthConnectStepStatus:
          healthConnectStepStatus ?? this.healthConnectStepStatus,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
