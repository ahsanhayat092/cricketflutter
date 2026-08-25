import 'package:flutter_test/flutter_test.dart';
import 'package:wpl_cricket_app/features/scoring/engine/cricket_scoring_engine.dart';
import 'package:wpl_cricket_app/features/scoring/models/ball_event.dart';
import 'package:wpl_cricket_app/features/scoring/models/bowling_score.dart';
import 'package:wpl_cricket_app/features/scoring/models/innings_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/match_model.dart';

void main() {
  group('CricketScoringEngine Tests', () {
    late MatchModel testMatch;
    late InningsModel testInnings1;
    late InningsModel testInnings2;

    setUp(() {
      testMatch = const MatchModel(
        id: 'match-1',
        matchNumber: 1,
        stage: 'LEAGUE',
        teamAId: 'team-a',
        teamBId: 'team-b',
        date: '2026-08-22',
        teamAPlayingVI: ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'],
        teamBPlayingVI: ['b1', 'b2', 'b3', 'b4', 'b5', 'b6'],
      );

      testInnings1 = const InningsModel(
        id: 'inn-1',
        matchId: 'match-1',
        inningsNumber: 1,
        battingTeamId: 'team-a',
        bowlingTeamId: 'team-b',
      );

      testInnings2 = const InningsModel(
        id: 'inn-2',
        matchId: 'match-1',
        inningsNumber: 2,
        battingTeamId: 'team-b',
        bowlingTeamId: 'team-a',
      );
    });

    test('Single run rotates strike and increments batsman/bowler stats', () {
      final res = CricketScoringEngine.processDelivery(
        match: testMatch,
        innings: testInnings1,
        firstInningsTotalRuns: null,
        battingScores: {},
        bowlingScores: {},
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        previousBowlerId: null,
        input: const BallDeliveryInput(runsOffBat: 1),
      );

      expect(res.innings.runs, 1);
      expect(res.innings.balls, 1);
      expect(res.strikerId, 'p2'); // Strike rotated
      expect(res.nonStrikerId, 'p1');
      expect(res.battingScores['p1']?.runs, 1);
      expect(res.battingScores['p1']?.balls, 1);
      expect(res.bowlingScores['b1']?.runs, 1);
      expect(res.bowlingScores['b1']?.balls, 1);
    });

    test('Four and Six trigger celebrations', () {
      final fourRes = CricketScoringEngine.processDelivery(
        match: testMatch,
        innings: testInnings1,
        firstInningsTotalRuns: null,
        battingScores: {},
        bowlingScores: {},
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        previousBowlerId: null,
        input: const BallDeliveryInput(runsOffBat: 4),
      );

      expect(fourRes.celebrationType, 'FOUR');
      expect(fourRes.battingScores['p1']?.fours, 1);
      expect(fourRes.strikerId, 'p1'); // Even runs -> strike remains

      final sixRes = CricketScoringEngine.processDelivery(
        match: testMatch,
        innings: testInnings1,
        firstInningsTotalRuns: null,
        battingScores: {},
        bowlingScores: {},
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        previousBowlerId: null,
        input: const BallDeliveryInput(runsOffBat: 6),
      );

      expect(sixRes.celebrationType, 'SIX');
      expect(sixRes.battingScores['p1']?.sixes, 1);
    });

    test('RecentEvent includes batterName, bowlerName, and dismissal for Wicket and Boundaries', () {
      final playerNames = {
        'p1': 'Babar Azam',
        'p2': 'Mohammad Rizwan',
        'p3': 'Fakhar Zaman',
        'b1': 'Shaheen Afridi',
      };

      // 1. FOUR Event
      final fourRes = CricketScoringEngine.processDelivery(
        match: testMatch,
        innings: testInnings1,
        firstInningsTotalRuns: null,
        battingScores: {},
        bowlingScores: {},
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        previousBowlerId: null,
        input: const BallDeliveryInput(runsOffBat: 4),
        playerNames: playerNames,
      );

      final fourEvent = fourRes.match.recentEvent;
      expect(fourEvent, isNotNull);
      expect(fourEvent!.type, 'FOUR');
      expect(fourEvent.batterName, 'Babar Azam');
      expect(fourEvent.bowlerName, 'Shaheen Afridi');
      expect(fourEvent.text, 'Babar Azam smashes a boundary FOUR! 🏏');

      final fourMap = fourEvent.toMap();
      expect(fourMap['batterName'], 'Babar Azam');
      expect(fourMap['bowlerName'], 'Shaheen Afridi');
      expect(fourMap['type'], 'FOUR');

      // 2. SIX Event
      final sixRes = CricketScoringEngine.processDelivery(
        match: testMatch,
        innings: testInnings1,
        firstInningsTotalRuns: null,
        battingScores: {},
        bowlingScores: {},
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        previousBowlerId: null,
        input: const BallDeliveryInput(runsOffBat: 6),
        playerNames: playerNames,
      );

      final sixEvent = sixRes.match.recentEvent;
      expect(sixEvent, isNotNull);
      expect(sixEvent!.type, 'SIX');
      expect(sixEvent.batterName, 'Babar Azam');
      expect(sixEvent.bowlerName, 'Shaheen Afridi');
      expect(sixEvent.text, 'Babar Azam launches a colossal SIX! 🚀');

      // 3. WICKET Event
      final wicketRes = CricketScoringEngine.processDelivery(
        match: testMatch,
        innings: testInnings1,
        firstInningsTotalRuns: null,
        battingScores: {},
        bowlingScores: {},
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        previousBowlerId: null,
        input: const BallDeliveryInput(
          isWicket: true,
          wicketType: WicketType.caught,
          outBatsmanId: 'p1',
          newBatsmanId: 'p3',
          dismissalDescription: 'c Fakhar Zaman b Shaheen Afridi',
        ),
        playerNames: playerNames,
      );

      final wicketEvent = wicketRes.match.recentEvent;
      expect(wicketEvent, isNotNull);
      expect(wicketEvent!.type, 'WICKET');
      expect(wicketEvent.batterName, 'Babar Azam');
      expect(wicketEvent.bowlerName, 'Shaheen Afridi');
      expect(wicketEvent.dismissal, 'c Fakhar Zaman b Shaheen Afridi');
      expect(wicketEvent.text, 'Babar Azam is OUT (c Fakhar Zaman b Shaheen Afridi)! 🔴');

      final wicketMap = wicketEvent.toMap();
      expect(wicketMap['batterName'], 'Babar Azam');
      expect(wicketMap['bowlerName'], 'Shaheen Afridi');
      expect(wicketMap['dismissal'], 'c Fakhar Zaman b Shaheen Afridi');
    });

    test('Wide adds 1 extra run without consuming legal ball', () {
      final res = CricketScoringEngine.processDelivery(
        match: testMatch,
        innings: testInnings1,
        firstInningsTotalRuns: null,
        battingScores: {},
        bowlingScores: {},
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        previousBowlerId: null,
        input: const BallDeliveryInput(
          extraType: ExtraType.wide,
          extraRuns: 1,
        ),
      );

      expect(res.innings.runs, 1);
      expect(res.innings.balls, 0); // Not a legal ball
      expect(res.innings.wides, 1);
      expect(res.bowlingScores['b1']?.runs, 1);
      expect(res.bowlingScores['b1']?.balls, 0);
      expect(res.bowlingScores['b1']?.wides, 1);
      expect(res.battingScores['p1']?.balls, 0); // Batsman ball not incremented
    });

    test('5th Wicket triggers Last Man Standing transition (6th player bats alone)', () {
      final fourWicketsInnings = testInnings1.copyWith(wickets: 4);

      final res = CricketScoringEngine.processDelivery(
        match: testMatch,
        innings: fourWicketsInnings,
        firstInningsTotalRuns: null,
        battingScores: {},
        bowlingScores: {},
        strikerId: 'p5',
        nonStrikerId: 'p6',
        bowlerId: 'b1',
        previousBowlerId: null,
        input: const BallDeliveryInput(
          isWicket: true,
          wicketType: WicketType.bowled,
          outBatsmanId: 'p5',
          newBatsmanId: 'p6',
          dismissalDescription: 'b b1',
        ),
      );

      expect(res.innings.wickets, 5);
      expect(res.innings.allOut, isFalse); // 5th wicket is NOT all out (Last Man Standing)
      expect(res.isInningsCompleted, isFalse);
      expect(res.celebrationType, 'LAST_MAN_STANDING');
      expect(res.celebrationText, '⚡ Last Man Standing! The 6th player is now batting alone.');
      expect(res.strikerId, 'p6');
      expect(res.nonStrikerId, 'p6'); // Solitary batsman
    });

    test('6 Wickets triggers ALL OUT and completes innings', () {
      final fiveWicketsInnings = testInnings1.copyWith(wickets: 5);

      final res = CricketScoringEngine.processDelivery(
        match: testMatch,
        innings: fiveWicketsInnings,
        firstInningsTotalRuns: null,
        battingScores: {},
        bowlingScores: {},
        strikerId: 'p6',
        nonStrikerId: 'p6',
        bowlerId: 'b1',
        previousBowlerId: null,
        input: const BallDeliveryInput(
          isWicket: true,
          wicketType: WicketType.bowled,
          outBatsmanId: 'p6',
          dismissalDescription: 'b b1',
        ),
      );

      expect(res.innings.wickets, 6);
      expect(res.innings.allOut, isTrue);
      expect(res.innings.completed, isTrue);
      expect(res.isInningsCompleted, isTrue);
    });

    test('2nd Innings Target Chase auto-ends match immediately when target reached with team name', () {
      final chasingInnings = testInnings2.copyWith(runs: 32);

      final res = CricketScoringEngine.processDelivery(
        match: testMatch,
        innings: chasingInnings,
        firstInningsTotalRuns: 35, // Target = 36
        battingScores: {},
        bowlingScores: {},
        strikerId: 'b1',
        nonStrikerId: 'b2',
        bowlerId: 'p1',
        previousBowlerId: null,
        input: const BallDeliveryInput(runsOffBat: 4), // 32 + 4 = 36 >= 36
        teamNames: {'team-a': 'Team Alpha', 'team-b': 'Team Bravo'},
      );

      expect(res.innings.runs, 36);
      expect(res.isMatchCompleted, isTrue);
      expect(res.isInningsCompleted, isTrue);
      expect(res.match.status, 'COMPLETED');
      expect(res.match.winnerTeamId, 'team-b');
      expect(res.match.resultText, 'Team Bravo won by 6 wickets');
    });

    test('2nd Innings 6 Wickets All Out ends match with bowling team winning by run margin and team name', () {
      final almostAllOutChasingInnings = testInnings2.copyWith(runs: 42, wickets: 5);

      final res = CricketScoringEngine.processDelivery(
        match: testMatch,
        innings: almostAllOutChasingInnings,
        firstInningsTotalRuns: 100, // Target was 101, Chasing team at 42 runs, 5 wkts
        battingScores: {},
        bowlingScores: {},
        strikerId: 'b6',
        nonStrikerId: 'b6',
        bowlerId: 'p1',
        previousBowlerId: null,
        input: const BallDeliveryInput(
          isWicket: true,
          wicketType: WicketType.bowled,
          outBatsmanId: 'b6',
        ),
        teamNames: {'team-a': 'Royal Strikers', 'team-b': 'Super Kings'},
      );

      expect(res.innings.wickets, 6);
      expect(res.innings.allOut, isTrue);
      expect(res.isMatchCompleted, isTrue);
      expect(res.isInningsCompleted, isTrue);
      expect(res.match.status, 'COMPLETED');
      expect(res.match.winnerTeamId, 'team-a');
      expect(res.match.resultText, 'Royal Strikers won by 58 runs');
    });

    test('Consecutive Over Guard prevents same bowler from bowling consecutive over', () {
      final canBowl = CricketScoringEngine.canBowlerBowlNextOver(
        bowlerId: 'b1',
        previousBowlerId: 'b1',
        isFinalMatch: false,
        bowlingScores: {'b1': const BowlingScore(id: '1', inningsId: '1', playerId: 'b1', balls: 6)},
      );

      expect(canBowl, isFalse);

      final eligible = CricketScoringEngine.isBowlerEligibleForNextOver(
        bowlerId: 'b1',
        lastOverBowlerId: 'b1',
        stage: MatchStage.league,
        bowlingScores: [const BowlingScore(id: '1', inningsId: '1', playerId: 'b1', balls: 0)],
      );
      expect(eligible, isFalse);
    });

    test('League stage restricts each bowler to max 1 over (6 legal balls)', () {
      expect(
        CricketScoringEngine.getBowlerMaxBalls(
          bowlerId: 'b1',
          stage: MatchStage.league,
          bowlingScores: [],
        ),
        6,
      );

      final isExhausted = CricketScoringEngine.isBowlerQuotaExhausted(
        bowlerId: 'b1',
        stage: MatchStage.league,
        bowlingScores: [const BowlingScore(id: '1', inningsId: '1', playerId: 'b1', balls: 6)],
      );
      expect(isExhausted, isTrue);
    });

    test('Final match allows exactly ONE bowler up to 2 overs (12 legal balls)', () {
      // 1. Initial state: bowler b1 has bowled 6 balls, b2 has bowled 6 balls
      final scores = [
        const BowlingScore(id: '1', inningsId: '1', playerId: 'b1', balls: 6),
        const BowlingScore(id: '2', inningsId: '1', playerId: 'b2', balls: 6),
      ];

      expect(
        CricketScoringEngine.getBowlerMaxBalls(
          bowlerId: 'b1',
          stage: MatchStage.finalMatch,
          bowlingScores: scores,
        ),
        12,
      );

      // b1 is eligible to bowl their 2nd over if last over was bowled by b2
      final canB1Bowl = CricketScoringEngine.isBowlerEligibleForNextOver(
        bowlerId: 'b1',
        lastOverBowlerId: 'b2',
        stage: MatchStage.finalMatch,
        bowlingScores: scores,
      );
      expect(canB1Bowl, isTrue);

      // 2. Now b1 bowls their 2nd over and reaches 12 balls
      final scoresAfterB1TwoOvers = [
        const BowlingScore(id: '1', inningsId: '1', playerId: 'b1', balls: 12),
        const BowlingScore(id: '2', inningsId: '1', playerId: 'b2', balls: 6),
      ];

      // b1 quota is now exhausted
      expect(
        CricketScoringEngine.isBowlerQuotaExhausted(
          bowlerId: 'b1',
          stage: MatchStage.finalMatch,
          bowlingScores: scoresAfterB1TwoOvers,
        ),
        isTrue,
      );

      // b2 max balls is now capped strictly at 6 balls (cannot bowl a 2nd over)
      expect(
        CricketScoringEngine.getBowlerMaxBalls(
          bowlerId: 'b2',
          stage: MatchStage.finalMatch,
          bowlingScores: scoresAfterB1TwoOvers,
        ),
        6,
      );

      // b2 quota is now exhausted because 1 bowler (b1) already took the 2-over slot
      expect(
        CricketScoringEngine.isBowlerEligibleForNextOver(
          bowlerId: 'b2',
          lastOverBowlerId: 'b3',
          stage: MatchStage.finalMatch,
          bowlingScores: scoresAfterB1TwoOvers,
        ),
        isFalse,
      );
    });

    test('6th legal ball of over completes over and clears currentBowlerId to null', () {
      final fiveBallsInnings = testInnings1.copyWith(balls: 5);
      final res = CricketScoringEngine.processDelivery(
        match: testMatch,
        innings: fiveBallsInnings,
        firstInningsTotalRuns: null,
        battingScores: {},
        bowlingScores: {'b1': const BowlingScore(id: '1', inningsId: '1', playerId: 'b1', balls: 5)},
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        previousBowlerId: null,
        input: const BallDeliveryInput(runsOffBat: 1),
      );

      expect(res.isOverCompleted, isTrue);
      expect(res.currentBowlerId, isNull);
      expect(res.previousBowlerId, 'b1');
    });

    test('Engine rejects delivery if bowler has already bowled 6 balls in league match', () {
      final sixBallsInnings = testInnings1.copyWith(balls: 6);
      final res = CricketScoringEngine.processDelivery(
        match: testMatch, // League match
        innings: sixBallsInnings,
        firstInningsTotalRuns: null,
        battingScores: {},
        bowlingScores: {'b1': const BowlingScore(id: '1', inningsId: '1', playerId: 'b1', balls: 6)},
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1', // Same bowler trying to bowl 7th ball
        previousBowlerId: 'b1',
        input: const BallDeliveryInput(runsOffBat: 2),
      );

      // Must reject and clear bowler
      expect(res.currentBowlerId, isNull);
      expect(res.innings.balls, 6); // Ball not added
    });

    test('Free Hit lifecycle: No-Ball triggers, Wide preserves, and legal ball consumes Free Hit', () {
      // 1. Initial ball: No-Ball is bowled
      final nbRes = CricketScoringEngine.processDelivery(
        match: testMatch,
        innings: testInnings1,
        firstInningsTotalRuns: null,
        battingScores: {},
        bowlingScores: {},
        strikerId: 'p1',
        nonStrikerId: 'p2',
        bowlerId: 'b1',
        previousBowlerId: null,
        input: const BallDeliveryInput(
          extraType: ExtraType.noBall,
          extraRuns: 1,
          runsOffBat: 0,
        ),
      );

      // Next ball MUST be a Free Hit
      expect(nbRes.innings.isFreeHit, isTrue);
      expect(nbRes.innings.noBalls, 1);
      expect(nbRes.innings.balls, 0); // No-ball does not consume legal ball

      // 2. Next delivery is a Wide on Free Hit: Free Hit must NOT be consumed
      final wideOnFhRes = CricketScoringEngine.processDelivery(
        match: testMatch,
        innings: nbRes.innings, // isFreeHit is true
        firstInningsTotalRuns: null,
        battingScores: nbRes.battingScores,
        bowlingScores: nbRes.bowlingScores,
        strikerId: nbRes.strikerId ?? 'p1',
        nonStrikerId: nbRes.nonStrikerId ?? 'p2',
        bowlerId: 'b1',
        previousBowlerId: null,
        input: const BallDeliveryInput(
          extraType: ExtraType.wide,
          extraRuns: 1,
        ),
      );

      // Free Hit remains active because Wide is an illegal delivery
      expect(wideOnFhRes.innings.isFreeHit, isTrue);
      expect(wideOnFhRes.innings.wides, 1);
      expect(wideOnFhRes.innings.balls, 0);

      // 3. Next delivery is a legal ball (e.g. 2 runs scored)
      final legalFhRes = CricketScoringEngine.processDelivery(
        match: testMatch,
        innings: wideOnFhRes.innings, // isFreeHit is true
        firstInningsTotalRuns: null,
        battingScores: wideOnFhRes.battingScores,
        bowlingScores: wideOnFhRes.bowlingScores,
        strikerId: wideOnFhRes.strikerId ?? 'p1',
        nonStrikerId: wideOnFhRes.nonStrikerId ?? 'p2',
        bowlerId: 'b1',
        previousBowlerId: null,
        input: const BallDeliveryInput(runsOffBat: 2),
      );

      // Free Hit is now consumed after the legal delivery!
      expect(legalFhRes.innings.isFreeHit, isFalse);
      expect(legalFhRes.innings.balls, 1);
      expect(legalFhRes.innings.runs, 4); // 1 (nb) + 1 (wd) + 2 (runs)
    });
  });
}
