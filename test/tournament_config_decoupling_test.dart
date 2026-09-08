import 'package:flutter/material.dart';
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
  group('TournamentConfig & UiPresentationConfig Parsing Tests', () {
    test('parses full JSON tournament config contract accurately', () {
      final jsonConfig = {
        'version': '1.0.0',
        'meta': {
          'preset': 'T10_TAPE_BALL',
          'ballType': 'HEAVY_TENNIS',
          'pitchType': 'TURF',
          'boundaryMeters': 55,
        },
        'matchRules': {
          'oversPerSide': 8,
          'ballsPerOver': 6,
          'maxOversPerBowler': 2,
          'playersPerTeam': 8,
          'maxDismissals': 7,
          'allowLastManStanding': false,
          'noBallRule': {
            'freeHit': true,
            'runs': 2,
            'reball': false,
          },
          'wideRule': {
            'runs': 1,
            'reball': true,
          },
          'superOver': {
            'enabled': true,
            'maxOvers': 1,
          },
        },
        'stages': [
          {
            'id': 'stage-groups',
            'name': 'Group Stage',
            'type': 'GROUPS',
            'sequenceOrder': 1,
            'groups': [
              {
                'id': 'A',
                'name': 'Group Alpha',
                'colorAccent': '#06B6D4',
                'qualifyingSlots': 2,
              },
              {
                'id': 'B',
                'name': 'Group Beta',
                'colorAccent': '#A855F7',
                'qualifyingSlots': 2,
              },
            ],
            'advancementRule': {
              'type': 'CROSS_SEMI_FINALS',
              'description': 'Top 2 from each group advance to Cross Semi-Finals (A1 vs B2, B1 vs A2)',
            },
          },
          {
            'id': 'stage-knockout',
            'name': 'Knockout Stage',
            'type': 'KNOCKOUT',
            'sequenceOrder': 2,
          },
        ],
        'pointsConfig': {
          'win': 2,
          'tie': 1,
          'noResult': 1,
          'loss': 0,
        },
        'tieBreakers': {
          'primary': 'NRR',
          'secondary': 'HEAD_TO_HEAD',
        },
      };

      final config = TournamentConfig.fromMap(jsonConfig);

      expect(config.version, '1.0.0');
      expect(config.meta.preset, 'T10_TAPE_BALL');
      expect(config.meta.ballType, 'HEAVY_TENNIS');
      expect(config.matchRules.oversPerSide, 8);
      expect(config.matchRules.playersPerTeam, 8);
      expect(config.matchRules.maxDismissals, 7);
      expect(config.matchRules.noBallRule.freeHit, true);
      expect(config.matchRules.noBallRule.runs, 2);
      expect(config.matchRules.noBallRule.reball, false);
      expect(config.matchRules.wideRule.reball, true);
      expect(config.stages.length, 2);
      expect(config.groupsStage, isNotNull);
      expect(config.groupsStage!.groups.length, 2);
      expect(config.groupsStage!.findGroup('A')?.name, 'Group Alpha');
      expect(config.groupsStage!.findGroup('B')?.color, const Color(0xFFA855F7));
      expect(config.groupsStage!.advancementRule?.type, 'CROSS_SEMI_FINALS');
    });

    test('parses UiPresentationConfig with themes and qualifier badges', () {
      final jsonUi = {
        'standingsLayout': 'GROUPED_TABS',
        'showNrr': true,
        'scoringUiMode': 'STANDARD_CRICKET',
        'groupThemes': {
          'A': {'name': 'Group Alpha', 'primary': '#06B6D4'},
          'B': {'name': 'Group Beta', 'primary': '#A855F7'},
        },
        'qualifierBadges': [
          {'rankCutoff': 1, 'label': 'Semi-Final 1 (Q)', 'badgeColor': '#10B981'},
          {'rankCutoff': 2, 'label': 'Semi-Final 2 (Q)', 'badgeColor': '#06B6D4'},
        ],
      };

      final uiPres = UiPresentationConfig.fromMap(jsonUi);

      expect(uiPres.isGroupedTabs, true);
      expect(uiPres.isSingleLeague, false);
      expect(uiPres.getGroupTheme('A').name, 'Group Alpha');
      expect(uiPres.getGroupTheme('A').primaryColor, const Color(0xFF06B6D4));
      expect(uiPres.getGroupTheme('B').primaryColor, const Color(0xFFA855F7));

      final badge1 = uiPres.getBadgeForPosition(1);
      expect(badge1, isNotNull);
      expect(badge1!.label, 'Semi-Final 1 (Q)');
      expect(badge1.badgeColor, const Color(0xFF10B981));

      final badge2 = uiPres.getBadgeForPosition(2);
      expect(badge2, isNotNull);
      expect(badge2!.label, 'Semi-Final 2 (Q)');

      final badge3 = uiPres.getBadgeForPosition(3);
      expect(badge3, isNull);
    });

    test('TournamentModel seamlessly integrates config and MatchRulesModel', () {
      final tournamentMap = {
        'name': 'Dynamic Super 8',
        'shortName': 'DS8',
        'config': {
          'matchRules': {
            'oversPerSide': 6,
            'ballsPerOver': 6,
            'maxOversPerBowler': 2,
            'playersPerTeam': 8,
            'maxDismissals': 7,
            'allowLastManStanding': true,
            'noBallRule': {'freeHit': false, 'runs': 1, 'reball': true},
          },
          'stages': [
            {
              'id': 'g1',
              'name': 'Groups',
              'type': 'GROUPS',
              'groups': [
                {'id': 'X', 'name': 'Pool X', 'qualifyingSlots': 1},
                {'id': 'Y', 'name': 'Pool Y', 'qualifyingSlots': 1},
              ],
              'advancementRule': {
                'type': 'DIRECT_FINAL',
                'description': 'Winner of Pool X plays Winner of Pool Y in Grand Final',
              },
            },
          ],
        },
      };

      final tournament = TournamentModel.fromMap(tournamentMap, id: 'tour-123');

      expect(tournament.rules.oversPerSide, 6);
      expect(tournament.rules.playersPerTeam, 8);
      expect(tournament.rules.maxWickets, 7);
      expect(tournament.rules.allowLastManStanding, true);
      expect(tournament.rules.freeHitEnabled, false);
      expect(tournament.effectiveTeamsPerGroupAdvance, 1);
      expect(tournament.isGroupsAndKnockout, true);
    });
  });

  group('CricketScoringEngine Dynamic Match Rules Tests', () {
    test('Delivery honors freeHitEnabled: false (no Free Hit awarded on No-Ball)', () {
      const matchRules = MatchRulesModel(
        oversPerSide: 5,
        ballsPerOver: 6,
        freeHitEnabled: false,
        noBallRuns: 1,
        noBallReball: true,
      );

      final match = MatchModel(
        id: 'match-1',
        matchNumber: 1,
        teamAId: 't1',
        teamBId: 't2',
        date: '2026-09-08',
        rules: matchRules,
      );

      final innings = InningsModel(
        id: 'inn-1',
        matchId: 'match-1',
        inningsNumber: 1,
        battingTeamId: 't1',
        bowlingTeamId: 't2',
        strikerId: 'batsman-1',
        nonStrikerId: 'batsman-2',
        currentBowlerId: 'bowler-1',
      );

      final result = CricketScoringEngine.processDelivery(
        match: match,
        innings: innings,
        firstInningsTotalRuns: null,
        battingScores: {
          'batsman-1': const BattingScore(id: 'bs1', inningsId: 'inn-1', playerId: 'batsman-1'),
        },
        bowlingScores: {'bowler-1': BowlingScore.empty('bowler-1', inningsId: 'inn-1')},
        strikerId: 'batsman-1',
        nonStrikerId: 'batsman-2',
        bowlerId: 'bowler-1',
        previousBowlerId: null,
        input: const BallDeliveryInput(
          extraType: ExtraType.noBall,
          extraRuns: 1,
        ),
      );

      expect(result.innings.runs, 1);
      expect(result.innings.balls, 0); // Reball == true, so legal ball count stays 0
      expect(result.innings.isFreeHit, false); // Crucial: freeHitEnabled is false
    });

    test('Delivery honors noBallReball: false (ball counted as legal delivery)', () {
      const matchRules = MatchRulesModel(
        oversPerSide: 5,
        ballsPerOver: 6,
        freeHitEnabled: true,
        noBallRuns: 2,
        noBallReball: false, // Box cricket: no re-bowl!
      );

      final match = MatchModel(
        id: 'match-1',
        matchNumber: 1,
        teamAId: 't1',
        teamBId: 't2',
        date: '2026-09-08',
        rules: matchRules,
      );

      final innings = InningsModel(
        id: 'inn-1',
        matchId: 'match-1',
        inningsNumber: 1,
        battingTeamId: 't1',
        bowlingTeamId: 't2',
        strikerId: 'batsman-1',
        nonStrikerId: 'batsman-2',
        currentBowlerId: 'bowler-1',
      );

      final result = CricketScoringEngine.processDelivery(
        match: match,
        innings: innings,
        firstInningsTotalRuns: null,
        battingScores: {
          'batsman-1': const BattingScore(id: 'bs1', inningsId: 'inn-1', playerId: 'batsman-1'),
        },
        bowlingScores: {'bowler-1': BowlingScore.empty('bowler-1', inningsId: 'inn-1')},
        strikerId: 'batsman-1',
        nonStrikerId: 'batsman-2',
        bowlerId: 'bowler-1',
        previousBowlerId: null,
        input: const BallDeliveryInput(
          extraType: ExtraType.noBall,
          extraRuns: 2,
        ),
      );

      expect(result.innings.runs, 2);
      expect(result.innings.balls, 1); // Crucial: ball counted towards over!
      expect(result.innings.isFreeHit, true);
    });

    test('Bowler quota honors dynamic maxOverPerBowler', () {
      const rules = MatchRulesModel(
        oversPerSide: 10,
        maxOverPerBowler: 3,
        ballsPerOver: 6,
      );

      // Max legal balls for bowler should be 3 * 6 = 18 balls
      final maxBalls = CricketScoringEngine.getBowlerMaxBalls(
        bowlerId: 'bowl1',
        stage: MatchStage.league,
        bowlingScores: [BowlingScore.empty('bowl1')],
        maxOverPerBowler: rules.maxOverPerBowler,
        matchOvers: rules.oversPerSide,
        ballsPerOver: rules.ballsPerOver,
      );
      expect(maxBalls, 18);

      final exhausted = CricketScoringEngine.isBowlerQuotaExhausted(
        bowlerId: 'bowl1',
        stage: MatchStage.league,
        bowlingScores: [
          const BowlingScore(
            id: 'bs1',
            inningsId: 'inn-1',
            playerId: 'bowl1',
            balls: 18,
            maidens: 0,
            runs: 12,
            wickets: 1,
            wides: 0,
            noBalls: 0,
          ),
        ],
        maxOverPerBowler: rules.maxOverPerBowler,
        matchOvers: rules.oversPerSide,
        ballsPerOver: rules.ballsPerOver,
      );
      expect(exhausted, true);

      final notExhausted = CricketScoringEngine.isBowlerQuotaExhausted(
        bowlerId: 'bowl1',
        stage: MatchStage.league,
        bowlingScores: [
          const BowlingScore(
            id: 'bs1',
            inningsId: 'inn-1',
            playerId: 'bowl1',
            balls: 17,
            maidens: 0,
            runs: 12,
            wickets: 1,
            wides: 0,
            noBalls: 0,
          ),
        ],
        maxOverPerBowler: rules.maxOverPerBowler,
        matchOvers: rules.oversPerSide,
        ballsPerOver: rules.ballsPerOver,
      );
      expect(notExhausted, false);
    });
  });
}
