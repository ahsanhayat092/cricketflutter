import 'package:flutter_test/flutter_test.dart';
import 'package:wpl_cricket_app/features/scoring/engine/cricket_scoring_engine.dart';
import 'package:wpl_cricket_app/features/scoring/models/ball_event.dart';
import 'package:wpl_cricket_app/features/scoring/models/innings_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/match_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/match_rules_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/tournament_model.dart';

void main() {
  group('Dynamic Max Wickets & Last Man Standing Unit Tests', () {
    test('6-a-side with allowLastManStanding = true requires all 6 wickets for all out', () {
      final match = MatchModel(
        id: 'm1',
        matchNumber: 1,
        teamAId: 'team_a',
        teamBId: 'team_b',
        date: '2026-09-01',
        rules: const MatchRulesModel(
          playersPerTeam: 6,
          allowLastManStanding: true,
          maxWickets: 6,
        ),
      );

      expect(match.maxWickets, equals(6));
      expect(match.allowLastManStanding, isTrue);
      expect(match.playersPerTeam, equals(6));
    });

    test('8-a-side match resolves playersPerTeam = 8 and maxWickets = 7 without LMS', () {
      final match = MatchModel(
        id: 'm_8_side',
        matchNumber: 1,
        teamAId: 'team_a',
        teamBId: 'team_b',
        date: '2026-09-01',
        rules: const MatchRulesModel(
          playersPerTeam: 8,
          allowLastManStanding: false,
        ),
      );

      expect(match.playersPerTeam, equals(8));
      expect(match.maxWickets, equals(7));
    });

    test('11-a-side match resolves playersPerTeam = 11 and maxWickets = 10 without LMS', () {
      final match = MatchModel(
        id: 'm_11_side',
        matchNumber: 1,
        teamAId: 'team_a',
        teamBId: 'team_b',
        date: '2026-09-01',
        rules: const MatchRulesModel(
          playersPerTeam: 11,
          allowLastManStanding: false,
        ),
      );

      expect(match.playersPerTeam, equals(11));
      expect(match.maxWickets, equals(10));
      expect(match.allowLastManStanding, isFalse);
    });

    test('11-a-side match with legacy maxWickets: 6 in Firestore correctly guards and uses 10 maxWickets', () {
      final matchLegacy = MatchModel.fromMap('m_legacy', {
        'playersPerTeam': 11,
        'rules': {
          'playersPerTeam': 11,
          'maxWickets': 6, // Legacy default from 6-a-side
        },
      });

      expect(matchLegacy.playersPerTeam, equals(11));
      expect(matchLegacy.maxWickets, equals(10));
      expect(matchLegacy.allowLastManStanding, isFalse);
    });

    test('T20 format defaults to 11 players per team in TournamentModel and MatchRulesModel', () {
      final tourT20 = TournamentModel.fromMap({
        'name': 'ICC T20 Cup',
        'formatType': 'T20',
      });
      expect(tourT20.playersPerTeam, equals(11));
      expect(tourT20.maxWickets, equals(10));

      final matchT20 = MatchModel.fromMap('m_t20', {
        'formatType': 'T20',
        'teamA': 'AUS',
        'teamB': 'PAK',
      });
      expect(matchT20.playersPerTeam, equals(11));
      expect(matchT20.maxWickets, equals(10));
      expect(matchT20.allowLastManStanding, isFalse);
    });

    test('6-a-side with allowLastManStanding = false requires 5 wickets for all out', () {
      final match = MatchModel(
        id: 'm2',
        matchNumber: 2,
        teamAId: 'team_a',
        teamBId: 'team_b',
        date: '2026-09-01',
        rules: const MatchRulesModel(
          playersPerTeam: 6,
          allowLastManStanding: false,
          maxWickets: 5,
        ),
      );

      expect(match.maxWickets, equals(5));
      expect(match.allowLastManStanding, isFalse);
    });

    test('TournamentModel.fromMap dynamically calculates maxWickets based on allowLastManStanding', () {
      final tourLMS = TournamentModel.fromMap({
        'name': 'LMS Tour',
        'playersPerTeam': 6,
        'allowLastManStanding': true,
      });
      expect(tourLMS.maxWickets, equals(6));

      final tourNoLMS = TournamentModel.fromMap({
        'name': 'Standard Tour',
        'playersPerTeam': 6,
        'allowLastManStanding': false,
      });
      expect(tourNoLMS.maxWickets, equals(5));

      final tour11 = TournamentModel.fromMap({
        'name': '11-a-side Tour',
        'playersPerTeam': 11,
        'allowLastManStanding': false,
      });
      expect(tour11.maxWickets, equals(10));
    });

    test('MatchRulesModel.fromMap dynamically calculates maxWickets based on allowLastManStanding', () {
      final rulesLMS = MatchRulesModel.fromMap({
        'playersPerTeam': 6,
        'allowLastManStanding': true,
      });
      expect(rulesLMS.maxWickets, equals(6));

      final rulesNoLMS = MatchRulesModel.fromMap({
        'playersPerTeam': 6,
        'allowLastManStanding': false,
      });
      expect(rulesNoLMS.maxWickets, equals(5));

      final rulesExplicit = MatchRulesModel.fromMap({
        'playersPerTeam': 8,
        'allowLastManStanding': false,
        'maxWickets': 7,
      });
      expect(rulesExplicit.maxWickets, equals(7));
    });

    test('11-a-side match does NOT end or trigger LMS on 5th wicket', () {
      final match11 = MatchModel(
        id: 'm_11',
        matchNumber: 1,
        teamAId: 'aus',
        teamBId: 'pak',
        date: '2026-09-01',
        rules: const MatchRulesModel(
          playersPerTeam: 11,
          allowLastManStanding: false,
          oversPerSide: 20,
        ),
      );

      final inningsAt4 = InningsModel(
        id: 'inn_1',
        matchId: 'm_11',
        inningsNumber: 1,
        battingTeamId: 'aus',
        bowlingTeamId: 'pak',
        wickets: 4,
        balls: 20,
        runs: 50,
      );

      // 5th wicket falls in 11-a-side match
      final result5th = CricketScoringEngine.processDelivery(
        match: match11,
        innings: inningsAt4,
        firstInningsTotalRuns: null,
        battingScores: {},
        bowlingScores: {},
        strikerId: 'p4',
        nonStrikerId: 'p5',
        bowlerId: 'b1',
        previousBowlerId: null,
        input: const BallDeliveryInput(
          runsOffBat: 0,
          isWicket: true,
          wicketType: WicketType.bowled,
          newBatsmanId: 'p6', // 6th player comes in
        ),
      );

      expect(result5th.innings.wickets, equals(5));
      expect(result5th.innings.completed, isFalse, reason: '11-a-side match must not end on 5th wicket');
      expect(result5th.innings.allOut, isFalse);
      expect(result5th.strikerId, equals('p6'));
      expect(result5th.nonStrikerId, equals('p5'), reason: 'Non-striker must remain distinct (no LMS)');
    });

    test('Scoring Engine does NOT end innings at 5 wickets when allowLastManStanding = true in 6-a-side', () {
      final match = MatchModel(
        id: 'm_test_lms',
        matchNumber: 1,
        teamAId: 'team_a',
        teamBId: 'team_b',
        date: '2026-09-01',
        rules: const MatchRulesModel(
          playersPerTeam: 6,
          allowLastManStanding: true,
          maxWickets: 6,
          oversPerSide: 4,
        ),
      );

      final inningsAt4Wickets = InningsModel(
        id: 'inn_1',
        matchId: 'm_test_lms',
        inningsNumber: 1,
        battingTeamId: 'team_a',
        bowlingTeamId: 'team_b',
        wickets: 4,
        balls: 10,
        runs: 35,
      );

      // 5th wicket falls
      final result5thWicket = CricketScoringEngine.processDelivery(
        match: match,
        innings: inningsAt4Wickets,
        firstInningsTotalRuns: null,
        battingScores: {},
        bowlingScores: {},
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        previousBowlerId: null,
        input: const BallDeliveryInput(
          runsOffBat: 0,
          isWicket: true,
          wicketType: WicketType.bowled,
          newBatsmanId: 'p6', // 6th player comes in
        ),
      );

      expect(result5thWicket.innings.wickets, equals(5));
      expect(result5thWicket.innings.completed, isFalse, reason: 'Innings should NOT be completed at 5 wickets in 6-a-side LMS');
      expect(result5thWicket.innings.allOut, isFalse);
      expect(result5thWicket.strikerId, equals('p6'));
      expect(result5thWicket.nonStrikerId, equals('p6'), reason: 'Last Man Standing bats alone');

      // 6th wicket falls (All Out)
      final result6thWicket = CricketScoringEngine.processDelivery(
        match: match,
        innings: result5thWicket.innings,
        firstInningsTotalRuns: null,
        battingScores: result5thWicket.battingScores,
        bowlingScores: result5thWicket.bowlingScores,
        strikerId: 'p6',
        nonStrikerId: 'p6',
        bowlerId: 'b1',
        previousBowlerId: null,
        input: const BallDeliveryInput(
          runsOffBat: 0,
          isWicket: true,
          wicketType: WicketType.bowled,
        ),
      );

      expect(result6thWicket.innings.wickets, equals(6));
      expect(result6thWicket.innings.completed, isTrue, reason: 'Innings should complete at 6 wickets (all out)');
      expect(result6thWicket.innings.allOut, isTrue);
    });

    test('Match with 11 players in lineup and 10 overs does NOT finish or trigger LMS on 6th wicket', () {
      final elevenPlayerIds = List.generate(11, (i) => 'player_$i');
      final matchDoc = MatchModel.fromMap('match_7', {
        'matchNumber': 7,
        'oversPerSide': 10,
        'teamAPlayingVI': elevenPlayerIds,
        'teamBPlayingVI': elevenPlayerIds,
        'rules': {
          'allowLastManStanding': true, // Stale default in Firestore
          'maxWickets': 6, // Stale default in Firestore
        },
      });

      expect(matchDoc.playersPerTeam, equals(11));
      expect(matchDoc.allowLastManStanding, isFalse);
      expect(matchDoc.maxWickets, equals(10));

      final inningsAt5 = InningsModel(
        id: 'inn_m7_1',
        matchId: 'match_7',
        inningsNumber: 1,
        battingTeamId: 'team_a',
        bowlingTeamId: 'team_b',
        wickets: 5,
        balls: 5,
        runs: 0,
      );

      // 6th wicket falls
      final result6th = CricketScoringEngine.processDelivery(
        match: matchDoc,
        innings: inningsAt5,
        firstInningsTotalRuns: null,
        battingScores: {},
        bowlingScores: {},
        strikerId: 'player_5',
        nonStrikerId: 'player_6',
        bowlerId: 'bowler_1',
        previousBowlerId: null,
        input: const BallDeliveryInput(
          runsOffBat: 0,
          isWicket: true,
          wicketType: WicketType.bowled,
          newBatsmanId: 'player_7',
        ),
      );

      expect(result6th.innings.wickets, equals(6));
      expect(result6th.innings.completed, isFalse, reason: '11-player match must not end on 6th wicket');
      expect(result6th.innings.allOut, isFalse);
      expect(result6th.strikerId, equals('player_6'), reason: 'Over ended on ball 6, rotating strike');
      expect(result6th.nonStrikerId, equals('player_7'));
    });

    test('Grand Final in 10-over tournament enforces 10 overs and 2-over bowler quota', () {
      final finalMatchDoc = MatchModel.fromMap('final_match_1', {
        'stage': 'FINAL',
        'oversPerSide': 10,
        'formatType': 'T10',
        'rules': {
          'oversPerSide': 10,
        },
      });

      expect(finalMatchDoc.isFinal, isTrue);
      expect(finalMatchDoc.maxOvers, equals(10), reason: 'Final match must have 10 overs, not hardcoded 5');
      expect(finalMatchDoc.maxBalls, equals(60));

      final inningsAt5Overs = InningsModel(
        id: 'inn_final_1',
        matchId: 'final_match_1',
        inningsNumber: 1,
        battingTeamId: 'team_a',
        bowlingTeamId: 'team_b',
        wickets: 2,
        balls: 30, // 5.0 overs completed
        runs: 45,
      );

      // Scoring delivery at ball 30 (5.0 overs) should NOT finish innings
      final result = CricketScoringEngine.processDelivery(
        match: finalMatchDoc,
        innings: inningsAt5Overs,
        firstInningsTotalRuns: null,
        battingScores: {},
        bowlingScores: {},
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b2',
        previousBowlerId: 'b1',
        input: const BallDeliveryInput(runsOffBat: 1),
      );

      expect(result.innings.balls, equals(31));
      expect(result.innings.completed, isFalse, reason: '10-over Grand Final must not end after 5.0 overs');

      // Bowler quota for 10 overs allows 2 overs (12 balls)
      final quotaBalls = CricketScoringEngine.getBowlerMaxBalls(
        bowlerId: 'b2',
        stage: MatchStage.finalMatch,
        bowlingScores: [],
        matchOvers: finalMatchDoc.maxOvers,
      );
      expect(quotaBalls, equals(12), reason: 'Each bowler gets 2 overs in 10-over Final');
    });

    test('Grand Final in T20 tournament enforces 20 overs and 4-over bowler quota', () {
      final t20FinalDoc = MatchModel.fromMap('final_t20', {
        'stage': 'FINAL',
        'formatType': 'T20',
        'rules': {
          'formatType': 'T20',
        },
      });

      expect(t20FinalDoc.isFinal, isTrue);
      expect(t20FinalDoc.maxOvers, equals(20), reason: 'T20 Final must have 20 overs');
      expect(t20FinalDoc.maxBalls, equals(120));

      final quotaBalls = CricketScoringEngine.getBowlerMaxBalls(
        bowlerId: 'b1',
        stage: MatchStage.finalMatch,
        bowlingScores: [],
        matchOvers: t20FinalDoc.maxOvers,
      );
      expect(quotaBalls, equals(24), reason: 'Each bowler gets 4 overs in T20 Final');
    });
  });
}
