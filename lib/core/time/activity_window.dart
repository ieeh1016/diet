enum ActivityWindowPhase { beforeWindow, active, afterWindow, weekend }

class ActivityWindow {
  const ActivityWindow({this.startHour = 11, this.endHour = 13});

  final int startHour;
  final int endHour;

  bool isWeekday(DateTime dateTime) =>
      dateTime.weekday >= DateTime.monday &&
      dateTime.weekday <= DateTime.friday;

  DateTime startFor(DateTime dateTime) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day, startHour);

  DateTime endFor(DateTime dateTime) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day, endHour);

  bool isWithin(DateTime dateTime) {
    if (!isWeekday(dateTime)) {
      return false;
    }

    final start = startFor(dateTime);
    final end = endFor(dateTime);
    return !dateTime.isBefore(start) && dateTime.isBefore(end);
  }

  bool isEvaluationTime(DateTime dateTime) {
    if (!isWeekday(dateTime)) {
      return false;
    }

    return !dateTime.isBefore(endFor(dateTime));
  }

  ActivityWindowPhase phaseFor(DateTime dateTime) {
    if (!isWeekday(dateTime)) {
      return ActivityWindowPhase.weekend;
    }
    if (dateTime.isBefore(startFor(dateTime))) {
      return ActivityWindowPhase.beforeWindow;
    }
    if (dateTime.isBefore(endFor(dateTime))) {
      return ActivityWindowPhase.active;
    }
    return ActivityWindowPhase.afterWindow;
  }
}
