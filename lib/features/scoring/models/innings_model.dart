import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/cricket_calculator.dart';

class InningsModel {
  final String id;
  final String matchId;
  final int inningsNumber; // 1 | 2
  final String battingTeamId;
  final String bowlingTeamId;
  final int runs;
  final int wickets;
  final int balls; // Total legal deliveries bowled
  final int wides;
  final int noBalls;
  final int byes;
  final int legByes;
  final int penaltyRuns;
  final bool allOut;
  final bool completed;
  final bool isFreeHit;
  final List<String> recentBalls;
  final String? createdAt;
  final String? updatedAt;

  const InningsModel({
    required this.id,
    required this.matchId,
    required this.inningsNumber,
    required this.battingTeamId,
    required this.bowlingTeamId,
    this.runs = 0,
    this.wickets = 0,
    this.balls = 0,
    this.wides = 0,
    this.noBalls = 0,
    this.byes = 0,
    this.legByes = 0,
    this.penaltyRuns = 0,
    this.allOut = false,
    this.completed = false,
    this.isFreeHit = false,
    this.recentBalls = const [],
    this.createdAt,
    this.updatedAt,
  });

  String get oversString => CricketCalculator.ballsToOvers(balls);
  double get crr => CricketCalculator.calculateCRR(runs, balls);
  int get totalExtras => wides + noBalls + byes + legByes + penaltyRuns;

  factory InningsModel.fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) {
      return InningsModel(
        id: id,
        matchId: '',
        inningsNumber: 1,
        battingTeamId: '',
        bowlingTeamId: '',
      );
    }
    return InningsModel(
      id: id,
      matchId: data['matchId'] as String? ?? '',
      inningsNumber: (data['inningsNumber'] as num?)?.toInt() ?? 1,
      battingTeamId: data['battingTeamId'] as String? ?? '',
      bowlingTeamId: data['bowlingTeamId'] as String? ?? '',
      runs: (data['runs'] as num?)?.toInt() ?? 0,
      wickets: (data['wickets'] as num?)?.toInt() ?? 0,
      balls: (data['balls'] as num?)?.toInt() ?? 0,
      wides: (data['wides'] as num?)?.toInt() ?? 0,
      noBalls: (data['noBalls'] as num?)?.toInt() ?? 0,
      byes: (data['byes'] as num?)?.toInt() ?? 0,
      legByes: (data['legByes'] as num?)?.toInt() ?? 0,
      penaltyRuns: (data['penaltyRuns'] as num?)?.toInt() ?? 0,
      allOut: data['allOut'] as bool? ?? false,
      completed: data['completed'] as bool? ?? false,
      isFreeHit: data['isFreeHit'] as bool? ?? false,
      recentBalls: (data['recentBalls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: data['createdAt'] as String?,
      updatedAt: data['updatedAt'] as String?,
    );
  }

  factory InningsModel.fromFirestore(DocumentSnapshot doc) =>
      InningsModel.fromMap(doc.id, doc.data() as Map<String, dynamic>?);

  factory InningsModel.fromJson(Map<String, dynamic> json) =>
      InningsModel.fromMap(json['id'] as String? ?? '', json);

  Map<String, dynamic> toMap() {
    return {
      'matchId': matchId,
      'inningsNumber': inningsNumber,
      'battingTeamId': battingTeamId,
      'bowlingTeamId': bowlingTeamId,
      'runs': runs,
      'wickets': wickets,
      'balls': balls,
      'wides': wides,
      'noBalls': noBalls,
      'byes': byes,
      'legByes': legByes,
      'penaltyRuns': penaltyRuns,
      'allOut': allOut,
      'completed': completed,
      'isFreeHit': isFreeHit,
      'recentBalls': recentBalls,
      if (createdAt != null) 'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  InningsModel copyWith({
    String? id,
    String? matchId,
    int? inningsNumber,
    String? battingTeamId,
    String? bowlingTeamId,
    int? runs,
    int? wickets,
    int? balls,
    int? wides,
    int? noBalls,
    int? byes,
    int? legByes,
    int? penaltyRuns,
    bool? allOut,
    bool? completed,
    bool? isFreeHit,
    List<String>? recentBalls,
    String? createdAt,
    String? updatedAt,
  }) {
    return InningsModel(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      inningsNumber: inningsNumber ?? this.inningsNumber,
      battingTeamId: battingTeamId ?? this.battingTeamId,
      bowlingTeamId: bowlingTeamId ?? this.bowlingTeamId,
      runs: runs ?? this.runs,
      wickets: wickets ?? this.wickets,
      balls: balls ?? this.balls,
      wides: wides ?? this.wides,
      noBalls: noBalls ?? this.noBalls,
      byes: byes ?? this.byes,
      legByes: legByes ?? this.legByes,
      penaltyRuns: penaltyRuns ?? this.penaltyRuns,
      allOut: allOut ?? this.allOut,
      completed: completed ?? this.completed,
      isFreeHit: isFreeHit ?? this.isFreeHit,
      recentBalls: recentBalls ?? this.recentBalls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
