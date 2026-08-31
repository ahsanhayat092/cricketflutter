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
  
  /// League and Playoff matches are 4 overs (24 legal balls). Final match is 5 overs (30 legal balls).
  int get maxOvers => isFinal ? 5 : (rules.oversPerSide > 0 ? rules.oversPerSide : (oversPerSide > 0 ? oversPerSide : 4));
  int get maxBalls => maxOvers * 6;

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
    final stage = (data['stage'] as String?)?.toUpperCase() ?? 'LEAGUE';
    final isFinalStage = stage == 'FINAL';
    final defaultOvers = isFinalStage ? 5 : 4;

    final rawRules = data['rules'] as Map<String, dynamic>?;
    final parsedRules = rawRules != null
        ? MatchRulesModel.fromMap(rawRules)
        : MatchRulesModel.fromMap({
            ...data,
            'oversPerSide': data['oversPerSide'] ?? data['overs_per_side'] ?? defaultOvers,
          });

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
      venue: (data['venue'] as String?) ?? 'WASA Sports Complex',
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
      teamAPlayingVI: (data['teamAPlayingVI'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (data['team_a_playing_vi'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      teamAReserveId: (data['teamAReserveId'] as String?) ?? (data['team_a_reserve_id'] as String?),
      teamBPlayingVI: (data['teamBPlayingVI'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (data['team_b_playing_vi'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      teamBReserveId: (data['teamBReserveId'] as String?) ?? (data['team_b_reserve_id'] as String?),
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
