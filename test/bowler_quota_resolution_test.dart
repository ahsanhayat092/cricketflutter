import 'package:flutter_test/flutter_test.dart';
import 'package:wpl_cricket_app/core/models/tournament_config.dart';
import 'package:wpl_cricket_app/features/scoring/engine/cricket_scoring_engine.dart';
import 'package:wpl_cricket_app/features/scoring/models/ball_event.dart';
import 'package:wpl_cricket_app/features/scoring/models/batting_score.dart';
import 'package:wpl_cricket_app/features/scoring/models/bowling_score.dart';
import 'package:wpl_cricket_app/features/scoring/models/innings_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/match_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/match_rules_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/tournament_model.dart';

void main() {
  group('Dynamic Bowler Quota Resolution Tests', () {
    test('Tournament config quota (3) overrides stale match document quota (2)', () {
      final match = MatchModel(
        id: 'match-1',
        matchNumber: 1,
        teamAId: 't1',
        teamBId: 't2',
        date: '2026-09-08',
        rules: const MatchRulesModel(oversPerSide: 10, maxOverPerBowler: 2),
      );

      final tournament = TournamentModel(
        id: 'tour-1',
        name: 'Asia Sixer T10',
        shortName: 'AST10',
        oversPerSide: 10,
        config: TournamentConfig.fromMap({
          'matchRules': {
            'oversPerSide': 10,
            'maxOversPerBowler': 3,
          },
        }),
      );

      final resolved = CricketScoringEngine.resolveMaxOversPerBowler(
        match: match,
        tournament: tournament,
      );

      expect(resolved, 3, reason: 'Tournament config 3 overs must override legacy match 2 overs');
    });

    test('Tournament root field quota (3) overrides stale match document quota (2)', () {
      final match = MatchModel(
        id: 'match-2',
        matchNumber: 2,
        teamAId: 't1',
        teamBId: 't2',
        date: '2026-09-08',
        rules: const MatchRulesModel(oversPerSide: 10, maxOverPerBowler: 2),
      );

      final tournament = const TournamentModel(
        id: 'tour-2',
        name: 'T10 Open',
        shortName: 'T10O',
        oversPerSide: 10,
        maxOverPerBowler: 3,
      );

      final resolved = CricketScoringEngine.resolveMaxOversPerBowler(
        match: match,
        tournament: tournament,
      );

      expect(resolved, 3, reason: 'Tournament root quota 3 overs must override legacy match 2 overs');
    });

    test('Custom higher match quota is preserved if greater than tournament', () {
      final match = MatchModel(
        id: 'match-3',
        matchNumber: 3,
        teamAId: 't1',
        teamBId: 't2',
        date: '2026-09-08',
        rules: const MatchRulesModel(oversPerSide: 10, maxOverPerBowler: 4),
      );

      final tournament = const TournamentModel(
        id: 'tour-3',
        name: 'T10 Open',
        shortName: 'T10O',
        oversPerSide: 10,
        maxOverPerBowler: 3,
      );

      final resolved = CricketScoringEngine.resolveMaxOversPerBowler(
        match: match,
        tournament: tournament,
      );

      expect(resolved, 4, reason: 'Match quota greater than tournament must be respected');
    });

    test('Scorer runtime custom quota overrides all tournament and match settings', () {
      final match = MatchModel(
        id: 'match-4',
        matchNumber: 4,
        teamAId: 't1',
        teamBId: 't2',
        date: '2026-09-08',
        rules: const MatchRulesModel(oversPerSide: 10, maxOverPerBowler: 2),
      );

      final tournament = const TournamentModel(
        id: 'tour-4',
        name: 'T10 Open',
        shortName: 'T10O',
        oversPerSide: 10,
        maxOverPerBowler: 3,
      );

      final resolved = CricketScoringEngine.resolveMaxOversPerBowler(
        match: match,
        tournament: tournament,
        customQuota: 4,
      );

      expect(resolved, 4, reason: 'Explicit scorer customQuota override must take highest priority');
    });

    test('10-over match defaults to 3 overs when no tournament or match quota is set', () {
      final match = MatchModel(
        id: 'match-5',
        matchNumber: 5,
        teamAId: 't1',
        teamBId: 't2',
        date: '2026-09-08',
        rules: const MatchRulesModel(oversPerSide: 10, maxOverPerBowler: 0),
      );

      final resolved = CricketScoringEngine.resolveMaxOversPerBowler(
        match: match,
      );

      expect(resolved, 3, reason: '10-over match must default to 3 overs per bowler');
    });

    test('Short matches (<= 5 overs) default to 1 over per bowler when no quota is set', () {
      final match = MatchModel(
        id: 'match-6',
        matchNumber: 6,
        teamAId: 't1',
        teamBId: 't2',
        date: '2026-09-08',
        rules: const MatchRulesModel(oversPerSide: 5, maxOverPerBowler: 0),
      );

      final resolved = CricketScoringEngine.resolveMaxOversPerBowler(
        match: match,
      );

      expect(resolved, 1, reason: '5-over match must default to 1 over per bowler');
    });
  });

  group('Bowler Eligibility & Delivery Processing with 3-Over Quota', () {
    test('Bowler who bowled 12 balls (2.0 overs) is eligible to bowl 3rd over when quota is 3', () {
      final bowlerScore = const BowlingScore(
        id: 'bs-1',
        inningsId: 'inn-1',
        playerId: 'bowler-1',
        balls: 12,
        runs: 15,
        wickets: 1,
      );

      final bowlingScores = {'bowler-1': bowlerScore};

      final canBowl = CricketScoringEngine.canBowlerBowlNextOver(
        bowlerId: 'bowler-1',
        previousBowlerId: 'bowler-2', // previous over bowled by bowler-2
        isFinalMatch: false,
        bowlingScores: bowlingScores,
        maxOverPerBowler: 3,
      );

      expect(canBowl, isTrue, reason: 'Bowler with 2 overs should be eligible when quota is 3');

      final isExhausted = CricketScoringEngine.isBowlerQuotaExhausted(
        bowlerId: 'bowler-1',
        stage: MatchStage.league,
        bowlingScores: bowlingScores.values.toList(),
        maxOverPerBowler: 3,
        matchOvers: 10,
      );

      expect(isExhausted, isFalse, reason: 'Bowler with 12 balls is not exhausted under 3-over quota');
    });

    test('Delivery processing allows 13th legal ball (3rd over) without blocking bowler', () {
      final match = MatchModel(
        id: 'match-t10',
        matchNumber: 7,
        teamAId: 't1',
        teamBId: 't2',
        date: '2026-09-08',
        stage: 'SEMI_FINAL',
        rules: const MatchRulesModel(oversPerSide: 10, maxOverPerBowler: 2), // legacy 2 in match doc
      );

      final tournament = TournamentModel(
        id: 'tour-1',
        name: 'Asia Sixer T10',
        shortName: 'AST10',
        oversPerSide: 10,
        config: TournamentConfig.fromMap({
          'matchRules': {
            'oversPerSide': 10,
            'maxOversPerBowler': 3, // organizer configured 3
          },
        }),
      );

      final innings = const InningsModel(
        id: 'inn-1',
        matchId: 'match-t10',
        inningsNumber: 1,
        battingTeamId: 't1',
        bowlingTeamId: 't2',
        runs: 50,
        wickets: 1,
        balls: 18, // 3.0 overs in innings so far
      );

      final bowlerScore = const BowlingScore(
        id: 'bs-star',
        inningsId: 'inn-1',
        playerId: 'bowler-star',
        balls: 12,
        runs: 16,
        wickets: 1,
      );

      final battingScores = {
        'bat-1': const BattingScore(id: 'bat-1', inningsId: 'inn-1', playerId: 'bat-1', runs: 25, balls: 10),
        'bat-2': const BattingScore(id: 'bat-2', inningsId: 'inn-1', playerId: 'bat-2', runs: 20, balls: 8),
      };

      final result = CricketScoringEngine.processDelivery(
        match: match,
        innings: innings,
        tournament: tournament,
        maxOverPerBowler: 3,
        firstInningsTotalRuns: null,
        strikerId: 'bat-1',
        nonStrikerId: 'bat-2',
        bowlerId: 'bowler-star',
        previousBowlerId: 'bowler-other',
        battingScores: battingScores,
        bowlingScores: {'bowler-star': bowlerScore},
        input: const BallDeliveryInput(runsOffBat: 1),
      );

      // Bowler should have 13 balls and 2.1 overs
      final updatedBowler = result.bowlingScores['bowler-star']!;
      expect(updatedBowler.balls, 13);
      expect(updatedBowler.oversString, '2.1');
      // Over is NOT complete yet (only ball 1 of this over)
      expect(result.isOverCompleted, isFalse);
      // Bowler should NOT be unassigned mid-over
      expect(result.currentBowlerId, 'bowler-star');
    });
  });
}
