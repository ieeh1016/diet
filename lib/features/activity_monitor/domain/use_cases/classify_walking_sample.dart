enum WalkingSampleDecision { accepted, tooLittleMovement, tooFastForWalking }

class ClassifyWalkingSample {
  const ClassifyWalkingSample({
    this.minimumDistanceMetersPerWindow = 10,
    this.minimumWalkingSpeedMetersPerSecond = 0.3,
    this.maximumWalkingSpeedMetersPerSecond = 3.0,
  });

  final double minimumDistanceMetersPerWindow;
  final double minimumWalkingSpeedMetersPerSecond;
  final double maximumWalkingSpeedMetersPerSecond;

  WalkingSampleDecision call({
    required double distanceMeters,
    required Duration elapsed,
  }) {
    final seconds = elapsed.inMilliseconds / Duration.millisecondsPerSecond;
    if (seconds <= 0) {
      return WalkingSampleDecision.tooLittleMovement;
    }

    final minimumDistance = _minimumDistance(seconds);
    final maximumDistance = maximumWalkingSpeedMetersPerSecond * seconds;
    if (distanceMeters <= minimumDistance) {
      return WalkingSampleDecision.tooLittleMovement;
    }
    if (distanceMeters >= maximumDistance) {
      return WalkingSampleDecision.tooFastForWalking;
    }
    return WalkingSampleDecision.accepted;
  }

  double _minimumDistance(double seconds) {
    final speedBasedMinimum = minimumWalkingSpeedMetersPerSecond * seconds;
    if (speedBasedMinimum > minimumDistanceMetersPerWindow) {
      return speedBasedMinimum;
    }
    return minimumDistanceMetersPerWindow;
  }
}
