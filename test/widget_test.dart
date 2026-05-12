import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diet/core/time/clock.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_monitor_settings.dart';
import 'package:diet/features/activity_monitor/presentation/activity_monitor_dependencies.dart';
import 'package:diet/main.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('renders activity monitor dashboard', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(
            FakeClock(DateTime(2026, 5, 11, 9)) as Clock,
          ),
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(ActivityMonitorSettings.defaults),
          ),
          activitySensorRepositoryProvider.overrideWithValue(
            FakeSensorRepository(),
          ),
          permissionRepositoryProvider.overrideWithValue(
            FakePermissionRepository(),
          ),
          alertRepositoryProvider.overrideWithValue(FakeAlertRepository()),
          backgroundMonitoringCoordinatorProvider.overrideWithValue(
            FakeBackgroundMonitoringCoordinator(),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    expect(find.text('활동 안전'), findsOneWidget);
    expect(find.text('걸음수'), findsWidgets);
    expect(find.text('이동거리'), findsWidgets);
    expect(find.text('목표 수정'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('보호자 연락처 설정'), 500);
    expect(find.text('보호자 연락처 설정'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
  });
}
