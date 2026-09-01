// -------------------------------------------------------------
// Tournament / Match Rules Model for PitchPe Mobile App
// -------------------------------------------------------------
class MatchRulesModel {
  final String formatType;
  final int oversPerSide;
  final int maxOverPerBowler;
  final int _explicitPlayersPerTeam;
  final int _explicitMaxWickets;
  final bool allowLastManStanding;
  final bool freeHitEnabled;
  final int noBallRuns;
  final int wideRuns;

  const MatchRulesModel({
    this.formatType = 'TAPE_BALL_INDOOR',
    this.oversPerSide = 4,
    this.maxOverPerBowler = 1,
    int playersPerTeam = 0,
    int maxWickets = 0,
    this.allowLastManStanding = true,
    this.freeHitEnabled = true,
    this.noBallRuns = 1,
    this.wideRuns = 1,
  })  : _explicitPlayersPerTeam = playersPerTeam,
        _explicitMaxWickets = maxWickets;

  bool get hasExplicitPlayersPerTeam => _explicitPlayersPerTeam > 0;

  int get playersPerTeam => _explicitPlayersPerTeam > 0
      ? _explicitPlayersPerTeam
      : (formatType == 'T20' || formatType == 'T10' || formatType == 'ODI' || formatType == 'TEST' ? 11 : 6);

  int get maxWickets {
    if (_explicitMaxWickets > 0) {
      // Guard against legacy/stale 6-wicket default in 11-a-side matches
      if (playersPerTeam >= 10 && _explicitMaxWickets <= 6) {
        return allowLastManStanding ? playersPerTeam : playersPerTeam - 1;
      }
      return _explicitMaxWickets;
    }
    return allowLastManStanding
        ? playersPerTeam
        : (playersPerTeam > 1 ? playersPerTeam - 1 : 1);
  }

  factory MatchRulesModel.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const MatchRulesModel();
    final formatType = data['formatType'] as String? ?? 'TAPE_BALL_INDOOR';
    final overs = (data['oversPerSide'] as num?)?.toInt() ??
        (data['overs_per_side'] as num?)?.toInt() ??
        (data['overs'] as num?)?.toInt() ??
        (data['maxOvers'] as num?)?.toInt() ??
        (formatType == 'T20' ? 20 : (formatType == 'T10' ? 10 : 4));

    final explicitPlayers = (data['playersPerTeam'] as num?)?.toInt() ??
        (data['players_per_team'] as num?)?.toInt() ??
        (data['players'] as num?)?.toInt() ??
        (data['teamSize'] as num?)?.toInt() ??
        (data['team_size'] as num?)?.toInt() ??
        (data['squadSize'] as num?)?.toInt() ??
        (data['squad_size'] as num?)?.toInt() ??
        (data['playingSquadSize'] as num?)?.toInt() ??
        (data['playing_squad_size'] as num?)?.toInt() ??
        (data['totalPlayers'] as num?)?.toInt() ??
        0;

    final resolvedPlayers = explicitPlayers > 0
        ? explicitPlayers
        : (formatType == 'T20' || formatType == 'T10' || formatType == 'ODI' || formatType == 'TEST' ? 11 : 6);

    final lms = data['allowLastManStanding'] as bool? ??
        (data['allow_last_man_standing'] as bool?) ??
        (formatType == 'T20' || formatType == 'ODI' || formatType == 'TEST' || resolvedPlayers > 8
            ? false
            : (resolvedPlayers <= 8));

    final explicitMaxWickets = (data['maxWickets'] as num?)?.toInt() ??
        (data['max_wickets'] as num?)?.toInt() ??
        0;

    return MatchRulesModel(
      formatType: formatType,
      oversPerSide: overs,
      maxOverPerBowler: (data['maxOverPerBowler'] as num?)?.toInt() ??
          (data['max_over_per_bowler'] as num?)?.toInt() ??
          (overs <= 5 ? 1 : 2),
      playersPerTeam: explicitPlayers,
      maxWickets: explicitMaxWickets,
      allowLastManStanding: lms,
      freeHitEnabled: data['freeHitEnabled'] as bool? ?? data['free_hit_enabled'] as bool? ?? true,
      noBallRuns: (data['noBallRuns'] as num?)?.toInt() ?? (data['no_ball_runs'] as num?)?.toInt() ?? 1,
      wideRuns: (data['wideRuns'] as num?)?.toInt() ?? (data['wide_runs'] as num?)?.toInt() ?? 1,
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
      playersPerTeam: playersPerTeam ?? this._explicitPlayersPerTeam,
      maxWickets: maxWickets ?? this._explicitMaxWickets,
      allowLastManStanding: allowLastManStanding ?? this.allowLastManStanding,
      freeHitEnabled: freeHitEnabled ?? this.freeHitEnabled,
      noBallRuns: noBallRuns ?? this.noBallRuns,
      wideRuns: wideRuns ?? this.wideRuns,
    );
  }
}
