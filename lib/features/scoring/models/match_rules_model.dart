// -------------------------------------------------------------
// Tournament / Match Rules Model for PitchPe Mobile App
// -------------------------------------------------------------
class MatchRulesModel {
  final String formatType;
  final int oversPerSide;
  final int maxOverPerBowler;
  final int playersPerTeam;
  final int maxWickets;
  final bool allowLastManStanding;
  final bool freeHitEnabled;
  final int noBallRuns;
  final int wideRuns;

  const MatchRulesModel({
    this.formatType = 'TAPE_BALL_INDOOR',
    this.oversPerSide = 4,
    this.maxOverPerBowler = 1,
    this.playersPerTeam = 6,
    this.maxWickets = 6,
    this.allowLastManStanding = true,
    this.freeHitEnabled = true,
    this.noBallRuns = 1,
    this.wideRuns = 1,
  });

  factory MatchRulesModel.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const MatchRulesModel();
    final overs = (data['oversPerSide'] as num?)?.toInt() ?? 4;
    final players = (data['playersPerTeam'] as num?)?.toInt() ?? 6;
    final lms = data['allowLastManStanding'] as bool? ?? (overs <= 8);
    return MatchRulesModel(
      formatType: data['formatType'] as String? ?? 'TAPE_BALL_INDOOR',
      oversPerSide: overs,
      maxOverPerBowler: (data['maxOverPerBowler'] as num?)?.toInt() ?? (overs <= 5 ? 1 : 2),
      playersPerTeam: players,
      maxWickets: (data['maxWickets'] as num?)?.toInt() ?? (lms ? players : players - 1),
      allowLastManStanding: lms,
      freeHitEnabled: data['freeHitEnabled'] as bool? ?? true,
      noBallRuns: (data['noBallRuns'] as num?)?.toInt() ?? 1,
      wideRuns: (data['wideRuns'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'formatType': formatType,
      'oversPerSide': oversPerSide,
      'maxOverPerBowler': maxOverPerBowler,
      'playersPerTeam': playersPerTeam,
      'maxWickets': maxWickets,
      'allowLastManStanding': allowLastManStanding,
      'freeHitEnabled': freeHitEnabled,
      'noBallRuns': noBallRuns,
      'wideRuns': wideRuns,
    };
  }

  MatchRulesModel copyWith({
    String? formatType,
    int? oversPerSide,
    int? maxOverPerBowler,
    int? playersPerTeam,
    int? maxWickets,
    bool? allowLastManStanding,
    bool? freeHitEnabled,
    int? noBallRuns,
    int? wideRuns,
  }) {
    return MatchRulesModel(
      formatType: formatType ?? this.formatType,
      oversPerSide: oversPerSide ?? this.oversPerSide,
      maxOverPerBowler: maxOverPerBowler ?? this.maxOverPerBowler,
      playersPerTeam: playersPerTeam ?? this.playersPerTeam,
      maxWickets: maxWickets ?? this.maxWickets,
      allowLastManStanding: allowLastManStanding ?? this.allowLastManStanding,
      freeHitEnabled: freeHitEnabled ?? this.freeHitEnabled,
      noBallRuns: noBallRuns ?? this.noBallRuns,
      wideRuns: wideRuns ?? this.wideRuns,
    );
  }
}
