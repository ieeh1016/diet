import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diet/features/activity_monitor/data/repositories/local_onboarding_repository.dart';

void main() {
  test('onboarding defaults to not completed', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalOnboardingRepository();

    expect(await repository.isCompleted(), isFalse);
  });

  test('onboarding completion can be saved and reset', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalOnboardingRepository();

    await repository.markCompleted();
    expect(await repository.isCompleted(), isTrue);

    await repository.reset();
    expect(await repository.isCompleted(), isFalse);
  });
}
