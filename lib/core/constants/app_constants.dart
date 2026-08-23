class AppConstants {
  static const String tournamentId = 'wasa-premier-league';
  static const String tournamentName = 'WASA Premier League';
  static const String tournamentShortName = 'WPL';

  // Squad Rules
  static const int playingSquadSize = 6;
  static const int reserveSquadSize = 1;

  // Wickets Rule
  static const int maxWicketsPerInnings = 6; // 6 dismissals = ALL OUT with Last Man Standing in 6-a-side

  // Overs Rules
  static const int ballsPerOver = 6;
  static const int leagueOvers = 4;
  static const int leagueLegalBalls = leagueOvers * ballsPerOver; // 24 balls

  static const int finalOvers = 5;
  static const int finalLegalBalls = finalOvers * ballsPerOver; // 30 balls

  // Bowling Quota Rules
  // League: Each bowler can bowl max 1 over (6 legal balls)
  static const int leagueMaxOversPerBowler = 1;
  static const int leagueMaxBallsPerBowler = 6;

  // Final: Exactly ONE bowler can bowl up to 2 overs (12 legal balls); others max 1 over (6 balls)
  static const int finalMaxOversForSingleBowler = 2;
  static const int finalMaxBallsForSingleBowler = 12;
  static const int finalMaxOversForOtherBowlers = 1;
  static const int finalMaxBallsForOtherBowlers = 6;

  // Points
  static const int winPoints = 2;
  static const int tiePoints = 1;
  static const int lossPoints = 0;
}
