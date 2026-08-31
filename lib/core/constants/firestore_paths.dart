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
  static const String tournamentMembers = 'tournamentMembers';
  static const String tournamentTeamMemberships = 'tournamentTeamMemberships';

  static String sanitizeId(String? id, [String fallback = 'unknown']) {
    final clean = (id ?? '').trim();
    return clean.isNotEmpty ? clean : fallback;
  }

  static String tournament(String id) => '$tournaments/${sanitizeId(id, tournamentMainId)}';
  static String team(String id) => '$teams/${sanitizeId(id)}';
  static String player(String id) => '$players/${sanitizeId(id)}';
  static String match(String id) => '$matches/${sanitizeId(id)}';
  static String inning(String id) => '$innings/${sanitizeId(id)}';
  static String battingScore(String id) => '$battingScores/${sanitizeId(id)}';
  static String bowlingScore(String id) => '$bowlingScores/${sanitizeId(id)}';
  static String standing(String teamId) => '$standings/${sanitizeId(teamId)}';
  static String user(String uid) => '$users/${sanitizeId(uid)}';
  static String tournamentMember(String id) => '$tournamentMembers/${sanitizeId(id)}';
}
