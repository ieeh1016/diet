class HealthConnectStepStatus {
  const HealthConnectStepStatus({
    required this.available,
    required this.readPermissionGranted,
    required this.lastReadSuccessful,
    this.lastCorrectedSteps,
    this.message,
  });

  const HealthConnectStepStatus.unavailable({this.message})
    : available = false,
      readPermissionGranted = false,
      lastReadSuccessful = false,
      lastCorrectedSteps = null;

  final bool available;
  final bool readPermissionGranted;
  final bool lastReadSuccessful;
  final int? lastCorrectedSteps;
  final String? message;

  String get label {
    if (!available) {
      return '미지원';
    }
    if (!readPermissionGranted) {
      return '필요';
    }
    if (lastReadSuccessful) {
      return '보정됨';
    }
    return '연결됨';
  }

  HealthConnectStepStatus copyWith({
    bool? available,
    bool? readPermissionGranted,
    bool? lastReadSuccessful,
    int? lastCorrectedSteps,
    String? message,
  }) {
    return HealthConnectStepStatus(
      available: available ?? this.available,
      readPermissionGranted:
          readPermissionGranted ?? this.readPermissionGranted,
      lastReadSuccessful: lastReadSuccessful ?? this.lastReadSuccessful,
      lastCorrectedSteps: lastCorrectedSteps ?? this.lastCorrectedSteps,
      message: message ?? this.message,
    );
  }
}
