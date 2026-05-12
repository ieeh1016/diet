import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diet/core/time/clock.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_monitor_settings.dart';
import 'package:diet/features/activity_monitor/presentation/activity_monitor_dependencies.dart';
import 'package:diet/main.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('shows onboarding first when not completed', (tester) async {
    await _pumpApp(tester, onboardingCompleted: false);

    expect(find.text('처음 설정'), findsOneWidget);
    expect(find.text('다이어트 프로젝트 소개'), findsOneWidget);
    expect(find.text('다음'), findsOneWidget);
  });

  testWidgets('completing onboarding shows dashboard', (tester) async {
    final onboardingRepository = FakeOnboardingRepository();
    await _pumpApp(
      tester,
      onboardingCompleted: false,
      onboardingRepository: onboardingRepository,
    );

    await tester.tap(find.text('다음'));
    await _pumpFrames(tester);
    await tester.tap(find.text('권한 허용하고 계속'));
    await _pumpFrames(tester);
    await tester.tap(find.text('목표 저장하고 계속'));
    await _pumpFrames(tester);
    await tester.tap(find.text('보호자 설정 저장'));
    await _pumpFrames(tester);
    await tester.tap(find.text('시작하기'));
    await _pumpFrames(tester);

    expect(onboardingRepository.completed, isTrue);
    expect(find.text('다이어트 프로젝트'), findsOneWidget);
    expect(find.text('처음 설정'), findsNothing);
    expect(find.text('다이어트 프로젝트 소개'), findsNothing);
  });

  testWidgets('renders dashboard when onboarding is already completed', (
    tester,
  ) async {
    await _pumpApp(tester, onboardingCompleted: true);

    expect(find.text('다이어트 프로젝트'), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('목표'), findsOneWidget);
    expect(find.text('보호자'), findsOneWidget);
    expect(find.text('준비'), findsOneWidget);
    expect(find.text('걸음수'), findsWidgets);
    expect(find.text('이동거리'), findsWidgets);

    await _tapDestination(tester, '목표');
    expect(find.text('목표 수정'), findsOneWidget);

    await _tapDestination(tester, '보호자');
    expect(find.text('보호자 연락처'), findsOneWidget);
    expect(find.text('보호자에게 미리보기 문자 보내기'), findsOneWidget);

    await _tapDestination(tester, '준비');
    expect(find.text('자동 기록 준비 상태'), findsOneWidget);
  });

  testWidgets('help button opens onboarding again', (tester) async {
    await _pumpApp(tester, onboardingCompleted: true);

    await tester.tap(find.byTooltip('튜토리얼 다시 보기'));
    await _pumpFrames(tester);

    expect(find.text('처음 설정'), findsOneWidget);
    expect(find.text('다이어트 프로젝트 소개'), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required bool onboardingCompleted,
  FakeOnboardingRepository? onboardingRepository,
}) async {
  final sensorRepository = FakeSensorRepository();
  addTearDown(sensorRepository.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(
          FakeClock(DateTime(2026, 5, 11, 9)) as Clock,
        ),
        settingsRepositoryProvider.overrideWithValue(
          FakeSettingsRepository(ActivityMonitorSettings.defaults),
        ),
        onboardingRepositoryProvider.overrideWithValue(
          onboardingRepository ??
              FakeOnboardingRepository(completed: onboardingCompleted),
        ),
        activitySensorRepositoryProvider.overrideWithValue(sensorRepository),
        permissionRepositoryProvider.overrideWithValue(
          FakePermissionRepository(),
        ),
        healthConnectPlatformServiceProvider.overrideWithValue(
          FakeHealthConnectPlatformService(),
        ),
        alertRepositoryProvider.overrideWithValue(FakeAlertRepository()),
        backgroundMonitoringCoordinatorProvider.overrideWithValue(
          FakeBackgroundMonitoringCoordinator(),
        ),
      ],
      child: const MyApp(),
    ),
  );
  await _pumpFrames(tester);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tapDestination(WidgetTester tester, String label) async {
  await tester.tap(
    find
        .descendant(of: find.byType(NavigationBar), matching: find.text(label))
        .last,
  );
  await _pumpFrames(tester);
}
