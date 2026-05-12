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
  });

  const ActivitySession.idle()
    : status = ActivitySessionStatus.idle,
      startedAt = null,
      endedAt = null,
      steps = 0,
      distanceMeters = 0,
      elevationGainMeters = 0,
      baselineAltitudeMeters = null,
      evaluation = null;

  ActivitySession.active(this.startedAt)
    : status = ActivitySessionStatus.active,
      endedAt = null,
      steps = 0,
      distanceMeters = 0,
      elevationGainMeters = 0,
      baselineAltitudeMeters = null,
      evaluation = null;

  final ActivitySessionStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int steps;
  final double distanceMeters;
  final double elevationGainMeters;
  final double? baselineAltitudeMeters;
  final ActivityEvaluation? evaluation;

  bool get isActive => status == ActivitySessionStatus.active;

  ActivitySession copyWith({
    ActivitySessionStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    int? steps,
    double? distanceMeters,
    double? elevationGainMeters,
    double? baselineAltitudeMeters,
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
      evaluation: evaluation ?? this.evaluation,
    );
  }
}
