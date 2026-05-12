class MonitoringWindow {
  const MonitoringWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime dateTime) =>
      !dateTime.isBefore(start) && dateTime.isBefore(end);
}
