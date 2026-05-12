abstract interface class OnboardingRepository {
  Future<bool> isCompleted();

  Future<void> markCompleted();

  Future<void> reset();
}
