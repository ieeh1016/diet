import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'activity_monitor_state.dart';
import 'activity_monitor_view_model.dart';

final activityMonitorViewModelProvider =
    NotifierProvider<ActivityMonitorViewModel, ActivityMonitorState>(
      ActivityMonitorViewModel.new,
    );
