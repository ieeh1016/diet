import 'package:flutter/services.dart';

import '../../features/activity_monitor/domain/entities/activity_session.dart';
import '../../features/activity_monitor/domain/entities/background_monitoring_status.dart';
import '../../features/activity_monitor/domain/entities/monitoring_window.dart';

class BackgroundMonitoringPlatformService {
  static const _channel = MethodChannel('diet/background_monitoring');

  Future<BackgroundMonitoringStatus> currentStatus() async {
    final response = await _invokeMap('currentStatus');
    return _statusFromMap(response);
  }

  Future<BackgroundMonitoringStatus> scheduleWeekdayMonitoring(
    MonitoringWindow window,
  ) async {
    final response = await _invokeMap(
      'scheduleWeekdayMonitoring',
      _windowArguments(window),
    );
    return _statusFromMap(response);
  }

  Future<ActivitySession> startWindow(MonitoringWindow window) async {
    final response = await _invokeMap('startWindow', _windowArguments(window));
    return _sessionFromMap(response);
  }

  Future<ActivitySession> stopAndEvaluate(
    MonitoringWindow window, {
    bool nativeEvaluate = false,
  }) async {
    final response = await _invokeMap('stopAndEvaluate', <String, Object?>{
      ..._windowArguments(window),
      'nativeEvaluate': nativeEvaluate,
    });
    return _sessionFromMap(response);
  }

  Future<bool> openExactAlarmSettings() async {
    try {
      final opened = await _channel.invokeMethod<bool>(
        'openExactAlarmSettings',
      );
      return opened ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> cancelSchedule() async {
    await _channel.invokeMethod<void>('cancelSchedule');
  }

  Map<String, int> _windowArguments(MonitoringWindow window) {
    return <String, int>{
      'startMillis': window.start.millisecondsSinceEpoch,
      'endMillis': window.end.millisecondsSinceEpoch,
    };
  }

  Future<Map<String, Object?>> _invokeMap(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      final response = await _channel.invokeMapMethod<String, Object?>(
        method,
        arguments,
      );
      return response ?? <String, Object?>{};
    } on MissingPluginException {
      return <String, Object?>{
        'nativeAvailable': false,
        'degradedReason': '네이티브 백그라운드 연결을 사용할 수 없어요.',
      };
    }
  }

  BackgroundMonitoringStatus _statusFromMap(Map<String, Object?> map) {
    final degradedReason = map['degradedReason'] as String?;
    final running = map['isRunning'] == true;
    final scheduled = map['isScheduled'] == true;
    final nativeAvailable = map['nativeAvailable'] == true;
    final mode = degradedReason != null
        ? BackgroundMonitoringMode.degraded
        : running
        ? BackgroundMonitoringMode.running
        : scheduled
        ? BackgroundMonitoringMode.scheduled
        : BackgroundMonitoringMode.foregroundOnly;

    return BackgroundMonitoringStatus(
      mode: mode,
      isScheduled: scheduled,
      isNativeAvailable: nativeAvailable,
      exactAlarmAvailable: map['exactAlarmAvailable'] == true,
      locationAlwaysGranted: map['locationAlwaysGranted'] == true,
      lastSession: _sessionFromMap(map),
      degradedReason: degradedReason,
    );
  }

  ActivitySession _sessionFromMap(Map<String, Object?> map) {
    final statusName = map['sessionStatus'] as String?;
    final status = ActivitySessionStatus.values
        .where((value) => value.name == statusName)
        .firstOrNull;

    if (status == null || status == ActivitySessionStatus.idle) {
      return const ActivitySession.idle();
    }

    return ActivitySession(
      status: status,
      startedAt: _dateFromMillis(map['startedAtMillis']),
      endedAt: _dateFromMillis(map['endedAtMillis']),
      steps: _intFrom(map['steps']),
      distanceMeters: _doubleFrom(map['distanceMeters']),
      evaluation: null,
    );
  }

  DateTime? _dateFromMillis(Object? value) {
    final millis = _nullableIntFrom(value);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  int _intFrom(Object? value) => _nullableIntFrom(value) ?? 0;

  int? _nullableIntFrom(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  double _doubleFrom(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }
}
