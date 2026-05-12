import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/activity_window.dart';
import '../domain/entities/activity_monitor_settings.dart';
import '../domain/entities/activity_session.dart';
import '../domain/entities/background_monitoring_status.dart';
import 'activity_monitor_dependencies.dart';
import 'activity_monitor_state.dart';

class ActivityMonitorViewModel extends Notifier<ActivityMonitorState> {
  final _window = const ActivityWindow();

  StreamSubscription<BackgroundMonitoringStatus>? _backgroundSubscription;
  var _disposed = false;

  @override
  ActivityMonitorState build() {
    _disposed = false;
    final coordinator = ref.read(backgroundMonitoringCoordinatorProvider);
    _backgroundSubscription = coordinator.statuses.listen(
      _handleBackgroundStatus,
      onError: (Object error) {
        _setState(state.copyWith(errorMessage: '백그라운드 상태를 확인하지 못했어요: $error'));
      },
    );
    unawaited(_loadInitialState());
    ref.onDispose(_dispose);

    return ActivityMonitorState.initial(now: ref.read(clockProvider).now());
  }

  Future<void> _loadInitialState() async {
    try {
      final settings = await ref
          .read(settingsRepositoryProvider)
          .loadSettings();
      final onboardingCompleted = await ref
          .read(onboardingRepositoryProvider)
          .isCompleted();
      final permissions = await ref
          .read(permissionRepositoryProvider)
          .readPermissionSnapshot();
      final backgroundStatus = await ref
          .read(backgroundMonitoringCoordinatorProvider)
          .scheduleWeekdayMonitoring();
      final healthConnectStepStatus = await ref
          .read(healthConnectPlatformServiceProvider)
          .currentStatus();

      _setState(
        state.copyWith(
          settings: settings,
          permissions: permissions,
          session: backgroundStatus.lastSession,
          backgroundStatus: backgroundStatus,
          healthConnectStepStatus: healthConnectStepStatus,
          isLoading: false,
          isInitialized: true,
          isOnboardingVisible: !onboardingCompleted,
          isOnboardingCompleted: onboardingCompleted,
          statusMessage: backgroundStatus.isScheduled
              ? '평일 백그라운드 측정이 예약됐어요'
              : '앱 실행 중 측정을 준비했어요',
          clearError: true,
        ),
      );
      await syncSchedule();
    } on Object catch (error) {
      _setState(
        state.copyWith(
          isLoading: false,
          isInitialized: true,
          errorMessage: '활동 모니터를 불러오지 못했어요: $error',
        ),
      );
    }
  }

  void showOnboarding() {
    _setState(state.copyWith(isOnboardingVisible: true, clearError: true));
  }

  void closeOnboarding() {
    if (!state.isOnboardingCompleted) {
      return;
    }
    _setState(state.copyWith(isOnboardingVisible: false, clearError: true));
  }

  Future<void> completeOnboarding() async {
    _setState(state.copyWith(isSaving: true, clearError: true));
    try {
      await ref.read(onboardingRepositoryProvider).markCompleted();
      _setState(
        state.copyWith(
          isSaving: false,
          isOnboardingVisible: false,
          isOnboardingCompleted: true,
          statusMessage: '첫 설정을 완료했어요',
          clearError: true,
        ),
      );
    } on Object catch (error) {
      _setState(
        state.copyWith(
          isSaving: false,
          errorMessage: '튜토리얼 완료 상태를 저장하지 못했어요: $error',
        ),
      );
    }
  }

  Future<void> saveSettings(ActivityMonitorSettings settings) async {
    _setState(state.copyWith(isSaving: true, clearError: true));
    try {
      await ref.read(settingsRepositoryProvider).saveSettings(settings);
      final backgroundStatus = await ref
          .read(backgroundMonitoringCoordinatorProvider)
          .scheduleWeekdayMonitoring();
      _setState(
        state.copyWith(
          settings: settings,
          backgroundStatus: backgroundStatus,
          isSaving: false,
          statusMessage: '설정을 저장하고 일정을 갱신했어요',
          clearError: true,
        ),
      );
    } on Object catch (error) {
      _setState(
        state.copyWith(isSaving: false, errorMessage: '설정을 저장하지 못했어요: $error'),
      );
    }
  }

  Future<void> requestPermissions() async {
    _setState(state.copyWith(isLoading: true, clearError: true));
    try {
      final permissions = await ref
          .read(permissionRepositoryProvider)
          .requestRequiredPermissions();
      final healthConnectStepStatus = await ref
          .read(healthConnectPlatformServiceProvider)
          .requestReadStepsPermission();
      final backgroundStatus = await ref
          .read(backgroundMonitoringCoordinatorProvider)
          .scheduleWeekdayMonitoring();
      _setState(
        state.copyWith(
          permissions: permissions,
          backgroundStatus: backgroundStatus,
          healthConnectStepStatus: healthConnectStepStatus,
          isLoading: false,
          statusMessage: permissions.requiredPermissionsGranted
              ? '권한을 확인하고 일정을 갱신했어요'
              : '필요한 권한이 부족해요: ${permissions.missingLabels.join(', ')}',
          clearError: true,
        ),
      );
    } on Object catch (error) {
      _setState(
        state.copyWith(isLoading: false, errorMessage: '권한 요청에 실패했어요: $error'),
      );
    }
  }

  Future<void> syncSchedule() async {
    final now = ref.read(clockProvider).now();
    final coordinator = ref.read(backgroundMonitoringCoordinatorProvider);
    final backgroundStatus = await coordinator.currentStatus();
    final healthConnectStepStatus = await ref
        .read(healthConnectPlatformServiceProvider)
        .currentStatus();

    _setState(
      state.copyWith(
        now: now,
        session: backgroundStatus.lastSession,
        backgroundStatus: backgroundStatus,
        healthConnectStepStatus: healthConnectStepStatus,
      ),
    );

    if (_window.isWithin(now) && !backgroundStatus.lastSession.isActive) {
      await startMonitoring();
    }
  }

  Future<void> startMonitoring() async {
    _setState(state.copyWith(isLoading: true, clearError: true));

    try {
      final permissions = await ref
          .read(permissionRepositoryProvider)
          .requestRequiredPermissions();
      _setState(state.copyWith(permissions: permissions));

      if (!permissions.requiredPermissionsGranted) {
        _setState(
          state.copyWith(
            isLoading: false,
            errorMessage:
                '필요한 권한이 부족해요: ${permissions.missingLabels.join(', ')}',
          ),
        );
        return;
      }

      final session = await ref
          .read(backgroundMonitoringCoordinatorProvider)
          .startWindow(state.settings);
      _setState(
        state.copyWith(
          session: session,
          isLoading: false,
          statusMessage: '측정을 시작했어요',
          clearError: true,
        ),
      );
    } on Object catch (error) {
      _setState(
        state.copyWith(isLoading: false, errorMessage: '측정을 시작하지 못했어요: $error'),
      );
    }
  }

  Future<void> stopMonitoringAndEvaluate() async {
    _setState(state.copyWith(isLoading: true, clearError: true));
    try {
      final session = await ref
          .read(backgroundMonitoringCoordinatorProvider)
          .stopAndEvaluate(state.settings);
      final evaluation = session.evaluation;
      final shouldFinalize = _window.isEvaluationTime(
        ref.read(clockProvider).now(),
      );
      _setState(
        state.copyWith(
          now: ref.read(clockProvider).now(),
          session: session,
          isLoading: false,
          statusMessage: (evaluation?.requiresAlert ?? false) && shouldFinalize
              ? '점심 시간 최소 활동 목표보다 낮아 보호자 연락을 준비했어요'
              : evaluation?.requiresAlert ?? false
              ? '현재 기록은 최소 활동 목표보다 낮지만 13시에 최종 판단해요'
              : '점심 시간 최소 활동 목표를 충족했어요',
          clearError: true,
        ),
      );
    } on Object catch (error) {
      _setState(
        state.copyWith(isLoading: false, errorMessage: '활동 평가에 실패했어요: $error'),
      );
    }
  }

  Future<void> openExactAlarmSettings() async {
    final opened = await ref
        .read(backgroundMonitoringCoordinatorProvider)
        .openExactAlarmSettings();
    _setState(
      state.copyWith(
        statusMessage: opened
            ? '정확 알람 설정 화면을 열었어요'
            : '이 플랫폼에서는 정확 알람 설정을 열 수 없어요',
      ),
    );
  }

  Future<void> openHealthConnectSettings() async {
    final opened = await ref
        .read(healthConnectPlatformServiceProvider)
        .openSettings();
    _setState(
      state.copyWith(
        statusMessage: opened
            ? 'Health Connect 설정 화면을 열었어요'
            : '이 플랫폼에서는 Health Connect 설정을 열 수 없어요',
      ),
    );
  }

  Future<void> sendGuardianTestMessage() async {
    _setState(state.copyWith(isLoading: true, clearError: true));
    try {
      final result = await ref
          .read(alertRepositoryProvider)
          .sendGuardianTestMessage(settings: state.settings);
      _setState(
        state.copyWith(
          isLoading: false,
          lastDeliveryResult: result,
          statusMessage: result.smsSent
              ? '보호자 미리보기 문자를 보냈어요'
              : result.smsFallbackOpened
              ? '문자 앱을 열었어요. 내용을 확인한 뒤 전송해 주세요'
              : result.errorMessage ?? '미리보기 문자 전송을 완료하지 못했어요',
          errorMessage: result.errorMessage,
          clearError: result.errorMessage == null,
        ),
      );
    } on Object catch (error) {
      _setState(
        state.copyWith(
          isLoading: false,
          errorMessage: '미리보기 문자 전송에 실패했어요: $error',
        ),
      );
    }
  }

  Future<void> stopMonitoring() async {
    await ref.read(backgroundMonitoringCoordinatorProvider).cancelSchedule();
    _setState(
      state.copyWith(
        session: state.session.copyWith(status: ActivitySessionStatus.idle),
        statusMessage: '백그라운드 예약을 취소했어요',
      ),
    );
  }

  void _handleBackgroundStatus(BackgroundMonitoringStatus backgroundStatus) {
    _setState(
      state.copyWith(
        backgroundStatus: backgroundStatus,
        session: backgroundStatus.lastSession,
        errorMessage: backgroundStatus.degradedReason,
      ),
    );
  }

  void _dispose() {
    _disposed = true;
    unawaited(_backgroundSubscription?.cancel());
  }

  void _setState(ActivityMonitorState nextState) {
    if (!_disposed) {
      state = nextState;
    }
  }
}
