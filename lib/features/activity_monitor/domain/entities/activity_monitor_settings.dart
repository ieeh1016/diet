import 'activity_threshold.dart';
import 'emergency_contact.dart';

class ActivityMonitorSettings {
  const ActivityMonitorSettings({
    required this.threshold,
    required this.emergencyContact,
  });

  static const defaults = ActivityMonitorSettings(
    threshold: ActivityThreshold.defaults,
    emergencyContact: EmergencyContact.empty,
  );

  final ActivityThreshold threshold;
  final EmergencyContact emergencyContact;

  ActivityMonitorSettings copyWith({
    ActivityThreshold? threshold,
    EmergencyContact? emergencyContact,
  }) {
    return ActivityMonitorSettings(
      threshold: threshold ?? this.threshold,
      emergencyContact: emergencyContact ?? this.emergencyContact,
    );
  }
}
