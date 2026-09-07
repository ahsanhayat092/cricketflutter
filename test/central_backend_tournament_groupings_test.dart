import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wpl_cricket_app/features/scoring/models/match_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/tournament_model.dart';
import 'package:wpl_cricket_app/features/standings/models/standing.dart';

void main() {
  group('Central Backend Brain Integration - TournamentModel Tests', () {
    test('TournamentModel parses GROUPS_AND_KNOCKOUT configuration correctly', () {
      final data = {
        'id': 'tour_wpl_2026',
        'name': 'WASA Premier League 2026',
        'stageFormat': 'GROUPS_AND_KNOCKOUT',
        'groupPlayoffFormat': 'GROUP_SEMI_FINALS',
        'groups': ['A', 'B'],
        'groupCount': 2,
        'teamsPerGroupAdvance': 2,
        'oversPerSide': 10,
        'championTeamId': 'team_falcons',
      };

      final tournament = TournamentModel.fromMap(data, id: 'tour_wpl_2026');

      expect(tournament.stageFormat, equals('GROUPS_AND_KNOCKOUT'));
      expect(tournament.isGroupsAndKnockout, isTrue);
      expect(tournament.groupPlayoffFormat, equals('GROUP_SEMI_FINALS'));
      expect(tournament.groups, equals(['A', 'B']));
      expect(tournament.groupCount, equals(2));
      expect(tournament.teamsPerGroupAdvance, equals(2));
      expect(tournament.oversPerSide, equals(10));
      expect(tournament.championTeamId, equals('team_falcons'));

      final serialized = tournament.toMap();
      expect(serialized['stageFormat'], equals('GROUPS_AND_KNOCKOUT'));
      expect(serialized['groupPlayoffFormat'], equals('GROUP_SEMI_FINALS'));
      expect(serialized['groups'], equals(['A', 'B']));
      expect(serialized['groupCount'], equals(2));
      expect(serialized['teamsPerGroupAdvance'], equals(2));
      expect(serialized['championTeamId'], equals('team_falcons'));
    });

    test('TournamentModel defaults to ROUND_ROBIN when stageFormat is null', () {
      final tournament = TournamentModel.fromMap({'name': 'Casual League'}, id: 'tour_1');
      expect(tournament.stageFormat, equals('ROUND_ROBIN'));
      expect(tournament.isGroupsAndKnockout, isFalse);
    });
  });

  group('Central Backend Brain Integration - MatchModel Tests', () {
    test('MatchModel supports nullable teamAId & teamBId for TBD fixtures', () {
      final data = {
        'id': 'match_semi_1',
        'matchNumber': 11,
        'stage': 'SEMI_1',
        'teamAId': null,
        'teamBId': null,
        'oversPerSide': 8,
        'status': 'UPCOMING',
      };

      final match = MatchModel.fromMap('match_semi_1', data);

      expect(match.teamAId, isNull);
      expect(match.teamBId, isNull);
      expect(match.stage, equals('SEMI_1'));
      expect(match.oversPerSide, equals(8));
      expect(match.isSemi, isTrue);
      expect(match.isKnockout, isTrue);
    });

    test('MatchModel parses Firestore Timestamp completedAt without throwing type cast error', () {
      final now = DateTime.now();
      final data = {
        'id': 'match_completed_1',
        'matchNumber': 1,
        'stage': 'LEAGUE',
        'status': 'COMPLETED',
        'winningTeamId': 'team_a',
        'completedAt': Timestamp.fromDate(now),
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final match = MatchModel.fromMap('match_completed_1', data);
      expect(match.completedAt, isNotNull);
      expect(match.completedAt, equals(now.toIso8601String()));
      expect(match.status, equals('COMPLETED'));
    });

    test('MatchModel stageDisplayName formats correctly for groups and knockout stages', () {
      final leagueMatch = MatchModel.fromMap('m_1', {
        'matchNumber': 3,
        'stage': 'LEAGUE',
        'groupName': 'A',
      });
      expect(leagueMatch.stageDisplayName, equals('Group A · Match #3'));

      final semi1 = MatchModel.fromMap('m_sf1', {
        'matchNumber': 11,
        'stage': 'SEMI_1',
      });
      expect(semi1.stageDisplayName, equals('🎯 Semi-Final 1 (A1 vs B2)'));

      final semi2 = MatchModel.fromMap('m_sf2', {
        'matchNumber': 12,
        'stage': 'SEMI_2',
      });
      expect(semi2.stageDisplayName, equals('🎯 Semi-Final 2 (B1 vs A2)'));

      final finalMatch = MatchModel.fromMap('m_final', {
        'matchNumber': 13,
        'stage': 'FINAL',
      });
      expect(finalMatch.stageDisplayName, equals('🏆 Grand Final'));
    });

    test('MatchModel getPlaceholderTeamName provides accurate TBD placeholders', () {
      final semi1 = MatchModel.fromMap('m_sf1', {'stage': 'SEMI_1'});
      expect(semi1.getPlaceholderTeamName(isTeamA: true), equals('TBD (Winner Group A)'));
      expect(semi1.getPlaceholderTeamName(isTeamA: false), equals('TBD (Runner-up Group B)'));

      final semi2 = MatchModel.fromMap('m_sf2', {'stage': 'SEMI_2'});
      expect(semi2.getPlaceholderTeamName(isTeamA: true), equals('TBD (Winner Group B)'));
      expect(semi2.getPlaceholderTeamName(isTeamA: false), equals('TBD (Runner-up Group A)'));

      final grandFinalSF = MatchModel.fromMap('m_final', {'stage': 'FINAL'});
      expect(grandFinalSF.getPlaceholderTeamName(isTeamA: true, groupPlayoffFormat: 'GROUP_SEMI_FINALS'), equals('TBD (Winner SF1)'));
      expect(grandFinalSF.getPlaceholderTeamName(isTeamA: false, groupPlayoffFormat: 'GROUP_SEMI_FINALS'), equals('TBD (Winner SF2)'));

      final grandFinalDirect = MatchModel.fromMap('m_final_dir', {'stage': 'FINAL'});
      expect(grandFinalDirect.getPlaceholderTeamName(isTeamA: true, groupPlayoffFormat: 'GROUP_DIRECT_FINAL'), equals('TBD (Winner Group A)'));
      expect(grandFinalDirect.getPlaceholderTeamName(isTeamA: false, groupPlayoffFormat: 'GROUP_DIRECT_FINAL'), equals('TBD (Winner Group B)'));
    });
  });

  group('Central Backend Brain Integration - StandingModel Tests', () {
    test('StandingModel parses groupName, position, status, and ICC NRR', () {
      final data = {
        'teamId': 'team_lahore_lions',
        'groupName': 'A',
        'position': 1,
        'status': 'QUALIFIED_PLAYOFF',
        'netRunRate': 1.875,
        'points': 6,
        'matchesPlayed': 3,
        'won': 3,
        'lost': 0,
      };

      final standing = StandingModel.fromMap('lahore_lions_standing', data);

      expect(standing.teamId, equals('team_lahore_lions'));
      expect(standing.groupName, equals('A'));
      expect(standing.position, equals(1));
      expect(standing.status, equals('QUALIFIED_PLAYOFF'));
      expect(standing.netRunRate, closeTo(1.875, 0.001));
      expect(standing.nrr, closeTo(1.875, 0.001));
      expect(standing.nrrFormatted, equals('+1.875'));

      final serialized = standing.toMap();
      expect(serialized['groupName'], equals('A'));
      expect(serialized['position'], equals(1));
      expect(serialized['status'], equals('QUALIFIED_PLAYOFF'));
      expect(serialized['netRunRate'], equals(1.875));
    });
  });
}
