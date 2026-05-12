import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/clock.dart';
import '../../../../platform/background/background_monitoring_platform_service.dart';
import '../../../../platform/health/health_connect_platform_service.dart';
import '../../../../platform/notifications/activity_notification_service.dart';
import '../../../../platform/permissions/permission_service.dart';
import '../../../../platform/sms/sms_service.dart';
import '../data/repositories/device_activity_sensor_repository.dart';
import '../data/repositories/device_alert_repository.dart';
import '../data/repositories/device_background_monitoring_coordinator.dart';
import '../data/repositories/local_onboarding_repository.dart';
import '../data/repositories/device_permission_repository.dart';
import '../data/repositories/local_settings_repository.dart';
import '../data/repositories/shared_preferences_activity_session_store.dart';
import '../domain/repositories/activity_sensor_repository.dart';
import '../domain/repositories/activity_session_store.dart';
import '../domain/repositories/alert_repository.dart';
import '../domain/repositories/background_monitoring_coordinator.dart';
import '../domain/repositories/onboarding_repository.dart';
import '../domain/repositories/permission_repository.dart';
import '../domain/repositories/settings_repository.dart';

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => LocalSettingsRepository(),
);

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => LocalOnboardingRepository(),
);

final activitySensorRepositoryProvider = Provider<ActivitySensorRepository>(
  (ref) => DeviceActivitySensorRepository(),
);

final permissionRepositoryProvider = Provider<PermissionRepository>(
  (ref) => DevicePermissionRepository(PermissionService()),
);

final alertRepositoryProvider = Provider<AlertRepository>(
  (ref) => DeviceAlertRepository(
    notificationService: ActivityNotificationService(),
    smsService: SmsService(),
  ),
);

final activitySessionStoreProvider = Provider<ActivitySessionStore>(
  (ref) => SharedPreferencesActivitySessionStore(),
);

final healthConnectPlatformServiceProvider =
    Provider<HealthConnectPlatformService>(
      (ref) => HealthConnectPlatformService(),
    );

final backgroundMonitoringCoordinatorProvider =
    Provider<BackgroundMonitoringCoordinator>((ref) {
      final coordinator = DeviceBackgroundMonitoringCoordinator(
        clock: ref.read(clockProvider),
        sensorRepository: ref.read(activitySensorRepositoryProvider),
        sessionStore: ref.read(activitySessionStoreProvider),
        alertRepository: ref.read(alertRepositoryProvider),
        platformService: BackgroundMonitoringPlatformService(),
      );
      ref.onDispose(() => coordinator.dispose());
      return coordinator;
    });
