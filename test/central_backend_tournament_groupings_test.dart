import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wpl_cricket_app/features/scoring/models/match_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/team_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/tournament_model.dart';
import 'package:wpl_cricket_app/features/standings/models/standing.dart';
import 'package:wpl_cricket_app/features/standings/providers/standings_provider.dart';

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

  group('Standings Screen Grouping & Partitioning Logic Tests', () {
    test('Strict group resolver partitions teams without duplication across Group A and Group B', () {
      final teams = [
        StandingWithTeam(
          standing: const StandingModel(id: 's1', teamId: 'sl', groupName: 'A', points: 4, nrr: 1.2),
          team: const TeamModel(id: 'sl', name: 'Sri Lanka', shortName: 'SL', groupName: 'A'),
        ),
        StandingWithTeam(
          standing: const StandingModel(id: 's2', teamId: 'ind', groupName: 'A', points: 6, nrr: 2.1),
          team: const TeamModel(id: 'ind', name: 'India', shortName: 'IND', groupName: 'A'),
        ),
        StandingWithTeam(
          standing: const StandingModel(id: 's3', teamId: 'pak', groupName: 'A', points: 2, nrr: -0.5),
          team: const TeamModel(id: 'pak', name: 'Pakistan', shortName: 'PAK', groupName: 'A'),
        ),
        StandingWithTeam(
          standing: const StandingModel(id: 's4', teamId: 'ban', groupName: 'B', points: 4, nrr: 0.8),
          team: const TeamModel(id: 'ban', name: 'Bangladesh', shortName: 'BAN', groupName: 'B'),
        ),
        StandingWithTeam(
          standing: const StandingModel(id: 's5', teamId: 'afg', groupName: 'B', points: 4, nrr: 1.5),
          team: const TeamModel(id: 'afg', name: 'Afghanistan', shortName: 'AFG', groupName: 'B'),
        ),
        StandingWithTeam(
          standing: const StandingModel(id: 's6', teamId: 'nep', groupName: 'B', points: 0, nrr: -2.3),
          team: const TeamModel(id: 'nep', name: 'Nepal', shortName: 'NEP', groupName: 'B'),
        ),
      ];

      String resolveGroupName(StandingWithTeam item, int index) {
        final g = item.standing.groupName ?? item.team?.groupName;
        if (g != null && g.trim().isNotEmpty) {
          return g.trim().toUpperCase();
        }
        return index % 2 == 0 ? 'A' : 'B';
      }

      final Map<String, List<StandingWithTeam>> groupedStandings = {};
      for (int i = 0; i < teams.length; i++) {
        final item = teams[i];
        final g = resolveGroupName(item, i);
        groupedStandings.putIfAbsent(g, () => []).add(item);
      }

      for (final entry in groupedStandings.entries) {
        entry.value.sort((a, b) {
          if (b.standing.points != a.standing.points) {
            return b.standing.points.compareTo(a.standing.points);
          }
          if ((b.standing.nrr - a.standing.nrr).abs() > 0.0001) {
            return b.standing.nrr.compareTo(a.standing.nrr);
          }
          return a.standing.position.compareTo(b.standing.position);
        });
      }

      expect(groupedStandings['A']!.length, equals(3));
      expect(groupedStandings['B']!.length, equals(3));

      // No team in Group A is also in Group B
      final groupATeamIds = groupedStandings['A']!.map((e) => e.team?.id).toSet();
      final groupBTeamIds = groupedStandings['B']!.map((e) => e.team?.id).toSet();
      expect(groupATeamIds.intersection(groupBTeamIds), isEmpty);

      // Verify sorting: India (6 pts) is 1st in Group A, Sri Lanka (4 pts) 2nd, Pakistan (2 pts) 3rd
      expect(groupedStandings['A']![0].team!.id, equals('ind'));
      expect(groupedStandings['A']![1].team!.id, equals('sl'));
      expect(groupedStandings['A']![2].team!.id, equals('pak'));

      // Verify sorting: Afghanistan (4 pts, +1.5 NRR) is 1st in Group B over Bangladesh (4 pts, +0.8 NRR)
      expect(groupedStandings['B']![0].team!.id, equals('afg'));
      expect(groupedStandings['B']![1].team!.id, equals('ban'));
      expect(groupedStandings['B']![2].team!.id, equals('nep'));
    });

    test('Dynamic isGroupFormat activates even when tournament object is null/loading', () {
      final teams = [
        StandingWithTeam(
          standing: const StandingModel(id: 's1', teamId: 't1', groupName: 'A'),
        ),
        StandingWithTeam(
          standing: const StandingModel(id: 's2', teamId: 't2', groupName: 'B'),
        ),
      ];

      TournamentModel? tournament; // still loading / null

      final hasGroupedTeams = teams.any((item) =>
          (item.standing.groupName ?? item.team?.groupName)?.trim().isNotEmpty == true);
      final isGroupFormat = (tournament?.isGroupsAndKnockout == true) ||
          (tournament?.groups != null && tournament!.groups!.isNotEmpty) ||
          (tournament?.groupCount != null && tournament!.groupCount! > 1) ||
          hasGroupedTeams;

      expect(hasGroupedTeams, isTrue);
      expect(isGroupFormat, isTrue);
    });

    test('Knockout fixtures and projected pairings resolve correctly from group standings', () {
      final sortedGroupA = [
        StandingWithTeam(
          standing: const StandingModel(id: 's1', teamId: 'ind', points: 6),
          team: const TeamModel(id: 'ind', name: 'India', shortName: 'IND'),
        ),
        StandingWithTeam(
          standing: const StandingModel(id: 's2', teamId: 'sl', points: 4),
          team: const TeamModel(id: 'sl', name: 'Sri Lanka', shortName: 'SL'),
        ),
      ];

      final sortedGroupB = [
        StandingWithTeam(
          standing: const StandingModel(id: 's3', teamId: 'afg', points: 6),
          team: const TeamModel(id: 'afg', name: 'Afghanistan', shortName: 'AFG'),
        ),
        StandingWithTeam(
          standing: const StandingModel(id: 's4', teamId: 'ban', points: 4),
          team: const TeamModel(id: 'ban', name: 'Bangladesh', shortName: 'BAN'),
        ),
      ];

      // Semi-Final 1: Winner Group A (A1) vs Runner-up Group B (B2)
      final sf1TeamA = sortedGroupA[0].teamName;
      final sf1TeamB = sortedGroupB[1].teamName;
      expect(sf1TeamA, equals('India'));
      expect(sf1TeamB, equals('Bangladesh'));

      // Semi-Final 2: Winner Group B (B1) vs Runner-up Group A (A2)
      final sf2TeamA = sortedGroupB[0].teamName;
      final sf2TeamB = sortedGroupA[1].teamName;
      expect(sf2TeamA, equals('Afghanistan'));
      expect(sf2TeamB, equals('Sri Lanka'));
    });

    test('Champion and Runner-Up resolve accurately from completed Grand Final match', () {
      final grandFinal = MatchModel.fromMap('m_final', {
        'matchNumber': 15,
        'stage': 'FINAL',
        'teamAId': 'ind',
        'teamBId': 'afg',
        'status': 'COMPLETED',
        'winningTeamId': 'ind',
        'resultText': 'India won by 18 runs',
      });

      // Resolved Champion
      final championId = grandFinal.winningTeamId;
      expect(championId, equals('ind'));

      // Resolved Runner-Up (the other finalist)
      final runnerUpId = grandFinal.teamAId == championId ? grandFinal.teamBId : grandFinal.teamAId;
      expect(runnerUpId, equals('afg'));
      expect(grandFinal.resultText, equals('India won by 18 runs'));
    });
  });
}

