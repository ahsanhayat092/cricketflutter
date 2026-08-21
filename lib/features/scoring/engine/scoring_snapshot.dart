import '../models/match_model.dart';
import '../models/innings_model.dart';
import '../models/batting_score.dart';
import '../models/bowling_score.dart';
import '../models/ball_event.dart';

/// Full state snapshot captured before every ball delivery to enable instant 1-tap Undo
class ScoringSnapshot {
  final MatchModel match;
  final InningsModel innings;
  final Map<String, BattingScore> battingScores;
  final Map<String, BowlingScore> bowlingScores;
  final String? currentStrikerId;
  final String? currentNonStrikerId;
  final String? currentBowlerId;
  final String? previousBowlerId;
  final BallDeliveryInput deliveryInput;
  final String displayBall;

  const ScoringSnapshot({
    required this.match,
    required this.innings,
    required this.battingScores,
    required this.bowlingScores,
    required this.currentStrikerId,
    required this.currentNonStrikerId,
    required this.currentBowlerId,
    required this.previousBowlerId,
    required this.deliveryInput,
    required this.displayBall,
  });
}
