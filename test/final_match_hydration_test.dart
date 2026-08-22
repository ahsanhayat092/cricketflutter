import 'package:flutter_test/flutter_test.dart';
import 'package:wpl_cricket_app/features/scoring/models/match_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/team_model.dart';
import 'package:wpl_cricket_app/features/standings/models/standing.dart';
import 'package:wpl_cricket_app/features/match_management/providers/tournament_providers.dart';

void main() {
  group('Grand Final Match Hydration Tests', () {
    const team1 = TeamModel(id: 'team_rs', name: 'Royal Strikers', shortName: 'RS');
    const team2 = TeamModel(id: 'team_tw', name: 'Titan Warriors', shortName: 'TW');
    const team3 = TeamModel(id: 'team_bb', name: 'Blaster Bulls', shortName: 'BB');

    final standings = [
      StandingWithTeam(
        standing: const StandingModel(
          id: 'team_rs',
          tournamentId: 'main',
          teamId: 'team_rs',
          position: 1,
          played: 4,
          won: 4,
          points: 8,
          nrr: 1.85,
        ),
        team: team1,
      ),
      StandingWithTeam(
        standing: const StandingModel(
          id: 'team_tw',
          tournamentId: 'main',
          teamId: 'team_tw',
          position: 2,
          played: 4,
          won: 3,
          points: 6,
          nrr: 0.95,
        ),
        team: team2,
      ),
      StandingWithTeam(
        standing: const StandingModel(
          id: 'team_bb',
          tournamentId: 'main',
          teamId: 'team_bb',
          position: 3,
          played: 4,
          won: 2,
          points: 4,
          nrr: -0.40,
        ),
        team: team3,
      ),
    ];

    test('Hydrates Final match with Rank 1 and Rank 2 when team IDs are unset or placeholders', () {
      const finalMatchTbd = MatchModel(
        id: 'match_11',
        matchNumber: 11,
        stage: 'FINAL',
        teamAId: 'rank_1',
        teamBId: 'rank_2',
        date: '2026-08-22',
        status: 'UPCOMING',
      );

      final hydrated = hydrateMatchWithStandings(finalMatchTbd, standings);

      expect(hydrated.teamAId, equals('team_rs'));
      expect(hydrated.teamBId, equals('team_tw'));
      expect(hydrated.stage, equals('FINAL'));
    });

    test('Hydrates Final match when team IDs are empty strings', () {
      const finalMatchEmpty = MatchModel(
        id: 'match_final',
        matchNumber: 10,
        stage: 'FINAL',
        teamAId: '',
        teamBId: '',
        date: '2026-08-22',
        status: 'UPCOMING',
      );

      final hydrated = hydrateMatchWithStandings(finalMatchEmpty, standings);

      expect(hydrated.teamAId, equals('team_rs'));
      expect(hydrated.teamBId, equals('team_tw'));
    });

    test('Leaves League matches untouched even if standings are available', () {
      const leagueMatch = MatchModel(
        id: 'match_1',
        matchNumber: 1,
        stage: 'LEAGUE',
        teamAId: 'team_bb',
        teamBId: 'team_tw',
        date: '2026-08-22',
        status: 'UPCOMING',
      );

      final result = hydrateMatchWithStandings(leagueMatch, standings);

      expect(result.teamAId, equals('team_bb'));
      expect(result.teamBId, equals('team_tw'));
    });

    test('Preserves already set explicit teams on Final match', () {
      const finalMatchExplicit = MatchModel(
        id: 'match_11',
        matchNumber: 11,
        stage: 'FINAL',
        teamAId: 'team_rs',
        teamBId: 'team_bb',
        date: '2026-08-22',
        status: 'UPCOMING',
      );

      final result = hydrateMatchWithStandings(finalMatchExplicit, standings);

      expect(result.teamAId, equals('team_rs'));
      expect(result.teamBId, equals('team_bb'));
    });
  });
}
