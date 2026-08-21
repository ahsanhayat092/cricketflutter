class FirestorePaths {
  static const String tournaments = 'tournaments';
  static const String tournamentMainId = 'main';
  static const String tournamentMain = 'tournaments/$tournamentMainId';

  static const String teams = 'teams';
  static const String players = 'players';
  static const String matches = 'matches';
  static const String innings = 'innings';
  static const String battingScores = 'battingScores';
  static const String bowlingScores = 'bowlingScores';
  static const String standings = 'standings';
  static const String users = 'users';

  static String tournament(String id) => '$tournaments/$id';
  static String team(String id) => '$teams/$id';
  static String player(String id) => '$players/$id';
  static String match(String id) => '$matches/$id';
  static String inning(String id) => '$innings/$id';
  static String battingScore(String id) => '$battingScores/$id';
  static String bowlingScore(String id) => '$bowlingScores/$id';
  static String standing(String teamId) => '$standings/$teamId';
  static String user(String uid) => '$users/$uid';
}
