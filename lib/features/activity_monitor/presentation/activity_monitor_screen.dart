import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/toss_theme.dart';
import '../../../../core/permissions/permission_snapshot.dart';
import '../../../../core/time/activity_window.dart';
import '../domain/entities/activity_evaluation.dart';
import '../domain/entities/activity_monitor_settings.dart';
import '../domain/entities/activity_session.dart';
import '../domain/entities/activity_threshold.dart';
import '../domain/entities/background_monitoring_status.dart';
import '../domain/entities/emergency_contact.dart';
import '../domain/entities/health_connect_step_status.dart';
import '../domain/use_cases/build_alert_message.dart';
import 'activity_monitor_providers.dart';
import 'activity_monitor_state.dart';
import 'activity_monitor_view_model.dart';

class ActivityMonitorScreen extends ConsumerStatefulWidget {
  const ActivityMonitorScreen({super.key});

  @override
  ConsumerState<ActivityMonitorScreen> createState() =>
      _ActivityMonitorScreenState();
}

class _ActivityMonitorScreenState extends ConsumerState<ActivityMonitorScreen> {
  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activityMonitorViewModelProvider);
    final viewModel = ref.read(activityMonitorViewModelProvider.notifier);

    if (!state.isInitialized) {
      return const _InitialLoadingScreen();
    }

    if (state.isOnboardingVisible) {
      return _OnboardingFlow(state: state, viewModel: viewModel);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(ActivityMonitorSettings.appName),
        actions: [
          IconButton(
            tooltip: '튜토리얼 다시 보기',
            onPressed: state.isLoading ? null : viewModel.showOnboarding,
            icon: const Icon(Icons.help_outline_rounded),
          ),
          IconButton(
            tooltip: '새로고침',
            onPressed: state.isLoading ? null : viewModel.syncSchedule,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _TabPage(
              key: const PageStorageKey<String>('home_tab'),
              children: [
                const _TabPageHeader(
                  title: '오늘 점심 활동',
                  description: '11시부터 13시까지 걷기, 이동거리, 획득고도를 자동으로 확인해요.',
                  icon: Icons.wb_sunny_rounded,
                ),
                _StatusOverview(state: state),
                const _SectionGap(),
                _ActionSection(state: state, viewModel: viewModel),
              ],
            ),
            _TabPage(
              key: const PageStorageKey<String>('goal_tab'),
              children: [
                const _TabPageHeader(
                  title: '목표 관리',
                  description: '세 가지 목표를 모두 넘으면 보호자 연락이 필요하지 않아요.',
                  icon: Icons.flag_rounded,
                ),
                _MetricsSection(
                  session: state.session,
                  settings: state.settings,
                  viewModel: viewModel,
                ),
              ],
            ),
            _TabPage(
              key: const PageStorageKey<String>('guardian_tab'),
              children: [
                const _TabPageHeader(
                  title: '보호자 연락',
                  description: '연락처와 문자 문구를 저장하고 전송 전 미리 확인해요.',
                  icon: Icons.contact_phone_rounded,
                ),
                _GuardianSection(state: state, viewModel: viewModel),
                const _SectionGap(),
                ActivitySettingsForm(settings: state.settings),
              ],
            ),
            _TabPage(
              key: const PageStorageKey<String>('readiness_tab'),
              children: [
                const _TabPageHeader(
                  title: '자동 기록 준비',
                  description: '권한, 알람, 걸음수 보정 상태를 한곳에서 점검해요.',
                  icon: Icons.verified_user_rounded,
                ),
                _ReadinessSection(
                  backgroundStatus: state.backgroundStatus,
                  healthConnectStepStatus: state.healthConnectStepStatus,
                  permissions: state.permissions,
                  viewModel: viewModel,
                ),
                if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                  const _SectionGap(),
                  const _IosLimitSection(),
                ],
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: TossColors.white,
          border: Border(top: BorderSide(color: TossColors.gray100)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag_rounded),
              label: '목표',
            ),
            NavigationDestination(
              icon: Icon(Icons.contact_phone_outlined),
              selectedIcon: Icon(Icons.contact_phone_rounded),
              label: '보호자',
            ),
            NavigationDestination(
              icon: Icon(Icons.verified_user_outlined),
              selectedIcon: Icon(Icons.verified_user_rounded),
              label: '준비',
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPage extends StatelessWidget {
  const _TabPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [...children, const SizedBox(height: 28)],
    );
  }
}

class _TabPageHeader extends StatelessWidget {
  const _TabPageHeader({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 7),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: TossColors.gray500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TossColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TossColors.gray100),
            ),
            child: Icon(icon, color: TossColors.blue, size: 23),
          ),
        ],
      ),
    );
  }
}

class _InitialLoadingScreen extends StatelessWidget {
  const _InitialLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: TossColors.white,
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      ),
    );
  }
}

class _OnboardingFlow extends StatefulWidget {
  const _OnboardingFlow({required this.state, required this.viewModel});

  final ActivityMonitorState state;
  final ActivityMonitorViewModel viewModel;

  @override
  State<_OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<_OnboardingFlow> {
  static const _stepCount = 4;

  final _pageController = PageController();
  final _goalFormKey = GlobalKey<FormState>();
  final _guardianFormKey = GlobalKey<FormState>();
  late final TextEditingController _stepsController;
  late final TextEditingController _distanceController;
  late final TextEditingController _elevationController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _messageController;
  var _currentStep = 0;
  var _guardianSaved = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.state.settings;
    _stepsController = TextEditingController(
      text: settings.threshold.minimumSteps.toString(),
    );
    _distanceController = TextEditingController(
      text: settings.threshold.minimumDistanceKilometers.toStringAsFixed(1),
    );
    _elevationController = TextEditingController(
      text: settings.threshold.minimumElevationGainMeters.toStringAsFixed(0),
    );
    _nameController = TextEditingController(
      text: settings.emergencyContact.name,
    );
    _phoneController = TextEditingController(
      text: settings.emergencyContact.phoneNumber,
    );
    _messageController = TextEditingController(
      text: settings.resolvedAlertMessageTemplate,
    );
    _messageController.addListener(_refresh);
    _stepsController.addListener(_refresh);
    _distanceController.addListener(_refresh);
    _elevationController.addListener(_refresh);
    _nameController.addListener(_refresh);
  }

  @override
  void dispose() {
    _messageController.removeListener(_refresh);
    _stepsController.removeListener(_refresh);
    _distanceController.removeListener(_refresh);
    _elevationController.removeListener(_refresh);
    _nameController.removeListener(_refresh);
    _pageController.dispose();
    _stepsController.dispose();
    _distanceController.dispose();
    _elevationController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.state.isLoading || widget.state.isSaving;

    return Scaffold(
      backgroundColor: TossColors.white,
      appBar: AppBar(
        title: const Text('처음 설정'),
        automaticallyImplyLeading: false,
        actions: [
          if (widget.state.isOnboardingCompleted)
            IconButton(
              tooltip: '닫기',
              onPressed: busy ? null : widget.viewModel.closeOnboarding,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _stepCount,
            minHeight: 3,
            backgroundColor: TossColors.gray100,
            valueColor: const AlwaysStoppedAnimation<Color>(TossColors.blue),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildIntroStep(),
                  _buildPermissionStep(),
                  _buildGoalStep(),
                  _buildGuardianStep(),
                ],
              ),
            ),
            _OnboardingBottomBar(
              currentStep: _currentStep,
              stepCount: _stepCount,
              primaryLabel: busy ? '처리 중' : _primaryLabel(),
              primaryPressed: busy ? null : _handlePrimaryPressed,
              backPressed: _currentStep == 0 || busy ? null : _previousStep,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroStep() {
    return _OnboardingStepShell(
      icon: Icons.eco_rounded,
      title: '다이어트 프로젝트 소개',
      description: '평일 점심 시간의 걷기와 이동거리를 자동으로 확인해요.',
      children: [
        const _OnboardingHighlight(
          title: '앱이 알아서 하는 일',
          description: '평일 11시에 기록을 시작하고 13시에 목표보다 낮은지 확인해요.',
          icon: Icons.auto_awesome_rounded,
        ),
        const SizedBox(height: 10),
        const _OnboardingHighlight(
          title: '사용자가 해둘 일',
          description: '권한, 최소 활동 목표, 보호자 연락처만 처음에 정해두면 돼요.',
          icon: Icons.tune_rounded,
        ),
        const SizedBox(height: 14),
        _NoticeStrip(
          message: defaultTargetPlatform == TargetPlatform.iOS
              ? 'iOS는 정책상 13시 정시 실행과 자동 문자 발송을 보장하지 않아요.'
              : 'Android는 정확 알람과 foreground service로 11시-13시에만 자동 기록해요.',
          color: TossColors.gray700,
          backgroundColor: TossColors.gray50,
        ),
      ],
    );
  }

  Widget _buildPermissionStep() {
    final permissions = widget.state.permissions;
    final backgroundStatus = widget.state.backgroundStatus;
    final healthStatus = widget.state.healthConnectStepStatus;

    return _OnboardingStepShell(
      icon: Icons.verified_user_rounded,
      title: '자동 기록 준비',
      description: '자동 기록에 필요한 권한을 한 번에 확인해요.',
      children: [
        _InfoRow(
          icon: Icons.location_on_rounded,
          title: '위치 권한',
          value: permissions.locationGranted ? '허용됨' : '필요',
          color: permissions.locationGranted
              ? TossColors.green
              : TossColors.orange,
        ),
        const _ListDivider(indent: 45),
        _InfoRow(
          icon: Icons.directions_run_rounded,
          title: '걸음수 권한',
          value: permissions.activityGranted ? '허용됨' : '필요',
          color: permissions.activityGranted
              ? TossColors.green
              : TossColors.orange,
        ),
        const _ListDivider(indent: 45),
        _InfoRow(
          icon: Icons.notifications_rounded,
          title: '알림 권한',
          value: permissions.notificationGranted ? '허용됨' : '필요',
          color: permissions.notificationGranted
              ? TossColors.green
              : TossColors.orange,
        ),
        const _ListDivider(indent: 45),
        _InfoRow(
          icon: Icons.sms_rounded,
          title: '문자 권한',
          value: !permissions.smsRequired
              ? '불필요'
              : permissions.smsGranted
              ? '허용됨'
              : '필요',
          color: !permissions.smsRequired || permissions.smsGranted
              ? TossColors.green
              : TossColors.orange,
        ),
        const _ListDivider(indent: 45),
        _InfoRow(
          icon: Icons.health_and_safety_rounded,
          title: 'Health Connect',
          value: healthStatus.label,
          color: healthStatus.available && healthStatus.readPermissionGranted
              ? TossColors.green
              : healthStatus.available
              ? TossColors.orange
              : TossColors.gray500,
        ),
        if (defaultTargetPlatform == TargetPlatform.android &&
            backgroundStatus.isNativeAvailable &&
            !backgroundStatus.exactAlarmAvailable) ...[
          const SizedBox(height: 12),
          _SoftActionButton(
            icon: Icons.alarm_rounded,
            label: '정확 알람 설정 열기',
            onPressed: widget.viewModel.openExactAlarmSettings,
          ),
        ],
        const SizedBox(height: 12),
        _NoticeStrip(
          message: _permissionNotice(),
          color: permissions.requiredPermissionsGranted
              ? TossColors.green
              : TossColors.orange,
          backgroundColor: permissions.requiredPermissionsGranted
              ? TossColors.green50
              : TossColors.orange50,
        ),
      ],
    );
  }

  Widget _buildGoalStep() {
    return _OnboardingStepShell(
      icon: Icons.flag_rounded,
      title: '점심 시간 최소 활동 목표',
      description: '13시에 이 목표보다 낮으면 보호자 연락을 준비해요.',
      children: [
        Form(
          key: _goalFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              TextFormField(
                controller: _stepsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '최소 걸음수'),
                validator: _validateSteps,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _distanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '최소 이동거리(km)'),
                validator: _validateDistance,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _elevationController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '최소 획득고도(m)'),
                validator: _validateElevationGain,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _OnboardingHighlight(
          title: '현재 입력값',
          description:
              '${_stepsController.text.trim()}걸음, ${_distanceController.text.trim()}km, 획득고도 ${_elevationController.text.trim()}m 이상이면 보호자 연락이 필요하지 않아요.',
          icon: Icons.check_circle_rounded,
        ),
      ],
    );
  }

  Widget _buildGuardianStep() {
    return _OnboardingStepShell(
      icon: Icons.contact_phone_rounded,
      title: '보호자 연락',
      description: '목표보다 낮을 때 보낼 연락처와 문자 문구를 정해요.',
      children: [
        Form(
          key: _guardianFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '보호자 이름'),
                validator: _validateContactName,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '보호자 전화번호'),
                validator: _validatePhone,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _messageController,
                minLines: 4,
                maxLines: 6,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: '보호자 문자 문구',
                  alignLabelWithHint: true,
                ),
                validator: _validateAlertTemplate,
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _TemplateTokenChip(label: '{appName}'),
            _TemplateTokenChip(label: '{steps}'),
            _TemplateTokenChip(label: '{minimumSteps}'),
            _TemplateTokenChip(label: '{distanceKm}'),
            _TemplateTokenChip(label: '{minimumDistanceKm}'),
            _TemplateTokenChip(label: '{elevationGainMeters}'),
            _TemplateTokenChip(label: '{minimumElevationGainMeters}'),
          ],
        ),
        const SizedBox(height: 12),
        _MessagePreview(message: _previewMessage()),
        const SizedBox(height: 12),
        _NoticeStrip(
          message: _guardianSaved
              ? '설정이 저장됐어요. 시작하기를 누르면 대시보드로 이동해요.'
              : '보호자 연락처는 나중에 대시보드에서도 수정할 수 있어요.',
          color: _guardianSaved ? TossColors.green : TossColors.gray700,
          backgroundColor: _guardianSaved
              ? TossColors.green50
              : TossColors.gray50,
        ),
        if (widget.state.backgroundStatus.degradedReason != null) ...[
          const SizedBox(height: 10),
          _NoticeStrip(
            message: widget.state.backgroundStatus.degradedReason!,
            color: TossColors.orange,
            backgroundColor: TossColors.orange50,
          ),
        ],
      ],
    );
  }

  String _primaryLabel() {
    return switch (_currentStep) {
      0 => '다음',
      1 => '권한 허용하고 계속',
      2 => '목표 저장하고 계속',
      _ => _guardianSaved ? '시작하기' : '보호자 설정 저장',
    };
  }

  Future<void> _handlePrimaryPressed() async {
    if (_currentStep == 0) {
      _nextStep();
      return;
    }
    if (_currentStep == 1) {
      await widget.viewModel.requestPermissions();
      if (mounted) {
        _nextStep();
      }
      return;
    }
    if (_currentStep == 2) {
      await _saveGoalAndContinue();
      return;
    }
    if (_guardianSaved) {
      await widget.viewModel.completeOnboarding();
    } else {
      await _saveGuardianSettings();
    }
  }

  Future<void> _saveGoalAndContinue() async {
    if (!(_goalFormKey.currentState?.validate() ?? false)) {
      return;
    }
    final current = widget.state.settings;
    final settings = current.copyWith(
      threshold: ActivityThreshold(
        minimumSteps: int.parse(_stepsController.text.trim()),
        minimumDistanceMeters:
            double.parse(_distanceController.text.trim()) * 1000,
        minimumElevationGainMeters: double.parse(
          _elevationController.text.trim(),
        ),
      ),
    );
    await widget.viewModel.saveSettings(settings);
    if (mounted) {
      _nextStep();
    }
  }

  Future<void> _saveGuardianSettings() async {
    if (!(_guardianFormKey.currentState?.validate() ?? false)) {
      return;
    }
    final current = widget.state.settings;
    final settings = current.copyWith(
      emergencyContact: EmergencyContact(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      ),
      alertMessageTemplate: _messageController.text.trim(),
    );
    await widget.viewModel.saveSettings(settings);
    if (mounted) {
      setState(() => _guardianSaved = true);
    }
  }

  void _nextStep() {
    final nextStep = (_currentStep + 1).clamp(0, _stepCount - 1).toInt();
    _goToStep(nextStep);
  }

  void _previousStep() {
    final previousStep = (_currentStep - 1).clamp(0, _stepCount - 1).toInt();
    _goToStep(previousStep);
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  String _permissionNotice() {
    final permissions = widget.state.permissions;
    if (permissions.requiredPermissionsGranted) {
      return '필수 권한이 준비됐어요. 이제 목표를 정하면 자동 기록을 시작할 수 있어요.';
    }
    final missing = permissions.missingLabels.join(', ');
    if (missing.isEmpty) {
      return '권한 화면에서 허용하지 않아도 계속 진행할 수 있어요. 제한 사항은 대시보드에서 다시 보여드려요.';
    }
    return '아직 부족한 권한: $missing. 거부해도 계속 진행할 수 있지만 자동 기록이 제한될 수 있어요.';
  }

  String _previewMessage() {
    final threshold = _currentThreshold();
    final settings = widget.state.settings.copyWith(
      threshold: threshold,
      emergencyContact: EmergencyContact(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      ),
      alertMessageTemplate: _messageController.text,
    );
    final evaluation = ActivityEvaluation(
      steps: threshold.minimumSteps > 500 ? threshold.minimumSteps - 500 : 0,
      distanceMeters: threshold.minimumDistanceMeters * 0.7,
      elevationGainMeters: threshold.minimumElevationGainMeters * 0.7,
      threshold: threshold,
      evaluatedAt: DateTime.now(),
    );
    return const BuildAlertMessage()(
      settings: settings,
      evaluation: evaluation,
    );
  }

  ActivityThreshold _currentThreshold() {
    final steps = int.tryParse(_stepsController.text.trim());
    final distanceKm = double.tryParse(_distanceController.text.trim());
    final elevationGainMeters = double.tryParse(
      _elevationController.text.trim(),
    );
    return ActivityThreshold(
      minimumSteps: steps ?? widget.state.settings.threshold.minimumSteps,
      minimumDistanceMeters:
          (distanceKm ??
              widget.state.settings.threshold.minimumDistanceKilometers) *
          1000,
      minimumElevationGainMeters:
          elevationGainMeters ??
          widget.state.settings.threshold.minimumElevationGainMeters,
    );
  }

  String? _validateContactName(String? value) {
    final name = value?.trim() ?? '';
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty && name.isEmpty) {
      return '연락처 이름을 입력해 주세요.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    final name = _nameController.text.trim();
    if (name.isNotEmpty && phone.isEmpty) {
      return '전화번호를 입력해 주세요.';
    }
    if (phone.isEmpty) {
      return null;
    }
    final normalized = phone.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\+?\d{7,15}$').hasMatch(normalized)) {
      return '전화번호 형식을 확인해 주세요.';
    }
    return null;
  }

  String? _validateAlertTemplate(String? value) {
    final template = value?.trim() ?? '';
    if (template.isEmpty) {
      return '보호자에게 보낼 문자 문구를 입력해 주세요.';
    }
    if (template.length > 500) {
      return '문자 문구는 500자 이하로 입력해 주세요.';
    }
    return null;
  }
}

class _OnboardingStepShell extends StatelessWidget {
  const _OnboardingStepShell({
    required this.icon,
    required this.title,
    required this.description,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TossColors.blue50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: TossColors.blue, size: 28),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontSize: 30, height: 1.18),
        ),
        const SizedBox(height: 9),
        Text(description, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 26),
        ...children,
      ],
    );
  }
}

class _OnboardingHighlight extends StatelessWidget {
  const _OnboardingHighlight({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TossColors.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TinyIcon(icon: icon),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: TossColors.gray500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingBottomBar extends StatelessWidget {
  const _OnboardingBottomBar({
    required this.currentStep,
    required this.stepCount,
    required this.primaryLabel,
    required this.primaryPressed,
    required this.backPressed,
  });

  final int currentStep;
  final int stepCount;
  final String primaryLabel;
  final VoidCallback? primaryPressed;
  final VoidCallback? backPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      decoration: const BoxDecoration(
        color: TossColors.white,
        border: Border(top: BorderSide(color: TossColors.gray100)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: backPressed == null
                ? Text(
                    '${currentStep + 1}/$stepCount',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: TossColors.gray500),
                  )
                : TextButton(onPressed: backPressed, child: const Text('이전')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: primaryPressed,
              child: Text(primaryLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusOverview extends StatelessWidget {
  const _StatusOverview({required this.state});

  final ActivityMonitorState state;

  @override
  Widget build(BuildContext context) {
    final session = state.session;
    final statusTone = _statusTone(session);

    return _Section(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '평일 11:00-13:00',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: TossColors.gray500,
                    fontSize: 13,
                  ),
                ),
              ),
              _StatusPill(
                label: _sessionBadgeText(session),
                color: statusTone,
                filled: session.isActive,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _phaseHeadline(state.windowPhase, session),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 30,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _phaseBody(state.windowPhase, session),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              _HeroStatusMark(
                icon: _phaseIcon(state.windowPhase, session),
                color: statusTone,
              ),
            ],
          ),
          const SizedBox(height: 22),
          _DailySummary(session: session, tone: statusTone),
          if (state.statusMessage != null) ...[
            const SizedBox(height: 14),
            _NoticeStrip(
              message: state.statusMessage!,
              color: TossColors.blue,
              backgroundColor: TossColors.blue50,
            ),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: 14),
            _NoticeStrip(
              message: state.errorMessage!,
              color: TossColors.red,
              backgroundColor: TossColors.red50,
            ),
          ],
        ],
      ),
    );
  }

  Color _statusTone(ActivitySession session) {
    if (session.evaluation?.requiresAlert ?? false) {
      return TossColors.red;
    }
    if (session.isActive) {
      return TossColors.blue;
    }
    return TossColors.green;
  }

  String _sessionBadgeText(ActivitySession session) {
    return switch (session.status) {
      ActivitySessionStatus.idle => '대기',
      ActivitySessionStatus.active => '측정 중',
      ActivitySessionStatus.evaluated =>
        session.evaluation?.requiresAlert ?? false ? '주의' : '완료',
    };
  }

  String _phaseHeadline(ActivityWindowPhase phase, ActivitySession session) {
    if (session.evaluation?.requiresAlert ?? false) {
      return '오늘 활동이\n부족해요';
    }
    if (session.status == ActivitySessionStatus.evaluated) {
      return '오늘 최소 목표를\n확인했어요';
    }
    return switch (phase) {
      ActivityWindowPhase.beforeWindow => '오전 11시에\n자동으로 시작해요',
      ActivityWindowPhase.active => '지금 활동을\n측정하고 있어요',
      ActivityWindowPhase.afterWindow => '오늘 평가 시간이\n지났어요',
      ActivityWindowPhase.weekend => '주말에는\n쉬어가요',
    };
  }

  String _phaseBody(ActivityWindowPhase phase, ActivitySession session) {
    if (session.isActive) {
      return '13시에 점심 시간 최소 활동 목표를 넘었는지 확인해요.';
    }
    if (session.status == ActivitySessionStatus.evaluated) {
      return session.evaluation?.requiresAlert ?? false
          ? '최소 활동 목표보다 낮아 보호자 연락을 준비했어요.'
          : '최소 활동 목표를 넘어서 보호자 연락이 필요하지 않아요.';
    }
    return switch (phase) {
      ActivityWindowPhase.beforeWindow => '앱을 닫아도 가능한 범위에서 점심 활동을 챙겨요.',
      ActivityWindowPhase.active => '백그라운드에서도 가능한 범위에서 기록을 이어가요.',
      ActivityWindowPhase.afterWindow => '필요하면 오늘 기록을 다시 평가할 수 있어요.',
      ActivityWindowPhase.weekend => '다음 평일 점심 시간에 다시 준비돼요.',
    };
  }

  IconData _phaseIcon(ActivityWindowPhase phase, ActivitySession session) {
    if (session.evaluation?.requiresAlert ?? false) {
      return Icons.priority_high_rounded;
    }
    if (session.status == ActivitySessionStatus.evaluated) {
      return Icons.check_rounded;
    }
    if (session.isActive) {
      return Icons.near_me_rounded;
    }
    return switch (phase) {
      ActivityWindowPhase.beforeWindow => Icons.schedule_rounded,
      ActivityWindowPhase.active => Icons.near_me_rounded,
      ActivityWindowPhase.afterWindow => Icons.fact_check_rounded,
      ActivityWindowPhase.weekend => Icons.weekend_rounded,
    };
  }
}

class _HeroStatusMark extends StatelessWidget {
  const _HeroStatusMark({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: color, size: 34),
    );
  }
}

class _DailySummary extends StatelessWidget {
  const _DailySummary({required this.session, required this.tone});

  final ActivitySession session;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        final items = [
          _SummaryItem(
            icon: Icons.directions_walk_rounded,
            label: '걸음수',
            value: '${session.steps}',
            unit: '걸음',
            color: tone,
          ),
          _SummaryItem(
            icon: Icons.route_rounded,
            label: '이동거리',
            value: (session.distanceMeters / 1000).toStringAsFixed(2),
            unit: 'km',
            color: tone,
          ),
          _SummaryItem(
            icon: Icons.terrain_rounded,
            label: '획득고도',
            value: session.elevationGainMeters.toStringAsFixed(0),
            unit: 'm',
            color: tone,
          ),
        ];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TossColors.gray50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: compact
              ? Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      items[index],
                      if (index != items.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(),
                        ),
                    ],
                  ],
                )
              : Row(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      Expanded(child: items[index]),
                      if (index != items.length - 1)
                        Container(
                          width: 1,
                          height: 48,
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          color: TossColors.gray100,
                        ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TossColors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: TossColors.gray500),
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    text: value,
                    children: [
                      TextSpan(
                        text: unit,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: TossColors.gray500, fontSize: 15),
                      ),
                    ],
                  ),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontSize: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricsSection extends StatelessWidget {
  const _MetricsSection({
    required this.session,
    required this.settings,
    required this.viewModel,
  });

  final ActivitySession session;
  final ActivityMonitorSettings settings;
  final ActivityMonitorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final threshold = settings.threshold;
    final stepProgress = _progress(
      session.steps.toDouble(),
      threshold.minimumSteps.toDouble(),
    );
    final distanceProgress = _progress(
      session.distanceMeters,
      threshold.minimumDistanceMeters,
    );
    final elevationProgress = _progress(
      session.elevationGainMeters,
      threshold.minimumElevationGainMeters,
    );

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: '점심 시간 최소 활동 목표',
            description: '13시에 오늘 기록이 이 목표보다 낮으면 강한 알림과 보호자 연락을 준비해요.',
            trailing: TextButton(
              onPressed: () => _openGoalEditor(context),
              child: const Text('목표 수정'),
            ),
          ),
          const SizedBox(height: 8),
          const _GoalRuleBanner(),
          const SizedBox(height: 6),
          _MetricRow(
            icon: Icons.directions_walk_rounded,
            label: '최소 걸음수',
            value: '${session.steps}걸음',
            target: '${threshold.minimumSteps}걸음 이상',
            progress: stepProgress,
            color: TossColors.blue,
          ),
          const _ListDivider(),
          _MetricRow(
            icon: Icons.route_rounded,
            label: '최소 이동거리',
            value: _formatKilometers(session.distanceMeters),
            target: '${_formatKilometers(threshold.minimumDistanceMeters)} 이상',
            progress: distanceProgress,
            color: TossColors.green,
          ),
          const _ListDivider(),
          _MetricRow(
            icon: Icons.terrain_rounded,
            label: '최소 획득고도',
            value: '${session.elevationGainMeters.toStringAsFixed(0)}m',
            target:
                '${threshold.minimumElevationGainMeters.toStringAsFixed(0)}m 이상',
            progress: elevationProgress,
            color: TossColors.orange,
          ),
          const SizedBox(height: 8),
          const _NoticeStrip(
            message: '획득고도는 11:00-11:30 평균 고도를 기준으로, 이후 가장 높게 올라간 차이를 사용해요.',
            color: TossColors.gray700,
            backgroundColor: TossColors.gray50,
          ),
        ],
      ),
    );
  }

  double _progress(double value, double target) {
    if (target <= 0) {
      return 1;
    }
    return (value / target).clamp(0.0, 1.0).toDouble();
  }

  Future<void> _openGoalEditor(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: TossColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) => _GoalEditSheet(
        settings: settings,
        onSave: (threshold) {
          viewModel.saveSettings(settings.copyWith(threshold: threshold));
        },
      ),
    );
  }
}

class _GoalRuleBanner extends StatelessWidget {
  const _GoalRuleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TossColors.blue50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TossColors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.done_all_rounded,
              color: TossColors.blue,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '통과 기준은 걸음수, 이동거리, 획득고도 모두 목표 이상이에요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: TossColors.gray900,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.target,
    required this.progress,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String target;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TinyIcon(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Text(
                target,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: TossColors.gray500),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 24,
              color: TossColors.gray900,
            ),
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progress,
              backgroundColor: TossColors.gray100,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalEditSheet extends StatefulWidget {
  const _GoalEditSheet({required this.settings, required this.onSave});

  final ActivityMonitorSettings settings;
  final ValueChanged<ActivityThreshold> onSave;

  @override
  State<_GoalEditSheet> createState() => _GoalEditSheetState();
}

class _GoalEditSheetState extends State<_GoalEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _stepsController;
  late final TextEditingController _distanceController;
  late final TextEditingController _elevationController;

  @override
  void initState() {
    super.initState();
    _stepsController = TextEditingController(
      text: widget.settings.threshold.minimumSteps.toString(),
    );
    _distanceController = TextEditingController(
      text: widget.settings.threshold.minimumDistanceKilometers.toStringAsFixed(
        1,
      ),
    );
    _elevationController = TextEditingController(
      text: widget.settings.threshold.minimumElevationGainMeters
          .toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _stepsController.dispose();
    _distanceController.dispose();
    _elevationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 22, 24, bottomInset + 24),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(
              title: '최소 활동 목표 수정',
              description: '평일 13시에 이 목표보다 낮으면 보호자 연락을 준비해요.',
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _stepsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '최소 걸음수'),
              validator: _validateSteps,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _distanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '최소 이동거리(km)'),
              validator: _validateDistance,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _elevationController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '최소 획득고도(m)'),
              validator: _validateElevationGain,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('목표 저장')),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final steps = int.parse(_stepsController.text.trim());
    final distanceKm = double.parse(_distanceController.text.trim());
    final elevationGainMeters = double.parse(_elevationController.text.trim());
    widget.onSave(
      ActivityThreshold(
        minimumSteps: steps,
        minimumDistanceMeters: distanceKm * 1000,
        minimumElevationGainMeters: elevationGainMeters,
      ),
    );
    Navigator.of(context).pop();
  }
}

String? _validateSteps(String? value) {
  final steps = int.tryParse(value?.trim() ?? '');
  if (steps == null) {
    return '숫자로 입력해 주세요.';
  }
  if (steps <= 0) {
    return '1걸음 이상으로 입력해 주세요.';
  }
  if (steps > 100000) {
    return '100,000걸음 이하로 입력해 주세요.';
  }
  return null;
}

String? _validateDistance(String? value) {
  final distance = double.tryParse(value?.trim() ?? '');
  if (distance == null) {
    return '숫자로 입력해 주세요.';
  }
  if (distance <= 0) {
    return '0보다 큰 거리로 입력해 주세요.';
  }
  if (distance > 100) {
    return '100km 이하로 입력해 주세요.';
  }
  return null;
}

String? _validateElevationGain(String? value) {
  final elevationGain = double.tryParse(value?.trim() ?? '');
  if (elevationGain == null) {
    return '숫자로 입력해 주세요.';
  }
  if (elevationGain < 0) {
    return '0m 이상으로 입력해 주세요.';
  }
  if (elevationGain > 3000) {
    return '3,000m 이하로 입력해 주세요.';
  }
  return null;
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({required this.state, required this.viewModel});

  final ActivityMonitorState state;
  final ActivityMonitorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final permissionsReady = state.permissions.requiredPermissionsGranted;
    final isActive = state.session.isActive;
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(
            title: '기록과 확인',
            description: '앱은 평일 11시에 자동으로 기록하고 13시에 목표 달성 여부를 확인해요.',
          ),
          const SizedBox(height: 14),
          const _AutomationFlow(),
          const SizedBox(height: 14),
          if (!permissionsReady)
            _ActionTile(
              icon: Icons.verified_user_rounded,
              title: '자동 기록을 위해 권한 허용하기',
              description: '위치, 걸음수, 알림, 문자 권한이 있어야 11시-13시 기록이 안정적으로 동작해요.',
              onPressed: state.isLoading ? null : viewModel.requestPermissions,
              emphasized: true,
            )
          else if (isActive)
            _ActionTile(
              icon: Icons.fact_check_rounded,
              title: '지금까지 기록으로 보호자 연락 여부 확인',
              description: '현재까지의 걸음수와 이동거리로 최소 활동 목표를 넘었는지 평가해요.',
              onPressed: state.isLoading
                  ? null
                  : viewModel.stopMonitoringAndEvaluate,
              emphasized: true,
            )
          else
            _ActionTile(
              icon: Icons.play_arrow_rounded,
              title: '수동으로 점심 활동 기록 시작',
              description: '자동 기록이 시작되지 않았거나 테스트가 필요할 때만 눌러요.',
              onPressed: state.isLoading ? null : viewModel.startMonitoring,
              emphasized: true,
            ),
          if (!isActive && permissionsReady) ...[
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.fact_check_rounded,
              title: '저장된 오늘 기록으로 바로 확인',
              description: '기록이 끝난 뒤 보호자 연락이 필요한지 다시 판단해요.',
              onPressed: state.isLoading
                  ? null
                  : viewModel.stopMonitoringAndEvaluate,
            ),
          ],
          if (isActive) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: state.isLoading ? null : viewModel.stopMonitoring,
              child: const Text('기록을 중단하고 자동 예약 끄기'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AutomationFlow extends StatelessWidget {
  const _AutomationFlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TossColors.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _FlowStep(time: '11:00', label: '자동 기록'),
          ),
          _FlowArrow(),
          Expanded(
            child: _FlowStep(time: '13:00', label: '목표 확인'),
          ),
          _FlowArrow(),
          Expanded(
            child: _FlowStep(time: '부족할 때', label: '보호자 연락'),
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({required this.time, required this.label});

  final String time;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          time,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: TossColors.blue,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: TossColors.gray900,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.chevron_right_rounded,
        color: TossColors.gray500,
        size: 18,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onPressed,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final backgroundColor = emphasized && enabled
        ? TossColors.blue
        : TossColors.gray50;
    final titleColor = emphasized && enabled
        ? TossColors.white
        : enabled
        ? TossColors.gray900
        : TossColors.gray500;
    final descriptionColor = emphasized && enabled
        ? TossColors.blue100
        : TossColors.gray500;
    final iconBackgroundColor = emphasized && enabled
        ? TossColors.white.withValues(alpha: 0.14)
        : TossColors.white;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: titleColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: titleColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: descriptionColor),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: titleColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadinessSection extends StatelessWidget {
  const _ReadinessSection({
    required this.backgroundStatus,
    required this.healthConnectStepStatus,
    required this.permissions,
    required this.viewModel,
  });

  final BackgroundMonitoringStatus backgroundStatus;
  final HealthConnectStepStatus healthConnectStepStatus;
  final PermissionSnapshot permissions;
  final ActivityMonitorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final modeColor = backgroundStatus.isDegraded
        ? TossColors.orange
        : TossColors.blue;

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: '자동 기록 준비 상태',
            description: '평일 11시에 기록을 시작하고 13시에 목표 달성 여부를 확인하기 위한 설정이에요.',
          ),
          const SizedBox(height: 14),
          _ReadinessScoreCard(
            readyCount: _readyCheckCount(),
            totalCount: _totalCheckCount(),
            isDegraded: backgroundStatus.isDegraded,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            title: '평일 11시 자동 시작',
            value: _modeText(backgroundStatus.mode),
            color: modeColor,
          ),
          const _ListDivider(indent: 45),
          _InfoRow(
            icon: Icons.alarm_rounded,
            title: '13시 자동 평가 알람',
            value: backgroundStatus.exactAlarmAvailable ? '켜짐' : '필요',
            color: backgroundStatus.exactAlarmAvailable
                ? TossColors.green
                : TossColors.orange,
            trailing:
                !backgroundStatus.exactAlarmAvailable &&
                    backgroundStatus.isNativeAvailable
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatusPill(label: '필요', color: TossColors.orange),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: viewModel.openExactAlarmSettings,
                        child: const Text('설정'),
                      ),
                    ],
                  )
                : null,
          ),
          const _ListDivider(indent: 45),
          _InfoRow(
            icon: Icons.health_and_safety_rounded,
            title: 'Health Connect 걸음수 보정',
            value: healthConnectStepStatus.label,
            color:
                healthConnectStepStatus.available &&
                    healthConnectStepStatus.readPermissionGranted
                ? TossColors.green
                : healthConnectStepStatus.available
                ? TossColors.orange
                : TossColors.gray500,
            trailing:
                healthConnectStepStatus.available &&
                    !healthConnectStepStatus.readPermissionGranted
                ? TextButton(
                    onPressed: viewModel.requestPermissions,
                    child: const Text('권한 허용'),
                  )
                : null,
          ),
          const _ListDivider(indent: 45),
          _InfoRow(
            icon: Icons.location_on_rounded,
            title: '위치 권한',
            value: permissions.locationGranted ? '허용됨' : '필요',
            color: permissions.locationGranted
                ? TossColors.green
                : TossColors.orange,
          ),
          const _ListDivider(indent: 45),
          _InfoRow(
            icon: Icons.directions_run_rounded,
            title: '활동 권한',
            value: permissions.activityGranted ? '허용됨' : '필요',
            color: permissions.activityGranted
                ? TossColors.green
                : TossColors.orange,
          ),
          const _ListDivider(indent: 45),
          _InfoRow(
            icon: Icons.notifications_rounded,
            title: '알림 권한',
            value: permissions.notificationGranted ? '허용됨' : '필요',
            color: permissions.notificationGranted
                ? TossColors.green
                : TossColors.orange,
          ),
          const _ListDivider(indent: 45),
          _InfoRow(
            icon: Icons.sms_rounded,
            title: '문자 권한',
            value: !permissions.smsRequired
                ? '불필요'
                : permissions.smsGranted
                ? '허용됨'
                : '필요',
            color: !permissions.smsRequired || permissions.smsGranted
                ? TossColors.green
                : TossColors.orange,
          ),
          if (backgroundStatus.degradedReason != null) ...[
            const SizedBox(height: 12),
            _NoticeStrip(
              message: backgroundStatus.degradedReason!,
              color: TossColors.orange,
              backgroundColor: TossColors.orange50,
            ),
          ],
          if (healthConnectStepStatus.message != null) ...[
            const SizedBox(height: 10),
            _NoticeStrip(
              message: healthConnectStepStatus.message!,
              color: TossColors.gray700,
              backgroundColor: TossColors.gray50,
            ),
          ],
        ],
      ),
    );
  }

  String _modeText(BackgroundMonitoringMode mode) {
    return switch (mode) {
      BackgroundMonitoringMode.foregroundOnly => '대기',
      BackgroundMonitoringMode.scheduled => '예약됨',
      BackgroundMonitoringMode.running => '실행 중',
      BackgroundMonitoringMode.degraded => '제한됨',
    };
  }

  int _readyCheckCount() {
    return _readinessChecks().where((ready) => ready).length;
  }

  int _totalCheckCount() {
    return _readinessChecks().length;
  }

  List<bool> _readinessChecks() {
    return [
      !backgroundStatus.isNativeAvailable ||
          backgroundStatus.exactAlarmAvailable,
      !healthConnectStepStatus.available ||
          healthConnectStepStatus.readPermissionGranted,
      permissions.locationGranted,
      permissions.activityGranted,
      permissions.notificationGranted,
      !permissions.smsRequired || permissions.smsGranted,
    ];
  }
}

class _ReadinessScoreCard extends StatelessWidget {
  const _ReadinessScoreCard({
    required this.readyCount,
    required this.totalCount,
    required this.isDegraded,
  });

  final int readyCount;
  final int totalCount;
  final bool isDegraded;

  @override
  Widget build(BuildContext context) {
    final complete = readyCount == totalCount && !isDegraded;
    final color = complete ? TossColors.green : TossColors.orange;
    final label = complete ? '자동 기록 가능' : '확인 필요';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TossColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              complete
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: TossColors.gray900),
                ),
                const SizedBox(height: 3),
                Text(
                  '$totalCount개 항목 중 $readyCount개가 준비됐어요.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: TossColors.gray700),
                ),
              ],
            ),
          ),
          _StatusPill(label: '$readyCount/$totalCount', color: color),
        ],
      ),
    );
  }
}

class _GuardianSection extends StatelessWidget {
  const _GuardianSection({required this.state, required this.viewModel});

  final ActivityMonitorState state;
  final ActivityMonitorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final contact = state.settings.emergencyContact;
    final complete = contact.isComplete;

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: '보호자 연락처',
            description: '점심 시간 최소 활동 목표를 넘지 못했을 때 연락할 사람을 확인해요.',
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.person_rounded,
            title: complete ? contact.name : '보호자 미설정',
            value: complete ? '연락 가능' : '입력 필요',
            color: complete ? TossColors.green : TossColors.orange,
          ),
          const _ListDivider(indent: 45),
          _InfoRow(
            icon: Icons.phone_rounded,
            title: complete ? _maskPhone(contact.phoneNumber) : '전화번호를 입력해 주세요',
            value: complete ? '저장됨' : '입력 필요',
            color: complete ? TossColors.green : TossColors.gray500,
          ),
          const _ListDivider(indent: 45),
          _InfoRow(
            icon: Icons.chat_bubble_rounded,
            title: '보호자 문자 문구',
            value:
                state.settings.resolvedAlertMessageTemplate ==
                    ActivityMonitorSettings.defaultAlertMessageTemplate
                ? '기본'
                : '직접 편집',
            color: TossColors.blue,
          ),
          const SizedBox(height: 14),
          _SoftActionButton(
            icon: Icons.sms_rounded,
            label: '보호자에게 미리보기 문자 보내기',
            onPressed: complete && !state.isLoading
                ? () => _confirmTestMessage(context)
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            '저장된 보호자 번호로 현재 문자 문구가 전송돼요.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: TossColors.gray500),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmTestMessage(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('미리보기 문자를 보낼까요?'),
        content: const Text('저장된 보호자 번호로 현재 문자 문구가 전송될 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('보내기'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await viewModel.sendGuardianTestMessage();
    }
  }

  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) {
      return phone;
    }
    final prefix = digits.substring(0, digits.length - 4);
    final suffix = digits.substring(digits.length - 4);
    return '$prefix-$suffix';
  }
}

class _IosLimitSection extends StatelessWidget {
  const _IosLimitSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'iOS에서 알아둘 점'),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.schedule_rounded,
            title: '13시 정시 실행',
            value: '보장 안 됨',
            color: TossColors.orange,
          ),
          const _ListDivider(indent: 45),
          _InfoRow(
            icon: Icons.location_on_rounded,
            title: '상시 위치 권한',
            value: '필요',
            color: TossColors.orange,
          ),
          const _ListDivider(indent: 45),
          _InfoRow(
            icon: Icons.sms_rounded,
            title: '자동 문자 발송',
            value: '미지원',
            color: TossColors.gray500,
          ),
          const SizedBox(height: 12),
          const _NoticeStrip(
            message:
                'iOS는 앱 강제 종료나 백그라운드 제한 상태에서 정확한 실행을 보장하지 않아요. 알림 후 사용자가 직접 문자 전송을 확인하는 흐름으로 동작해요.',
            color: TossColors.gray700,
            backgroundColor: TossColors.gray50,
          ),
        ],
      ),
    );
  }
}

class ActivitySettingsForm extends ConsumerStatefulWidget {
  const ActivitySettingsForm({super.key, required this.settings});

  final ActivityMonitorSettings settings;

  @override
  ConsumerState<ActivitySettingsForm> createState() =>
      _ActivitySettingsFormState();
}

class _ActivitySettingsFormState extends ConsumerState<ActivitySettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _messageController = TextEditingController();
    _syncControllers(widget.settings);
    _nameController.addListener(_refreshPreview);
    _phoneController.addListener(_refreshPreview);
    _messageController.addListener(_refreshPreview);
  }

  @override
  void didUpdateWidget(ActivitySettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _syncControllers(widget.settings);
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshPreview);
    _phoneController.removeListener(_refreshPreview);
    _messageController.removeListener(_refreshPreview);
    _nameController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activityMonitorViewModelProvider);

    return _Section(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(
              title: '보호자 연락처 설정',
              description: '최소 활동 목표보다 낮을 때 연락할 보호자 정보를 입력해요.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: '보호자 이름'),
              validator: _validateContactName,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '보호자 전화번호'),
              validator: _validatePhone,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _messageController,
              minLines: 4,
              maxLines: 7,
              maxLength: 500,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: '보호자 문자 문구',
                alignLabelWithHint: true,
              ),
              validator: _validateAlertTemplate,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _TemplateTokenChip(label: '{appName}'),
                _TemplateTokenChip(label: '{steps}'),
                _TemplateTokenChip(label: '{minimumSteps}'),
                _TemplateTokenChip(label: '{distanceKm}'),
                _TemplateTokenChip(label: '{minimumDistanceKm}'),
                _TemplateTokenChip(label: '{elevationGainMeters}'),
                _TemplateTokenChip(label: '{minimumElevationGainMeters}'),
              ],
            ),
            const SizedBox(height: 12),
            _MessagePreview(message: _previewMessage()),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _resetMessageTemplate,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('기본 문구로 되돌리기'),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: state.isSaving ? null : _save,
              child: Text(state.isSaving ? '저장 중' : '저장'),
            ),
          ],
        ),
      ),
    );
  }

  void _syncControllers(ActivityMonitorSettings settings) {
    _nameController.text = settings.emergencyContact.name;
    _phoneController.text = settings.emergencyContact.phoneNumber;
    _messageController.text = settings.resolvedAlertMessageTemplate;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final current = ref.read(activityMonitorViewModelProvider).settings;
    final settings = current.copyWith(
      emergencyContact: EmergencyContact(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      ),
      alertMessageTemplate: _messageController.text.trim(),
    );

    ref.read(activityMonitorViewModelProvider.notifier).saveSettings(settings);
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  void _resetMessageTemplate() {
    _messageController.text =
        ActivityMonitorSettings.defaultAlertMessageTemplate;
  }

  String _previewMessage() {
    final current = ref.watch(activityMonitorViewModelProvider).settings;
    final threshold = current.threshold;
    final previewSettings = current.copyWith(
      emergencyContact: EmergencyContact(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      ),
      alertMessageTemplate: _messageController.text,
    );
    final evaluation = ActivityEvaluation(
      steps: threshold.minimumSteps > 500 ? threshold.minimumSteps - 500 : 0,
      distanceMeters: threshold.minimumDistanceMeters * 0.7,
      elevationGainMeters: threshold.minimumElevationGainMeters * 0.7,
      threshold: threshold,
      evaluatedAt: DateTime.now(),
    );
    return const BuildAlertMessage()(
      settings: previewSettings,
      evaluation: evaluation,
    );
  }

  String? _validateContactName(String? value) {
    final name = value?.trim() ?? '';
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty && name.isEmpty) {
      return '연락처 이름을 입력해 주세요.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    final name = _nameController.text.trim();
    if (name.isNotEmpty && phone.isEmpty) {
      return '전화번호를 입력해 주세요.';
    }
    if (phone.isEmpty) {
      return null;
    }
    final normalized = phone.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\+?\d{7,15}$').hasMatch(normalized)) {
      return '전화번호 형식을 확인해 주세요.';
    }
    return null;
  }

  String? _validateAlertTemplate(String? value) {
    final template = value?.trim() ?? '';
    if (template.isEmpty) {
      return '보호자에게 보낼 문자 문구를 입력해 주세요.';
    }
    if (template.length > 500) {
      return '문자 문구는 500자 이하로 입력해 주세요.';
    }
    return null;
  }
}

class _TemplateTokenChip extends StatelessWidget {
  const _TemplateTokenChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: TossColors.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: TossColors.gray700,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MessagePreview extends StatelessWidget {
  const _MessagePreview({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TossColors.blue50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '전송 문구 미리보기',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: TossColors.blue,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: TossColors.gray900,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 22, 24, 24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TossColors.white,
      child: Padding(padding: padding, child: child),
    );
  }
}

class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: TossColors.gray50,
      child: SizedBox(height: 10),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.description, this.trailing});

  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (description != null) ...[
                const SizedBox(height: 5),
                Text(
                  description!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: TossColors.gray500),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Row(
        children: [
          _TinyIcon(icon: icon),
          const SizedBox(width: 13),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
          ),
          if (trailing != null) ...[
            trailing!,
          ] else
            _StatusPill(label: value, color: color),
        ],
      ),
    );
  }
}

class _TinyIcon extends StatelessWidget {
  const _TinyIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: TossColors.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: TossColors.gray500),
    );
  }
}

class _SoftActionButton extends StatelessWidget {
  const _SoftActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: enabled ? TossColors.gray50 : TossColors.gray100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: enabled ? TossColors.gray700 : TossColors.gray500,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: enabled ? TossColors.gray900 : TossColors.gray500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: filled ? TossColors.white : color,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _NoticeStrip extends StatelessWidget {
  const _NoticeStrip({
    required this.message,
    required this.color,
    required this.backgroundColor,
  });

  final String message;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
      ),
    );
  }
}

class _ListDivider extends StatelessWidget {
  const _ListDivider({this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: const Divider(),
    );
  }
}

String _formatKilometers(double meters) {
  return '${(meters / 1000).toStringAsFixed(2)}km';
}
