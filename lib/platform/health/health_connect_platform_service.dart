import 'package:flutter/services.dart';

import '../../features/activity_monitor/domain/entities/health_connect_step_status.dart';

class HealthConnectPlatformService {
  static const _channel = MethodChannel('diet/health_connect');

  Future<HealthConnectStepStatus> currentStatus() async {
    final response = await _invokeMap('currentStatus');
    return _statusFromMap(response);
  }

  Future<HealthConnectStepStatus> requestReadStepsPermission() async {
    final response = await _invokeMap('requestReadStepsPermission');
    return _statusFromMap(response);
  }

  Future<bool> openSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openSettings') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<Map<String, Object?>> _invokeMap(String method) async {
    try {
      final response = await _channel.invokeMapMethod<String, Object?>(method);
      return response ?? <String, Object?>{};
    } on MissingPluginException {
      return <String, Object?>{
        'available': false,
        'readPermissionGranted': false,
        'lastReadSuccessful': false,
        'message': '이 플랫폼에서는 Health Connect를 사용할 수 없어요.',
      };
    }
  }

  HealthConnectStepStatus _statusFromMap(Map<String, Object?> map) {
    return HealthConnectStepStatus(
      available: map['available'] == true,
      readPermissionGranted: map['readPermissionGranted'] == true,
      lastReadSuccessful: map['lastReadSuccessful'] == true,
      lastCorrectedSteps: _nullableIntFrom(map['lastCorrectedSteps']),
      message: map['message'] as String?,
    );
  }

  int? _nullableIntFrom(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}
