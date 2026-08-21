import 'dart:math';

class CricketCalculator {
  /// Converts legal ball count (e.g. 15) to cricket overs string (e.g. "2.3")
  static String ballsToOvers(int legalBalls) {
    if (legalBalls <= 0) return '0.0';
    final completedOvers = legalBalls ~/ 6;
    final ballsInOver = legalBalls % 6;
    return '$completedOvers.$ballsInOver';
  }

  /// Converts legal ball count to fractional decimal overs for run-rate calculation (e.g. 15 balls = 2.5 overs)
  static double ballsToDecimalOvers(int legalBalls) {
    if (legalBalls <= 0) return 0.0;
    return legalBalls / 6.0;
  }

  /// Converts cricket overs string (e.g. "2.3") or double to ball count (e.g. 15)
  static int oversStringToBalls(String oversStr) {
    final parts = oversStr.split('.');
    if (parts.isEmpty) return 0;
    final completedOvers = int.tryParse(parts[0]) ?? 0;
    final ballsInOver = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return (completedOvers * 6) + ballsInOver;
  }

  /// Calculates Current Run Rate (CRR) = (Runs / Balls) * 6
  static double calculateCRR(int runs, int balls) {
    if (balls <= 0) return 0.0;
    final crr = (runs / balls) * 6.0;
    return double.parse(crr.toStringAsFixed(2));
  }

  /// Calculates Required Run Rate (RRR) = (RunsNeeded / BallsRemaining) * 6
  static double? calculateRRR(int runsNeeded, int ballsRemaining) {
    if (ballsRemaining <= 0) {
      return runsNeeded <= 0 ? 0.0 : null; // Infinite / Over ended
    }
    if (runsNeeded <= 0) return 0.0;
    final rrr = (runsNeeded / ballsRemaining) * 6.0;
    return double.parse(rrr.toStringAsFixed(2));
  }

  /// Calculates Batsman Strike Rate = (Runs / Balls) * 100
  static double calculateStrikeRate(int runs, int balls) {
    if (balls <= 0) return 0.0;
    final sr = (runs / balls) * 100.0;
    return double.parse(sr.toStringAsFixed(1));
  }

  /// Calculates Bowler Economy Rate = (RunsConceded / BallsBowled) * 6
  static double calculateEconomy(int runsConceded, int ballsBowled) {
    if (ballsBowled <= 0) return 0.0;
    final econ = (runsConceded / ballsBowled) * 6.0;
    return double.parse(econ.toStringAsFixed(2));
  }

  /// Calculates Net Run Rate (NRR)
  /// NRR = (Total Runs Scored / Total Overs Faced) - (Total Runs Conceded / Total Overs Bowled)
  static double calculateNRR({
    required int runsFor,
    required int ballsFor,
    required int runsAgainst,
    required int ballsAgainst,
  }) {
    final oversFor = ballsToDecimalOvers(ballsFor);
    final oversAgainst = ballsToDecimalOvers(ballsAgainst);

    final forRate = oversFor > 0 ? (runsFor / oversFor) : 0.0;
    final againstRate = oversAgainst > 0 ? (runsAgainst / oversAgainst) : 0.0;

    final nrr = forRate - againstRate;
    return double.parse(nrr.toStringAsFixed(3));
  }

  /// Target Equation Text (e.g. "Need 18 runs from 11 balls")
  static String targetEquation({
    required int target,
    required int currentRuns,
    required int maxBalls,
    required int ballsBowled,
  }) {
    final needed = max(0, target - currentRuns);
    final remainingBalls = max(0, maxBalls - ballsBowled);

    if (currentRuns >= target) {
      return 'Target Achieved!';
    }
    if (remainingBalls <= 0) {
      return 'Innings Finished ($needed runs short)';
    }

    final ballWord = remainingBalls == 1 ? 'ball' : 'balls';
    final runWord = needed == 1 ? 'run' : 'runs';
    return 'Need $needed $runWord from $remainingBalls $ballWord';
  }
}
