class AppConstants {
  static const String appPlatformName = 'PitchPe';
  static const String defaultTournamentId = 'main';
  static const String defaultTournamentName = 'Cricket Tournament';
  static const String defaultTournamentShortName = 'CRIC';
  static const String defaultVenue = 'Cricket Ground';

  // Legacy compatibility fallbacks
  static const String tournamentId = 'main';
  static const String tournamentName = defaultTournamentName;
  static const String tournamentShortName = defaultTournamentShortName;

  // Squad Rules
  static const int playingSquadSize = 11;
  static const int tapeBallSquadSize = 6;
  static const int reserveSquadSize = 1;

  // Overs Rules
  static const int ballsPerOver = 6;
  static const int defaultOvers = 20;

  // Dynamic Bowling Quota Helper
  // E.g. <=5 overs -> 1, 10 overs -> 2, 20 overs -> 4, 50 overs -> 10
  static int getMaxOverPerBowler({required int oversPerSide, int? explicitMax}) {
    if (explicitMax != null && explicitMax > 0) return explicitMax;
    if (oversPerSide <= 5) return 1;
    if (oversPerSide <= 10) return 3; // Default to 3 overs for 10-over matches
    return (oversPerSide / 5).ceil();
  }

  // Points Table
  static const int winPoints = 2;
  static const int tiePoints = 1;
  static const int noResultPoints = 1;
  static const int lossPoints = 0;
}
