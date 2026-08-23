import 'package:cloud_firestore/cloud_firestore.dart';

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

typedef RecentEvent = RecentEventModel;

class MatchModel {
  final String id;
  final String tournamentId;
  final int matchNumber;
  final String stage; // "LEAGUE" | "FINAL"
  final String day; // "FRIDAY" | "SATURDAY" | "SUNDAY" etc.
  final String teamAId;
  final String teamBId;
  final String date;
  final String time;
  final String venue;
  final int oversPerSide; // 4 overs for LEAGUE, 5 overs for FINAL
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
    this.oversPerSide = 4, // Default 4 overs for League, 5 overs for Final
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
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  String? get winnerTeamId => winningTeamId;
  bool get isLive => status.toUpperCase() == 'LIVE';
  bool get isUpcoming => status.toUpperCase() == 'UPCOMING';
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isFinal => stage.toUpperCase() == 'FINAL' || matchNumber == 10;
  
  /// League matches are 4 overs (24 legal balls). Final match is 5 overs (30 legal balls).
  int get maxOvers => isFinal ? 5 : (oversPerSide > 0 ? oversPerSide : 4);
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

    return MatchModel(
      id: id,
      tournamentId: data['tournamentId'] as String? ?? 'main',
      matchNumber: (data['matchNumber'] as num?)?.toInt() ?? 1,
      stage: stage,
      day: (data['day'] as String?)?.toUpperCase() ?? 'FRIDAY',
      teamAId: data['teamAId'] as String? ?? '',
      teamBId: data['teamBId'] as String? ?? '',
      date: data['date'] as String? ?? '',
      time: data['time'] as String? ?? '14:00',
      venue: data['venue'] as String? ?? 'WASA Sports Complex',
      oversPerSide: (data['oversPerSide'] as num?)?.toInt() ??
          (data['maxOvers'] as num?)?.toInt() ??
          defaultOvers,
      status: (data['status'] as String?)?.toUpperCase() ?? 'UPCOMING',
      tossWinnerId: data['tossWinnerId'] as String?,
      tossDecision: data['tossDecision'] as String?,
      winningTeamId: data['winningTeamId'] as String?,
      resultText: data['resultText'] as String?,
      playerOfMatchId: data['playerOfMatchId'] as String?,
      teamAPlayingVI: (data['teamAPlayingVI'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      teamAReserveId: data['teamAReserveId'] as String?,
      teamBPlayingVI: (data['teamBPlayingVI'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      teamBReserveId: data['teamBReserveId'] as String?,
      recentEvent: data['recentEvent'] != null ? RecentEventModel.fromMap(data['recentEvent'] as Map<String, dynamic>?) : null,
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
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
