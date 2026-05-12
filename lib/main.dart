import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/toss_theme.dart';
import 'features/activity_monitor/domain/entities/activity_monitor_settings.dart';
import 'features/activity_monitor/presentation/activity_monitor_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: ActivityMonitorSettings.appName,
      debugShowCheckedModeBanner: false,
      theme: TossTheme.light(),
      home: const ActivityMonitorScreen(),
    );
  }
}
