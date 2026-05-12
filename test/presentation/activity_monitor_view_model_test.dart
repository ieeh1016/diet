import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diet/core/time/clock.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_monitor_settings.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_threshold.dart';
import 'package:diet/features/activity_monitor/domain/entities/emergency_contact.dart';
import 'package:diet/features/activity_monitor/presentation/activity_monitor_dependencies.dart';
import 'package:diet/features/activity_monitor/presentation/activity_monitor_providers.dart';

import '../support/fakes.dart';

void main() {
  test('manual evaluation delegates to background coordinator', () async {
    final clock = FakeClock(DateTime(2026, 5, 11, 10));
    final settingsRepository = FakeSettingsRepository(
      const ActivityMonitorSettings(
        threshold: ActivityThreshold(
          minimumSteps: 10,
          minimumDistanceMeters: 100,
        ),
        emergencyContact: EmergencyContact(
          name: 'Family',
          phoneNumber: '01012345678',
        ),
      ),
    );
    final sensorRepository = FakeSensorRepository();
    final alertRepository = FakeAlertRepository();
    final coordinator = FakeBackgroundMonitoringCoordinator();

    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock as Clock),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        activitySensorRepositoryProvider.overrideWithValue(sensorRepository),
        permissionRepositoryProvider.overrideWithValue(
          FakePermissionRepository(),
        ),
        alertRepositoryProvider.overrideWithValue(alertRepository),
        backgroundMonitoringCoordinatorProvider.overrideWithValue(coordinator),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(sensorRepository.dispose);

    container.listen(activityMonitorViewModelProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    final viewModel = container.read(activityMonitorViewModelProvider.notifier);
    await viewModel.startMonitoring();

    clock.value = DateTime(2026, 5, 11, 13);
    await viewModel.stopMonitoringAndEvaluate();

    final state = container.read(activityMonitorViewModelProvider);
    expect(state.session.evaluation?.requiresAlert, isTrue);
    expect(coordinator.startCount, 1);
    expect(coordinator.evaluateCount, 1);
  });

  test('saving settings delegates to repository and updates state', () async {
    final settingsRepository = FakeSettingsRepository(
      ActivityMonitorSettings.defaults,
    );
    final sensorRepository = FakeSensorRepository();
    final coordinator = FakeBackgroundMonitoringCoordinator();
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(
          FakeClock(DateTime(2026, 5, 11, 9)) as Clock,
        ),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        activitySensorRepositoryProvider.overrideWithValue(sensorRepository),
        permissionRepositoryProvider.overrideWithValue(
          FakePermissionRepository(),
        ),
        alertRepositoryProvider.overrideWithValue(FakeAlertRepository()),
        backgroundMonitoringCoordinatorProvider.overrideWithValue(coordinator),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(sensorRepository.dispose);

    container.listen(activityMonitorViewModelProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    const updated = ActivityMonitorSettings(
      threshold: ActivityThreshold(
        minimumSteps: 3000,
        minimumDistanceMeters: 1500,
      ),
      emergencyContact: EmergencyContact(
        name: 'Parent',
        phoneNumber: '01000000000',
      ),
    );

    await container
        .read(activityMonitorViewModelProvider.notifier)
        .saveSettings(updated);

    expect(settingsRepository.settings.threshold.minimumSteps, 3000);
    expect(coordinator.scheduleCount, greaterThanOrEqualTo(1));
    expect(
      container
          .read(activityMonitorViewModelProvider)
          .settings
          .emergencyContact
          .name,
      'Parent',
    );
  });
}
