import '../../../core/constants/app_constants.dart';
import '../models/match_model.dart';
import '../models/innings_model.dart';
import '../models/batting_score.dart';
import '../models/bowling_score.dart';
import '../models/ball_event.dart';

enum MatchStage {
  league,
  finalStage,
}

MatchStage matchStageFromString(String? stage) {
  if (stage?.toUpperCase() == 'FINAL') return MatchStage.finalStage;
  return MatchStage.league;
}

bool isFinalMatch(MatchStage stage) => stage == MatchStage.finalStage;

class ScoringResult {
  final MatchModel match;
  final InningsModel innings;
  final Map<String, BattingScore> battingScores;
  final Map<String, BowlingScore> bowlingScores;
  final String? strikerId;
  final String? nonStrikerId;
  final String? currentBowlerId;
  final String? previousBowlerId;
  final bool isOverCompleted;
  final bool isInningsCompleted;
  final bool isMatchCompleted;
  final String? celebrationType; // "FOUR", "SIX", "WICKET", "MAIDEN"
  final String? celebrationText;

  const ScoringResult({
    required this.match,
    required this.innings,
    required this.battingScores,
    required this.bowlingScores,
    required this.strikerId,
    required this.nonStrikerId,
    required this.currentBowlerId,
    required this.previousBowlerId,
    this.isOverCompleted = false,
    this.isInningsCompleted = false,
    this.isMatchCompleted = false,
    this.celebrationType,
    this.celebrationText,
  });
}

class CricketScoringEngine {
  /// Returns the maximum allowed legal balls for a specific bowler
  static int getBowlerMaxBalls({
    required String bowlerId,
    required MatchStage stage,
    required List<BowlingScore> bowlingScores,
  }) {
    final isFinal = isFinalMatch(stage);
    if (!isFinal) return 6; // League: strictly 6 legal balls (1 over)

    final bowlersWith2Overs = bowlingScores.where((b) => b.balls >= 12).toList();
    final alreadyHas2OverBowler = bowlersWith2Overs.isNotEmpty;
    final thisBowler = bowlingScores.firstWhere(
      (b) => b.playerId == bowlerId,
      orElse: () => BowlingScore.empty(bowlerId),
    );

    // If this bowler already bowled 6 balls and no other bowler has taken the 2-over quota
    if (thisBowler.balls >= 6) {
      if (!alreadyHas2OverBowler || bowlersWith2Overs.any((b) => b.playerId == bowlerId)) {
        return 12; // Allowed 2nd over
      }
      return 6; // Another bowler already bowled 2 overs
    }

    // Bowler has bowled < 6 balls
    if (alreadyHas2OverBowler && !bowlersWith2Overs.any((b) => b.playerId == bowlerId)) {
      return 6; // Someone else already has the 2-over slot
    }

    return 12; // Potentially eligible for 2 overs in Final
  }

  /// Checks if a bowler has completed their maximum allowed balls
  static bool isBowlerQuotaExhausted({
    required String bowlerId,
    required MatchStage stage,
    required List<BowlingScore> bowlingScores,
  }) {
    final current = bowlingScores.firstWhere(
      (b) => b.playerId == bowlerId,
      orElse: () => BowlingScore.empty(bowlerId),
    );
    return current.balls >= getBowlerMaxBalls(
      bowlerId: bowlerId,
      stage: stage,
      bowlingScores: bowlingScores,
    );
  }

  /// Checks if a bowler is eligible to bowl the next over
  static bool isBowlerEligibleForNextOver({
    required String bowlerId,
    required String? lastOverBowlerId,
    required MatchStage stage,
    required List<BowlingScore> bowlingScores,
  }) {
    // 1. Cannot bowl consecutive overs
    if (lastOverBowlerId != null && bowlerId == lastOverBowlerId) {
      return false;
    }
    // 2. Cannot exceed quota
    if (isBowlerQuotaExhausted(
      bowlerId: bowlerId,
      stage: stage,
      bowlingScores: bowlingScores,
    )) {
      return false;
    }
    return true;
  }

  /// Checks if a bowler is allowed to bowl the next over (Compatibility Wrapper)
  static bool canBowlerBowlNextOver({
    required String bowlerId,
    required String? previousBowlerId,
    required bool isFinalMatch,
    required Map<String, BowlingScore> bowlingScores,
  }) {
    return isBowlerEligibleForNextOver(
      bowlerId: bowlerId,
      lastOverBowlerId: previousBowlerId,
      stage: isFinalMatch ? MatchStage.finalStage : MatchStage.league,
      bowlingScores: bowlingScores.values.toList(),
    );
  }

  /// Reason why a bowler is not eligible to bowl
  static String? getBowlerIneligibilityReason({
    required String bowlerId,
    required String? previousBowlerId,
    required bool isFinalMatch,
    required Map<String, BowlingScore> bowlingScores,
  }) {
    if (previousBowlerId != null && bowlerId == previousBowlerId) {
      return 'Bowled Previous Over (Consecutive Lock)';
    }
    final stage = isFinalMatch ? MatchStage.finalStage : MatchStage.league;
    if (isBowlerQuotaExhausted(
      bowlerId: bowlerId,
      stage: stage,
      bowlingScores: bowlingScores.values.toList(),
    )) {
      final current = bowlingScores[bowlerId]?.oversString ?? '0.0';
      final maxOvers = getBowlerMaxBalls(
        bowlerId: bowlerId,
        stage: stage,
        bowlingScores: bowlingScores.values.toList(),
      ) ~/ 6;
      return 'Quota Completed ($current / $maxOvers.0 ov)';
    }
    return null;
  }

  /// Gets list of eligible bowlers from bowling squad for the next over
  static List<String> getEligibleBowlers({
    required List<String> bowlingPlayingVI,
    required String? previousBowlerId,
    required bool isFinalMatch,
    required Map<String, BowlingScore> bowlingScores,
  }) {
    return bowlingPlayingVI.where((bowlerId) {
      return canBowlerBowlNextOver(
        bowlerId: bowlerId,
        previousBowlerId: previousBowlerId,
        isFinalMatch: isFinalMatch,
        bowlingScores: bowlingScores,
      );
    }).toList();
  }

  /// Core Pure Function to process a single ball delivery
  static ScoringResult processDelivery({
    required MatchModel match,
    required InningsModel innings,
    required int? firstInningsTotalRuns, // Required for 2nd innings target chase calculation
    required Map<String, BattingScore> battingScores,
    required Map<String, BowlingScore> bowlingScores,
    required String strikerId,
    required String nonStrikerId,
    required String bowlerId,
    required String? previousBowlerId,
    required BallDeliveryInput input,
    Map<String, String>? teamNames,
    Map<String, String>? playerNames,
  }) {
    var updatedBattingScores = Map<String, BattingScore>.from(battingScores);
    var updatedBowlingScores = Map<String, BowlingScore>.from(bowlingScores);

    var currentRuns = innings.runs;
    var currentWickets = innings.wickets;
    var currentBalls = innings.balls;
    var currentWides = innings.wides;
    var currentNoBalls = innings.noBalls;
    var currentByes = innings.byes;
    var currentLegByes = innings.legByes;
    var currentPenalty = innings.penaltyRuns;

    var newStrikerId = strikerId;
    var newNonStrikerId = nonStrikerId;
    var nextBowlerId = bowlerId;
    var nextPreviousBowlerId = previousBowlerId;

    String? celebrationType;
    String? celebrationText;

    final bowlerBallsSoFar = bowlingScores[bowlerId]?.balls ?? 0;
    final stageEnum = match.isFinal ? MatchStage.finalStage : MatchStage.league;
    final maxBallsAllowed = getBowlerMaxBalls(
      bowlerId: bowlerId,
      stage: stageEnum,
      bowlingScores: bowlingScores.values.toList(),
    );
    final isNewOverStart = innings.balls > 0 && (innings.balls % AppConstants.ballsPerOver == 0);
    final isConsecutiveViolation = isNewOverStart && previousBowlerId != null && bowlerId == previousBowlerId;

    if (bowlerBallsSoFar >= maxBallsAllowed || isConsecutiveViolation) {
      return ScoringResult(
        match: match,
        innings: innings,
        battingScores: battingScores,
        bowlingScores: bowlingScores,
        strikerId: strikerId,
        nonStrikerId: nonStrikerId,
        currentBowlerId: null,
        previousBowlerId: previousBowlerId,
        isOverCompleted: true,
      );
    }

    // 1. Process Extras & Delivery Legality
    int deliveryTotalRuns = 0;
    int runsChargedToBowler = 0;
    int runsAddedToBatsman = 0;
    bool isLegal = input.isLegalBall;

    if (input.isWide) {
      currentWides += 1;
      final extraRuns = input.extraRuns > 0 ? input.extraRuns : 1;
      deliveryTotalRuns += extraRuns;
      runsChargedToBowler += extraRuns;
    } else if (input.isNoBall) {
      currentNoBalls += 1;
      final extraRuns = input.extraRuns > 0 ? input.extraRuns : 1;
      deliveryTotalRuns += extraRuns;
      runsChargedToBowler += extraRuns;
      if (input.runsOffBat > 0) {
        deliveryTotalRuns += input.runsOffBat;
        runsChargedToBowler += input.runsOffBat;
        runsAddedToBatsman += input.runsOffBat;
      }
    } else if (input.isBye) {
      currentByes += input.extraRuns;
      deliveryTotalRuns += input.extraRuns;
      // Byes not charged to bowler runs
    } else if (input.isLegBye) {
      currentLegByes += input.extraRuns;
      deliveryTotalRuns += input.extraRuns;
      // Leg byes not charged to bowler runs
    } else if (input.isPenalty) {
      currentPenalty += input.extraRuns;
      deliveryTotalRuns += input.extraRuns;
    } else {
      // Normal legal delivery off bat
      runsAddedToBatsman = input.runsOffBat;
      deliveryTotalRuns = input.runsOffBat;
      runsChargedToBowler = input.runsOffBat;
    }

    if (isLegal) {
      currentBalls += 1;
    }

    currentRuns += deliveryTotalRuns;

    // 2. Update Batsman Stats
    var strikerStat = updatedBattingScores[strikerId] ??
        BattingScore(
          id: '${innings.id}_$strikerId',
          inningsId: innings.id,
          playerId: strikerId,
          battingOrder: updatedBattingScores.length + 1,
        );

    // Only non-wides increment batsman balls faced
    final newBatsmanBalls = input.isWide ? strikerStat.balls : strikerStat.balls + 1;
    final newBatsmanRuns = strikerStat.runs + runsAddedToBatsman;
    final newFours = input.runsOffBat == 4 ? strikerStat.fours + 1 : strikerStat.fours;
    final newSixes = input.runsOffBat == 6 ? strikerStat.sixes + 1 : strikerStat.sixes;

    strikerStat = strikerStat.copyWith(
      balls: newBatsmanBalls,
      runs: newBatsmanRuns,
      fours: newFours,
      sixes: newSixes,
    );
    updatedBattingScores[strikerId] = strikerStat;

    // Check Celebrations
    if (input.runsOffBat == 6) {
      celebrationType = 'SIX';
      final sName = playerNames?[strikerId] ?? 'Batter';
      celebrationText = '$sName launches a colossal SIX! 🚀';
    } else if (input.runsOffBat == 4) {
      celebrationType = 'FOUR';
      final sName = playerNames?[strikerId] ?? 'Batter';
      celebrationText = '$sName smashes a boundary FOUR! 🏏';
    }

    // 3. Process Wicket
    if (input.isWicket) {
      currentWickets += 1;
      celebrationType = 'WICKET';
      final outPlayerId = input.outBatsmanId ?? strikerId;
      final outBatsmanName = playerNames?[outPlayerId] ?? 'Batter';
      final dismissalText = input.dismissalDescription ?? 'Out';
      celebrationText = '$outBatsmanName is OUT ($dismissalText)! 🔴';
      final outPlayerStat = updatedBattingScores[outPlayerId] ??
          BattingScore(
            id: '${innings.id}_$outPlayerId',
            inningsId: innings.id,
            playerId: outPlayerId,
          );

      updatedBattingScores[outPlayerId] = outPlayerStat.copyWith(
        isOut: true,
        dismissal: input.dismissalDescription ?? 'Out',
      );

      // Replace out batsman with incoming batsman if not all out
      if (currentWickets < AppConstants.maxWicketsPerInnings && input.newBatsmanId != null) {
        final newBatterId = input.newBatsmanId!;
        updatedBattingScores[newBatterId] = BattingScore(
          id: '${innings.id}_$newBatterId',
          inningsId: innings.id,
          playerId: newBatterId,
          battingOrder: updatedBattingScores.length + 1,
        );

        if (outPlayerId == strikerId) {
          newStrikerId = newBatterId;
        } else {
          newNonStrikerId = newBatterId;
        }
      }
    }

    // 4. Update Bowler Stats
    var bowlerStat = updatedBowlingScores[bowlerId] ??
        BowlingScore(
          id: '${innings.id}_$bowlerId',
          inningsId: innings.id,
          playerId: bowlerId,
        );

    final newBowlerBalls = isLegal ? bowlerStat.balls + 1 : bowlerStat.balls;
    final newBowlerRuns = bowlerStat.runs + runsChargedToBowler;
    final newBowlerWickets = (input.isWicket &&
            input.wicketType != WicketType.runOutStriker &&
            input.wicketType != WicketType.runOutNonStriker &&
            input.wicketType != WicketType.retiredHurt)
        ? bowlerStat.wickets + 1
        : bowlerStat.wickets;
    final newBowlerWides = input.isWide ? bowlerStat.wides + 1 : bowlerStat.wides;
    final newBowlerNoBalls = input.isNoBall ? bowlerStat.noBalls + 1 : bowlerStat.noBalls;

    bowlerStat = bowlerStat.copyWith(
      balls: newBowlerBalls,
      runs: newBowlerRuns,
      wickets: newBowlerWickets,
      wides: newBowlerWides,
      noBalls: newBowlerNoBalls,
    );
    updatedBowlingScores[bowlerId] = bowlerStat;

    int strikeRotatingRuns = runsAddedToBatsman;
    if (input.isBye || input.isLegBye) {
      strikeRotatingRuns = input.extraRuns;
    }

    if (strikeRotatingRuns % 2 == 1 && !input.isWicket) {
      final temp = newStrikerId;
      newStrikerId = newNonStrikerId;
      newNonStrikerId = temp;
    }

    bool isOverCompleted = false;
    if (isLegal && currentBalls % AppConstants.ballsPerOver == 0) {
      isOverCompleted = true;
      nextPreviousBowlerId = bowlerId;

      final overSymbols = [...innings.recentBalls, input.displaySymbol];
      final currentOverDeliveries = overSymbols.length >= 6
          ? overSymbols.sublist(overSymbols.length - 6)
          : overSymbols;

      final isMaiden = currentOverDeliveries.every((s) =>
          s == '•' || s == '0' || s == 'W' || s.startsWith('B+') || s.startsWith('Lb+'));

      if (isMaiden) {
        bowlerStat = bowlerStat.copyWith(maidens: bowlerStat.maidens + 1);
        updatedBowlingScores[bowlerId] = bowlerStat;
        celebrationType ??= 'MAIDEN';
        celebrationText ??= 'MAIDEN OVER! 0 Runs Conceded!';
      }

      final temp = newStrikerId;
      newStrikerId = newNonStrikerId;
      newNonStrikerId = temp;
    }

    bool allOut = currentWickets >= AppConstants.maxWicketsPerInnings;
    bool oversFinished = currentBalls >= match.maxBalls;

    bool isInningsCompleted = false;
    bool isMatchCompleted = false;
    String? matchResultText;
    String? winnerTeamId;

    if (innings.inningsNumber == 2 && firstInningsTotalRuns != null) {
      final target = firstInningsTotalRuns + 1;
      if (currentRuns >= target) {
        isInningsCompleted = true;
        isMatchCompleted = true;
        winnerTeamId = innings.battingTeamId;
        final wicketsLeft = AppConstants.maxWicketsPerInnings - currentWickets;
        final winnerName = teamNames?[winnerTeamId] ??
            (winnerTeamId == match.teamAId
                ? 'Team A'
                : (winnerTeamId == match.teamBId ? 'Team B' : 'Team'));
        matchResultText =
            '$winnerName won by $wicketsLeft ${wicketsLeft == 1 ? 'wicket' : 'wickets'}';
      } else if (allOut || oversFinished) {
        isInningsCompleted = true;
        isMatchCompleted = true;
        if (currentRuns == firstInningsTotalRuns) {
          matchResultText = 'Match Tied';
        } else {
          winnerTeamId = innings.bowlingTeamId;
          final runMargin = firstInningsTotalRuns - currentRuns;
          final winnerName = teamNames?[winnerTeamId] ??
              (winnerTeamId == match.teamAId
                  ? 'Team A'
                  : (winnerTeamId == match.teamBId ? 'Team B' : 'Team'));
          matchResultText =
              '$winnerName won by $runMargin ${runMargin == 1 ? 'run' : 'runs'}';
        }
      }
    } else {
      if (allOut || oversFinished) {
        isInningsCompleted = true;
      }
    }

    final recentBallsList = List<String>.from(innings.recentBalls);
    recentBallsList.add(input.displaySymbol);
    if (recentBallsList.length > 12) {
      recentBallsList.removeAt(0);
    }

    // Calculate Free Hit state for next delivery:
    // - No-Ball: triggers a Free Hit on the next ball
    // - Wide: preserves active Free Hit (illegal ball does not consume Free Hit)
    // - Legal delivery: consumes Free Hit
    bool nextFreeHit = false;
    if (input.isNoBall) {
      nextFreeHit = true;
      if (celebrationType == null) {
        celebrationType = 'FREE_HIT';
        celebrationText = 'NO BALL! 🎯 FREE HIT NEXT!';
      }
    } else if (input.isWide) {
      nextFreeHit = innings.isFreeHit;
    } else {
      nextFreeHit = false;
    }

    // Update Innings Model
    final updatedInnings = innings.copyWith(
      runs: currentRuns,
      wickets: currentWickets,
      balls: currentBalls,
      wides: currentWides,
      noBalls: currentNoBalls,
      byes: currentByes,
      legByes: currentLegByes,
      penaltyRuns: currentPenalty,
      completed: isInningsCompleted,
      allOut: allOut,
      isFreeHit: nextFreeHit,
      recentBalls: recentBallsList,
    );

    // Update Match Model
    RecentEvent? newRecentEvent;
    if (celebrationType != null) {
      final sName = playerNames?[strikerId] ?? 'Batter';
      final bName = playerNames?[bowlerId] ?? 'Bowler';
      final outPlayerId = input.outBatsmanId ?? strikerId;
      final outBatsmanName = playerNames?[outPlayerId] ?? 'Batter';

      String? eventBatterName;
      String? eventBowlerName = bName;
      String? eventDismissal;

      if (celebrationType == 'WICKET') {
        eventBatterName = outBatsmanName;
        eventDismissal = input.dismissalDescription ?? 'Out';
      } else if (celebrationType == 'FOUR' || celebrationType == 'SIX') {
        eventBatterName = sName;
      }

      newRecentEvent = RecentEvent(
        type: celebrationType,
        text: celebrationText ?? celebrationType,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        batterName: eventBatterName,
        bowlerName: eventBowlerName,
        dismissal: eventDismissal,
      );
    }

    final updatedMatch = match.copyWith(
      status: isMatchCompleted ? 'COMPLETED' : 'LIVE',
      resultText: matchResultText ?? match.resultText,
      winningTeamId: winnerTeamId ?? match.winningTeamId,
      recentEvent: newRecentEvent ?? match.recentEvent,
    );

    return ScoringResult(
      match: updatedMatch,
      innings: updatedInnings,
      battingScores: updatedBattingScores,
      bowlingScores: updatedBowlingScores,
      strikerId: newStrikerId,
      nonStrikerId: newNonStrikerId,
      currentBowlerId: (isOverCompleted && !isInningsCompleted && !isMatchCompleted) ? null : nextBowlerId,
      previousBowlerId: nextPreviousBowlerId,
      isOverCompleted: isOverCompleted,
      isInningsCompleted: isInningsCompleted,
      isMatchCompleted: isMatchCompleted,
      celebrationType: celebrationType,
      celebrationText: celebrationText,
    );
  }
}
