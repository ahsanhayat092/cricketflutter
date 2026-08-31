import '../../../core/utils/cricket_calculator.dart';

class BowlingScore {
  final String id;
  final String inningsId;
  final String playerId;
  final String? matchId;
  final String? tournamentId;
  final int balls;
  final int maidens;
  final int runs;
  final int wickets;
  final int wides;
  final int noBalls;

  const BowlingScore({
    required this.id,
    required this.inningsId,
    required this.playerId,
    this.matchId,
    this.tournamentId,
    this.balls = 0,
    this.maidens = 0,
    this.runs = 0,
    this.wickets = 0,
    this.wides = 0,
    this.noBalls = 0,
  });

  /// Factory for an empty initial bowling score
  factory BowlingScore.empty(String playerId, {String inningsId = '', String? matchId, String? tournamentId}) {
    return BowlingScore(
      id: inningsId.isNotEmpty ? '${inningsId}_$playerId' : playerId,
      inningsId: inningsId,
      playerId: playerId,
      matchId: matchId,
      tournamentId: tournamentId,
    );
  }

  String get oversString => CricketCalculator.ballsToOvers(balls);
  double get economy => CricketCalculator.calculateEconomy(runs, balls);
  double get economyRate => economy;

  factory BowlingScore.fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) {
      return BowlingScore(
        id: id,
        inningsId: '',
        playerId: '',
      );
    }
    return BowlingScore(
      id: id,
      inningsId: (data['inningsId'] as String?) ?? (data['innings_id'] as String?) ?? '',
      playerId: (data['playerId'] as String?) ?? (data['player_id'] as String?) ?? '',
      matchId: (data['matchId'] as String?) ?? (data['match_id'] as String?),
      tournamentId: (data['tournamentId'] as String?) ?? (data['tournament_id'] as String?),
      balls: (data['balls'] as num?)?.toInt() ?? 0,
      maidens: (data['maidens'] as num?)?.toInt() ?? 0,
      runs: (data['runs'] as num?)?.toInt() ?? 0,
      wickets: (data['wickets'] as num?)?.toInt() ?? 0,
      wides: (data['wides'] as num?)?.toInt() ?? 0,
      noBalls: (data['noBalls'] as num?)?.toInt() ?? 0,
    );
  }

  factory BowlingScore.fromJson(Map<String, dynamic> json) =>
      BowlingScore.fromMap(json['id'] as String? ?? '', json);

  Map<String, dynamic> toMap() {
    return {
      'inningsId': inningsId,
      'playerId': playerId,
      if (matchId != null && matchId!.isNotEmpty) 'matchId': matchId,
      if (tournamentId != null && tournamentId!.isNotEmpty) 'tournamentId': tournamentId,
      'balls': balls,
      'maidens': maidens,
      'runs': runs,
      'wickets': wickets,
      'wides': wides,
      'noBalls': noBalls,
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  BowlingScore copyWith({
    String? id,
    String? inningsId,
    String? playerId,
    String? matchId,
    String? tournamentId,
    int? balls,
    int? maidens,
    int? runs,
    int? wickets,
    int? wides,
    int? noBalls,
  }) {
    return BowlingScore(
      id: id ?? this.id,
      inningsId: inningsId ?? this.inningsId,
      playerId: playerId ?? this.playerId,
      matchId: matchId ?? this.matchId,
      tournamentId: tournamentId ?? this.tournamentId,
      balls: balls ?? this.balls,
      maidens: maidens ?? this.maidens,
      runs: runs ?? this.runs,
      wickets: wickets ?? this.wickets,
      wides: wides ?? this.wides,
      noBalls: noBalls ?? this.noBalls,
    );
  }
}
