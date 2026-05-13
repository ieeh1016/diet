import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diet/core/time/clock.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_monitor_settings.dart';
import 'package:diet/features/activity_monitor/domain/entities/activity_session.dart';
import 'package:diet/features/activity_monitor/domain/entities/background_monitoring_status.dart';
import 'package:diet/features/activity_monitor/domain/entities/sms_delivery_snapshot.dart';
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
    await tester.tap(find.text('권한 확인하고 계속'));
    await _pumpFrames(tester);
    await tester.tap(find.text('목표 저장하고 계속'));
    await _pumpFrames(tester);
    await tester.enterText(find.widgetWithText(TextFormField, '보호자 이름'), '부모님');
    await tester.enterText(
      find.widgetWithText(TextFormField, '보호자 전화번호'),
      '01012345678',
    );
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
    expect(find.text('규칙'), findsOneWidget);
    expect(find.text('보호자'), findsOneWidget);
    expect(find.text('준비'), findsOneWidget);
    expect(find.text('걸음수'), findsWidgets);
    expect(find.text('이동거리'), findsWidgets);
    expect(find.text('측정 상세'), findsOneWidget);
    expect(find.text('기록 신뢰도 양호'), findsOneWidget);
    await _scrollUntilText(tester, tabKey: 'home_tab', text: '상세 보기');
    expect(find.text('상세 보기'), findsOneWidget);
    await tester.tap(find.text('상세 보기'));
    await _pumpFrames(tester);
    expect(find.text('측정 상세 내역'), findsOneWidget);
    expect(find.text('GPS 정확도 불량 제외'), findsOneWidget);
    await tester.tap(find.byTooltip('닫기'));
    await _pumpFrames(tester);
    await _scrollUntilText(tester, tabKey: 'home_tab', text: '최근 기록');
    expect(find.text('최근 기록'), findsOneWidget);
    await _scrollUntilText(tester, tabKey: 'home_tab', text: '지금 바로 기록 시작');
    expect(find.text('지금 바로 기록 시작'), findsOneWidget);
    expect(find.text('기록 시작'), findsOneWidget);
    await _scrollUntilText(
      tester,
      tabKey: 'home_tab',
      text: '저장된 오늘 기록으로 최종 확인',
    );
    expect(find.text('저장된 오늘 기록으로 최종 확인'), findsOneWidget);
    expect(find.text('오늘 기록 확인'), findsOneWidget);

    await _tapDestination(tester, '목표');
    expect(find.text('목표 수정'), findsOneWidget);

    await _tapDestination(tester, '규칙');
    expect(find.text('측정 규칙과 제한'), findsOneWidget);
    expect(find.textContaining('10m 이하'), findsWidgets);
    expect(find.textContaining('90m 이상'), findsWidgets);

    await _tapDestination(tester, '보호자');
    expect(find.text('보호자 연락처'), findsOneWidget);
    expect(find.text('보호자에게 테스트 문자 실제 보내기'), findsOneWidget);
    await _scrollUntilText(tester, tabKey: 'guardian_tab', text: '문자 발송 상태');
    expect(find.text('문자 발송 상태'), findsOneWidget);
    expect(find.text('최근 문자 상태'), findsOneWidget);

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

  testWidgets('restores alert state from native evaluated session', (
    tester,
  ) async {
    final backgroundCoordinator = FakeBackgroundMonitoringCoordinator()
      ..status = BackgroundMonitoringStatus.initial().copyWith(
        lastSession: ActivitySession(
          status: ActivitySessionStatus.evaluated,
          startedAt: DateTime(2026, 5, 11, 11),
          endedAt: DateTime(2026, 5, 11, 13),
          steps: 500,
          distanceMeters: 100,
          elevationGainMeters: 0,
          evaluation: null,
        ),
      );

    await _pumpApp(
      tester,
      onboardingCompleted: true,
      backgroundCoordinator: backgroundCoordinator,
    );

    expect(find.text('오늘 활동이\n부족해요'), findsOneWidget);
    await _scrollUntilText(tester, tabKey: 'home_tab', text: '최근 기록');
    expect(find.text('기준 미달'), findsOneWidget);
  });

  testWidgets('shows automatic SMS failure instead of stale preview success', (
    tester,
  ) async {
    final backgroundCoordinator = FakeBackgroundMonitoringCoordinator()
      ..status = BackgroundMonitoringStatus.initial().copyWith(
        smsDelivery: SmsDeliverySnapshot(
          status: 'failed',
          error: '문자 권한이 없어 보호자 문자를 보내지 못했어요.',
          attemptedAt: DateTime(2026, 5, 11, 13, 1),
          phoneNumber: '01012345678',
          dateKey: '2026-5-11',
        ),
      );

    await _pumpApp(
      tester,
      onboardingCompleted: true,
      backgroundCoordinator: backgroundCoordinator,
    );
    await _tapDestination(tester, '보호자');
    await _scrollUntilText(tester, tabKey: 'guardian_tab', text: '문자 발송 상태');

    expect(find.text('발송 실패'), findsOneWidget);
    expect(find.text('문자 권한이 없어 보호자 문자를 보내지 못했어요.'), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required bool onboardingCompleted,
  FakeOnboardingRepository? onboardingRepository,
  FakeBackgroundMonitoringCoordinator? backgroundCoordinator,
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
          backgroundCoordinator ?? FakeBackgroundMonitoringCoordinator(),
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

Future<void> _scrollUntilText(
  WidgetTester tester, {
  required String tabKey,
  required String text,
}) async {
  final tab = find.byKey(PageStorageKey<String>(tabKey));
  final scrollable = find.descendant(
    of: tab,
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(find.text(text), 180, scrollable: scrollable);
  await _pumpFrames(tester);
}
