import '../entities/activity_evaluation.dart';
import '../entities/activity_monitor_settings.dart';

class BuildAlertMessage {
  const BuildAlertMessage();

  String call({
    required ActivityMonitorSettings settings,
    required ActivityEvaluation evaluation,
  }) {
    final distanceKm = (evaluation.distanceMeters / 1000).toStringAsFixed(2);
    final thresholdKm = settings.threshold.minimumDistanceKilometers
        .toStringAsFixed(1);
    final elevationGainMeters = evaluation.elevationGainMeters.toStringAsFixed(
      0,
    );
    final minimumElevationGainMeters = settings
        .threshold
        .minimumElevationGainMeters
        .toStringAsFixed(0);
    final contactName = settings.emergencyContact.name.trim();

    var message = settings.resolvedAlertMessageTemplate;
    final replacements = <String, String>{
      'appName': ActivityMonitorSettings.appName,
      'steps': evaluation.steps.toString(),
      'minimumSteps': settings.threshold.minimumSteps.toString(),
      'distanceKm': distanceKm,
      'minimumDistanceKm': thresholdKm,
      'elevationGainMeters': elevationGainMeters,
      'minimumElevationGainMeters': minimumElevationGainMeters,
      'goalPolicy': settings.goalPolicy.description,
      'contactName': contactName.isEmpty ? '보호자' : contactName,
    };

    for (final entry in replacements.entries) {
      message = message.replaceAll('{${entry.key}}', entry.value);
    }
    return message;
  }
}
