import 'activity_evaluation.dart';

enum ActivitySessionStatus { idle, active, evaluated }

class ActivitySession {
  const ActivitySession({
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.steps,
    required this.distanceMeters,
    required this.evaluation,
    this.elevationGainMeters = 0,
    this.baselineAltitudeMeters,
    this.acceptedGpsSegmentCount = 0,
    this.rejectedStationarySegmentCount = 0,
    this.rejectedFastSegmentCount = 0,
    this.rejectedPoorAccuracySampleCount = 0,
    this.ignoredStepCount = 0,
  });

  const ActivitySession.idle()
    : status = ActivitySessionStatus.idle,
      startedAt = null,
      endedAt = null,
      steps = 0,
      distanceMeters = 0,
      elevationGainMeters = 0,
      baselineAltitudeMeters = null,
      acceptedGpsSegmentCount = 0,
      rejectedStationarySegmentCount = 0,
      rejectedFastSegmentCount = 0,
      rejectedPoorAccuracySampleCount = 0,
      ignoredStepCount = 0,
      evaluation = null;

  ActivitySession.active(this.startedAt)
    : status = ActivitySessionStatus.active,
      endedAt = null,
      steps = 0,
      distanceMeters = 0,
      elevationGainMeters = 0,
      baselineAltitudeMeters = null,
      acceptedGpsSegmentCount = 0,
      rejectedStationarySegmentCount = 0,
      rejectedFastSegmentCount = 0,
      rejectedPoorAccuracySampleCount = 0,
      ignoredStepCount = 0,
      evaluation = null;

  final ActivitySessionStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int steps;
  final double distanceMeters;
  final double elevationGainMeters;
  final double? baselineAltitudeMeters;
  final int acceptedGpsSegmentCount;
  final int rejectedStationarySegmentCount;
  final int rejectedFastSegmentCount;
  final int rejectedPoorAccuracySampleCount;
  final int ignoredStepCount;
  final ActivityEvaluation? evaluation;

  bool get isActive => status == ActivitySessionStatus.active;

  int get rejectedGpsSegmentCount =>
      rejectedStationarySegmentCount +
      rejectedFastSegmentCount +
      rejectedPoorAccuracySampleCount;

  ActivitySession copyWith({
    ActivitySessionStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    int? steps,
    double? distanceMeters,
    double? elevationGainMeters,
    double? baselineAltitudeMeters,
    int? acceptedGpsSegmentCount,
    int? rejectedStationarySegmentCount,
    int? rejectedFastSegmentCount,
    int? rejectedPoorAccuracySampleCount,
    int? ignoredStepCount,
    ActivityEvaluation? evaluation,
  }) {
    return ActivitySession(
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      steps: steps ?? this.steps,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      elevationGainMeters: elevationGainMeters ?? this.elevationGainMeters,
      baselineAltitudeMeters:
          baselineAltitudeMeters ?? this.baselineAltitudeMeters,
      acceptedGpsSegmentCount:
          acceptedGpsSegmentCount ?? this.acceptedGpsSegmentCount,
      rejectedStationarySegmentCount:
          rejectedStationarySegmentCount ?? this.rejectedStationarySegmentCount,
      rejectedFastSegmentCount:
          rejectedFastSegmentCount ?? this.rejectedFastSegmentCount,
      rejectedPoorAccuracySampleCount:
          rejectedPoorAccuracySampleCount ??
          this.rejectedPoorAccuracySampleCount,
      ignoredStepCount: ignoredStepCount ?? this.ignoredStepCount,
      evaluation: evaluation ?? this.evaluation,
    );
  }
}
