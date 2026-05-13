enum ActivityGoalMetric {
  steps,
  distance,
  elevation;

  String get label {
    return switch (this) {
      ActivityGoalMetric.steps => '걸음수',
      ActivityGoalMetric.distance => '이동거리',
      ActivityGoalMetric.elevation => '획득고도',
    };
  }
}

enum ActivityGoalMatchMode {
  all,
  any;

  String get label {
    return switch (this) {
      ActivityGoalMatchMode.all => '모두 달성',
      ActivityGoalMatchMode.any => '하나 이상 달성',
    };
  }
}

class ActivityGoalPolicy {
  const ActivityGoalPolicy({
    required this.metrics,
    this.matchMode = ActivityGoalMatchMode.all,
  });

  static const defaults = ActivityGoalPolicy(
    metrics: {ActivityGoalMetric.steps, ActivityGoalMetric.distance},
  );

  final Set<ActivityGoalMetric> metrics;
  final ActivityGoalMatchMode matchMode;

  Set<ActivityGoalMetric> get normalizedMetrics {
    return metrics.isEmpty ? defaults.metrics : Set.unmodifiable(metrics);
  }

  Iterable<ActivityGoalMetric> get orderedMetrics {
    return ActivityGoalMetric.values.where(normalizedMetrics.contains);
  }

  bool includes(ActivityGoalMetric metric) =>
      normalizedMetrics.contains(metric);

  String get description {
    final labels = orderedMetrics.map((metric) => metric.label).join(', ');
    return matchMode == ActivityGoalMatchMode.all
        ? '$labels 모두 기준값 초과이면 성공'
        : '$labels 중 하나 이상 기준값 초과이면 성공';
  }

  ActivityGoalPolicy copyWith({
    Set<ActivityGoalMetric>? metrics,
    ActivityGoalMatchMode? matchMode,
  }) {
    return ActivityGoalPolicy(
      metrics: metrics ?? this.metrics,
      matchMode: matchMode ?? this.matchMode,
    );
  }
}
