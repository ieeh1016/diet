import '../../../../core/time/activity_window.dart';
import '../entities/monitoring_window.dart';

class NextMonitoringWindow {
  const NextMonitoringWindow({this.activityWindow = const ActivityWindow()});

  final ActivityWindow activityWindow;

  MonitoringWindow call(DateTime from) {
    var candidate = DateTime(from.year, from.month, from.day);

    if (!from.isBefore(activityWindow.endFor(from))) {
      candidate = candidate.add(const Duration(days: 1));
    }

    while (!activityWindow.isWeekday(candidate)) {
      candidate = candidate.add(const Duration(days: 1));
    }

    return MonitoringWindow(
      start: activityWindow.startFor(candidate),
      end: activityWindow.endFor(candidate),
    );
  }
}
