import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'match_rules_model.dart';

class RecentEventModel {
  final String type; // "FOUR" | "SIX" | "WICKET" | "MAIDEN"
  final String text;
  final int timestamp;
  final String? batterName;
  final String? bowlerName;
  final String? dismissal;

  const RecentEventModel({
    required this.type,
    required this.text,
    required this.timestamp,
    this.batterName,
    this.bowlerName,
    this.dismissal,
  });

  factory RecentEventModel.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return RecentEventModel(
        type: '',
        text: '',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }
    return RecentEventModel(
      type: data['type'] as String? ?? '',
      text: data['text'] as String? ?? '',
      timestamp: (data['timestamp'] as num?)?.toInt() ?? 0,
      batterName: data['batterName'] as String?,
      bowlerName: data['bowlerName'] as String?,
      dismissal: data['dismissal'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'type': type,
      'text': text,
      'timestamp': timestamp,
    };
    if (batterName != null && batterName!.isNotEmpty) {
      map['batterName'] = batterName;
    }
    if (bowlerName != null && bowlerName!.isNotEmpty) {
      map['bowlerName'] = bowlerName;
    }
    if (dismissal != null && dismissal!.isNotEmpty) {
      map['dismissal'] = dismissal;
    }
    return map;
  }
}

enum MatchStage {
  league,
  playoff,
  finalMatch,
}

extension MatchStageX on MatchStage {
  String toFirestoreString() {
    switch (this) {
      case MatchStage.league:
        return 'LEAGUE';
      case MatchStage.playoff:
        return 'PLAYOFF';
      case MatchStage.finalMatch:
        return 'FINAL';
    }
  }

  static MatchStage fromFirestoreString(String? val) {
    final v = val?.toUpperCase();
    if (v == 'FINAL') return MatchStage.finalMatch;
    if (v == 'PLAYOFF') return MatchStage.playoff;
    return MatchStage.league;
  }

  String get displayName {
    switch (this) {
      case MatchStage.finalMatch:
        return '🏆 Grand Final';
      case MatchStage.playoff:
        return '⚔️ Playoff (Rank 2 vs 3)';
      case MatchStage.league:
        return 'League Match';
    }
  }
}

typedef RecentEvent = RecentEventModel;

class MatchModel {
  final String id;
  final String tournamentId;
  final int matchNumber;
  final String stage; // "LEAGUE" | "PLAYOFF" | "FINAL"
  final String day; // "FRIDAY" | "SATURDAY" | "SUNDAY" etc.
  final String teamAId;
  final String teamBId;
  final String date;
  final String time;
  final String venue;
  final int oversPerSide; // 4 overs for LEAGUE/PLAYOFF, 5 overs for FINAL
  final String status; // "UPCOMING" | "LIVE" | "COMPLETED" | "ABANDONED" | "NO_RESULT"
  final String? tossWinnerId;
  final String? tossDecision; // "BAT" | "BOWL"
  final String? winningTeamId;
  final String? resultText;
  final String? playerOfMatchId;
  final List<String> teamAPlayingVI;
  final String? teamAReserveId;
  final List<String> teamBPlayingVI;
  final String? teamBReserveId;
  final RecentEventModel? recentEvent;
  final MatchRulesModel rules;
  final String? completedAt;
  final String? createdAt;
  final String? updatedAt;

  const MatchModel({
    required this.id,
    this.tournamentId = 'main',
    required this.matchNumber,
    this.stage = 'LEAGUE',
    this.day = 'FRIDAY',
    required this.teamAId,
    required this.teamBId,
    required this.date,
    this.time = '14:00',
    this.venue = 'WASA Sports Complex',
    this.oversPerSide = 4, // Default 4 overs for League/Playoff, 5 overs for Final
    this.status = 'UPCOMING',
    this.tossWinnerId,
    this.tossDecision,
    this.winningTeamId,
    this.resultText,
    this.playerOfMatchId,
    this.teamAPlayingVI = const [],
    this.teamAReserveId,
    this.teamBPlayingVI = const [],
    this.teamBReserveId,
    this.recentEvent,
    this.rules = const MatchRulesModel(),
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  String? get winnerTeamId => winningTeamId;
  bool get isLive => status.toUpperCase() == 'LIVE';
  bool get isUpcoming => status.toUpperCase() == 'UPCOMING';
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  MatchStage get matchStage => MatchStageX.fromFirestoreString(stage);
  bool get isPlayoff => matchStage == MatchStage.playoff;
  bool get isFinal => matchStage == MatchStage.finalMatch;
  String get stageDisplayName => matchStage.displayName;
  String get formatType => rules.formatType;
  
  /// Match overs strictly follows configured match rules, oversPerSide, or format defaults.
  /// Grand Final matches NEVER cap at 5 overs unless explicitly configured as a 5-over tournament.
  int get maxOvers {
    final candidate = rules.oversPerSide > 0 ? rules.oversPerSide : (oversPerSide > 0 ? oversPerSide : 0);
    // Guard against stale 5-over final cap in T20/T10 or matches with >= 10 players:
    if (candidate <= 5) {
      if (formatType == 'T20' || rules.formatType == 'T20') return 20;
      if (formatType.contains('T10') || rules.formatType.contains('T10')) return 10;
      if (formatType == 'ODI' || rules.formatType == 'ODI') return 50;
      if (playersPerTeam >= 10) return 20;
    }
    if (candidate > 0) return candidate;
    return rules.formatType == 'T20' ? 20 : (rules.formatType.contains('T10') ? 10 : 4);
  }
  int get maxBalls => maxOvers * 6;

  /// Dynamic Squad Size:
  /// Prioritizes actual lineup size (teamAPlayingVI / teamBPlayingVI), then rules, then format defaults.
  int get playersPerTeam {
    final lineupCount = math.max(teamAPlayingVI.length, teamBPlayingVI.length);
    if (lineupCount > 0) return lineupCount;
    if (rules.hasExplicitPlayersPerTeam && rules.playersPerTeam > 0) return rules.playersPerTeam;
    if (oversPerSide >= 10 || rules.oversPerSide >= 10) return 11;
    return rules.playersPerTeam > 0 ? rules.playersPerTeam : 11;
  }

  /// Dynamic Last Man Standing Flag:
  /// For 10+ player matches (T20, T10, ODI, standard cricket), LMS is disabled (false)
  /// unless explicitly enabled with maxWickets >= playersPerTeam.
  bool get allowLastManStanding {
    if (playersPerTeam >= 10) {
      return rules.allowLastManStanding && rules.maxWickets >= playersPerTeam;
    }
    return rules.allowLastManStanding;
  }

  /// Dynamic Max Wickets Calculation:
  /// - If allowLastManStanding is true: maxWickets = playersPerTeam (e.g. 6 for 6-a-side LMS, 11 for 11-a-side LMS).
  /// - If allowLastManStanding is false: maxWickets = playersPerTeam - 1 (e.g. 10 for 11-a-side, 5 for 6-a-side standard).
  int get maxWickets {
    final n = playersPerTeam;
    final lms = allowLastManStanding;
    if (rules.maxWickets > 0) {
      // Guard against stale legacy 5 or 6 maxWickets in 10/11-player matches
      if (n >= 10 && rules.maxWickets <= 6) {
        return lms ? n : (n > 1 ? n - 1 : 1);
      }
      return rules.maxWickets;
    }
    return lms ? n : (n > 1 ? n - 1 : 1);
  }

  factory MatchModel.fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) {
      return MatchModel(
        id: id,
        matchNumber: 1,
        teamAId: '',
        teamBId: '',
        date: '',
      );
    }
    final rawRules = data['rules'] as Map<String, dynamic>?;
    final formatType = (data['formatType'] as String?) ??
        (data['format_type'] as String?) ??
        (rawRules != null ? (rawRules['formatType'] as String?) : null) ??
        'TAPE_BALL_INDOOR';
    final stage = (data['stage'] as String?)?.toUpperCase() ?? 'LEAGUE';

    final explicitOvers = (data['oversPerSide'] as num?)?.toInt() ??
        (data['overs_per_side'] as num?)?.toInt() ??
        (data['maxOvers'] as num?)?.toInt() ??
        (rawRules != null ? (rawRules['oversPerSide'] as num?)?.toInt() : null) ??
        (rawRules != null ? (rawRules['overs_per_side'] as num?)?.toInt() : null) ??
        (rawRules != null ? (rawRules['maxOvers'] as num?)?.toInt() : null);

    // Guard against stale legacy 5 overs in final matches for T10/T20
    int resolvedOvers;
    if (explicitOvers != null && explicitOvers > 0) {
      if (explicitOvers == 5 && (formatType == 'T20' || formatType == 'T10' || formatType == 'ODI')) {
        resolvedOvers = formatType == 'T20' ? 20 : (formatType == 'T10' ? 10 : 50);
      } else {
        resolvedOvers = explicitOvers;
      }
    } else {
      resolvedOvers = formatType == 'T20'
          ? 20
          : (formatType.contains('T10') ? 10 : (formatType == 'ODI' ? 50 : 4));
    }

    final teamAPlayers = (data['teamAPlayingVI'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        (data['team_a_playing_vi'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        (data['teamAPlayingXI'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        (data['team_a_playing_xi'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        (data['teamAPlayingSquad'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        (data['team_a_playing_squad'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        [];
    final teamBPlayers = (data['teamBPlayingVI'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        (data['team_b_playing_vi'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        (data['teamBPlayingXI'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        (data['team_b_playing_xi'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        (data['teamBPlayingSquad'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        (data['team_b_playing_squad'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        [];

    final actualSquadSize = math.max(teamAPlayers.length, teamBPlayers.length);

    final mergedRulesData = {
      ...data,
      if (rawRules != null) ...rawRules,
      'formatType': formatType,
      'oversPerSide': resolvedOvers,
      if (actualSquadSize > 0) 'playersPerTeam': actualSquadSize,
      if (actualSquadSize >= 10 || resolvedOvers >= 10 || formatType == 'T20' || formatType == 'T10' || formatType == 'ODI')
        'allowLastManStanding': false,
    };

    final parsedRules = MatchRulesModel.fromMap(mergedRulesData);

    return MatchModel(
      id: id,
      tournamentId: (data['tournamentId'] as String?) ??
          (data['tournament_id'] as String?) ??
          'main',
      matchNumber: (data['matchNumber'] as num?)?.toInt() ??
          (data['match_number'] as num?)?.toInt() ??
          1,
      stage: stage,
      day: (data['day'] as String?)?.toUpperCase() ?? 'FRIDAY',
      teamAId: (data['teamAId'] as String?) ??
          (data['team_a_id'] as String?) ??
          (data['teamA_id'] as String?) ??
          (data['teamA'] is String ? data['teamA'] as String : null) ??
          '',
      teamBId: (data['teamBId'] as String?) ??
          (data['team_b_id'] as String?) ??
          (data['teamB_id'] as String?) ??
          (data['teamB'] is String ? data['teamB'] as String : null) ??
          '',
      date: (data['date'] as String?) ?? '',
      time: (data['time'] as String?) ?? '14:00',
      venue: (data['venue'] as String?) ?? 'Cricket Ground',
      oversPerSide: (data['oversPerSide'] as num?)?.toInt() ??
          (data['overs_per_side'] as num?)?.toInt() ??
          (data['maxOvers'] as num?)?.toInt() ??
          parsedRules.oversPerSide,
      status: (data['status'] as String?)?.toUpperCase() ?? 'UPCOMING',
      tossWinnerId: (data['tossWinnerId'] as String?) ?? (data['toss_winner_id'] as String?),
      tossDecision: (data['tossDecision'] as String?) ?? (data['toss_decision'] as String?),
      winningTeamId: (data['winningTeamId'] as String?) ?? (data['winning_team_id'] as String?),
      resultText: (data['resultText'] as String?) ?? (data['result_text'] as String?),
      playerOfMatchId: (data['playerOfMatchId'] as String?) ?? (data['player_of_match_id'] as String?),
      teamAPlayingVI: teamAPlayers,
      teamAReserveId: (data['teamAReserveId'] as String?) ??
          (data['team_a_reserve_id'] as String?) ??
          (data['teamAReserve'] as String?),
      teamBPlayingVI: teamBPlayers,
      teamBReserveId: (data['teamBReserveId'] as String?) ??
          (data['team_b_reserve_id'] as String?) ??
          (data['teamBReserve'] as String?),
      recentEvent: data['recentEvent'] != null ? RecentEventModel.fromMap(data['recentEvent'] as Map<String, dynamic>?) : null,
      rules: parsedRules,
      completedAt: data['completedAt'] as String?,
      createdAt: data['createdAt'] as String?,
      updatedAt: data['updatedAt'] as String?,
    );
  }

  factory MatchModel.fromFirestore(DocumentSnapshot doc) =>
      MatchModel.fromMap(doc.id, doc.data() as Map<String, dynamic>?);

  factory MatchModel.fromJson(Map<String, dynamic> json) =>
      MatchModel.fromMap(json['id'] as String? ?? '', json);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tournamentId': tournamentId,
      'matchNumber': matchNumber,
      'stage': stage,
      'day': day,
      'teamAId': teamAId,
      'teamBId': teamBId,
      'date': date,
      'time': time,
      'venue': venue,
      'oversPerSide': maxOvers,
      'status': status,
      'tossWinnerId': tossWinnerId,
      'tossDecision': tossDecision,
      'winningTeamId': winningTeamId,
      'resultText': resultText,
      'playerOfMatchId': playerOfMatchId,
      'teamAPlayingVI': teamAPlayingVI,
      'teamAReserveId': teamAReserveId,
      'teamBPlayingVI': teamBPlayingVI,
      'teamBReserveId': teamBReserveId,
      if (recentEvent != null) 'recentEvent': recentEvent!.toMap(),
      'rules': rules.toMap(),
      'completedAt': completedAt,
      if (createdAt != null) 'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  MatchModel copyWith({
    String? id,
    String? tournamentId,
    int? matchNumber,
    String? stage,
    String? day,
    String? teamAId,
    String? teamBId,
    String? date,
    String? time,
    String? venue,
    int? oversPerSide,
    String? status,
    String? tossWinnerId,
    String? tossDecision,
    String? winningTeamId,
    String? resultText,
    String? playerOfMatchId,
    List<String>? teamAPlayingVI,
    String? teamAReserveId,
    List<String>? teamBPlayingVI,
    String? teamBReserveId,
    RecentEventModel? recentEvent,
    MatchRulesModel? rules,
    String? completedAt,
    String? createdAt,
    String? updatedAt,
  }) {
    return MatchModel(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      matchNumber: matchNumber ?? this.matchNumber,
      stage: stage ?? this.stage,
      day: day ?? this.day,
      teamAId: teamAId ?? this.teamAId,
      teamBId: teamBId ?? this.teamBId,
      date: date ?? this.date,
      time: time ?? this.time,
      venue: venue ?? this.venue,
      oversPerSide: oversPerSide ?? this.oversPerSide,
      status: status ?? this.status,
      tossWinnerId: tossWinnerId ?? this.tossWinnerId,
      tossDecision: tossDecision ?? this.tossDecision,
      winningTeamId: winningTeamId ?? this.winningTeamId,
      resultText: resultText ?? this.resultText,
      playerOfMatchId: playerOfMatchId ?? this.playerOfMatchId,
      teamAPlayingVI: teamAPlayingVI ?? this.teamAPlayingVI,
      teamAReserveId: teamAReserveId ?? this.teamAReserveId,
      teamBPlayingVI: teamBPlayingVI ?? this.teamBPlayingVI,
      teamBReserveId: teamBReserveId ?? this.teamBReserveId,
      recentEvent: recentEvent ?? this.recentEvent,
      rules: rules ?? this.rules,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
