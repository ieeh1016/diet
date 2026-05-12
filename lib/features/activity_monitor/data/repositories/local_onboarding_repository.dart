import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/onboarding_repository.dart';

class LocalOnboardingRepository implements OnboardingRepository {
  static const completedKey = 'onboarding.completed';

  @override
  Future<bool> isCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(completedKey) ?? false;
  }

  @override
  Future<void> markCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(completedKey, true);
  }

  @override
  Future<void> reset() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(completedKey, false);
  }
}
