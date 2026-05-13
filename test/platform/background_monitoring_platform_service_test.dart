import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diet/features/activity_monitor/domain/entities/activity_session.dart';
import 'package:diet/platform/background/background_monitoring_platform_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('diet/background_monitoring');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('currentStatus maps native diagnostics and SMS status', () async {
    final startedAt = DateTime(2026, 5, 13, 11);
    final endedAt = DateTime(2026, 5, 13, 13);
    final smsAttemptedAt = DateTime(2026, 5, 13, 13, 1);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'currentStatus');
          return <String, Object?>{
            'nativeAvailable': true,
            'isScheduled': true,
            'isRunning': false,
            'exactAlarmAvailable': true,
            'locationAlwaysGranted': true,
            'sessionStatus': 'evaluated',
            'startedAtMillis': startedAt.millisecondsSinceEpoch,
            'endedAtMillis': endedAt.millisecondsSinceEpoch,
            'steps': 1800,
            'distanceMeters': 920.0,
            'elevationGainMeters': 35.0,
            'acceptedGpsSegmentCount': 7,
            'rejectedStationarySegmentCount': 2,
            'rejectedFastSegmentCount': 1,
            'rejectedPoorAccuracySampleCount': 3,
            'ignoredStepCount': 65,
            'smsLastStatus': 'failed',
            'smsLastError': '문자 권한이 없어요.',
            'smsLastAttemptedAtMillis': smsAttemptedAt.millisecondsSinceEpoch,
            'smsLastPhone': '01012345678',
            'smsLastDateKey': '2026-5-13',
          };
        });

    final status = await BackgroundMonitoringPlatformService().currentStatus();

    expect(status.isNativeAvailable, isTrue);
    expect(status.isScheduled, isTrue);
    expect(status.exactAlarmAvailable, isTrue);
    expect(status.lastSession.status, ActivitySessionStatus.evaluated);
    expect(status.lastSession.steps, 1800);
    expect(status.lastSession.acceptedGpsSegmentCount, 7);
    expect(status.lastSession.rejectedStationarySegmentCount, 2);
    expect(status.lastSession.rejectedFastSegmentCount, 1);
    expect(status.lastSession.rejectedPoorAccuracySampleCount, 3);
    expect(status.lastSession.ignoredStepCount, 65);
    expect(status.smsDelivery.label, '발송 실패');
    expect(status.smsDelivery.error, '문자 권한이 없어요.');
    expect(status.smsDelivery.attemptedAt, smsAttemptedAt);
    expect(status.smsDelivery.phoneNumber, '01012345678');
  });
}
