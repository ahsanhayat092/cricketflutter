import '../../../core/utils/cricket_calculator.dart';

class BattingScore {
  final String id;
  final String inningsId;
  final String playerId;
  final int battingOrder;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final bool isOut;
  final String? dismissal;

  const BattingScore({
    required this.id,
    required this.inningsId,
    required this.playerId,
    this.battingOrder = 1,
    this.runs = 0,
    this.balls = 0,
    this.fours = 0,
    this.sixes = 0,
    this.isOut = false,
    this.dismissal,
  });

  double get strikeRate => CricketCalculator.calculateStrikeRate(runs, balls);

  factory BattingScore.fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) {
      return BattingScore(
        id: id,
        inningsId: '',
        playerId: '',
      );
    }
    return BattingScore(
      id: id,
      inningsId: data['inningsId'] as String? ?? '',
      playerId: data['playerId'] as String? ?? '',
      battingOrder: (data['battingOrder'] as num?)?.toInt() ?? 1,
      runs: (data['runs'] as num?)?.toInt() ?? 0,
      balls: (data['balls'] as num?)?.toInt() ?? 0,
      fours: (data['fours'] as num?)?.toInt() ?? 0,
      sixes: (data['sixes'] as num?)?.toInt() ?? 0,
      isOut: data['isOut'] as bool? ?? false,
      dismissal: data['dismissal'] as String?,
    );
  }

  factory BattingScore.fromJson(Map<String, dynamic> json) =>
      BattingScore.fromMap(json['id'] as String? ?? '', json);

  Map<String, dynamic> toMap() {
    return {
      'inningsId': inningsId,
      'playerId': playerId,
      'battingOrder': battingOrder,
      'runs': runs,
      'balls': balls,
      'fours': fours,
      'sixes': sixes,
      'isOut': isOut,
      'dismissal': dismissal,
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  BattingScore copyWith({
    String? id,
    String? inningsId,
    String? playerId,
    int? battingOrder,
    int? runs,
    int? balls,
    int? fours,
    int? sixes,
    bool? isOut,
    String? dismissal,
  }) {
    return BattingScore(
      id: id ?? this.id,
      inningsId: inningsId ?? this.inningsId,
      playerId: playerId ?? this.playerId,
      battingOrder: battingOrder ?? this.battingOrder,
      runs: runs ?? this.runs,
      balls: balls ?? this.balls,
      fours: fours ?? this.fours,
      sixes: sixes ?? this.sixes,
      isOut: isOut ?? this.isOut,
      dismissal: dismissal ?? this.dismissal,
    );
  }
}
