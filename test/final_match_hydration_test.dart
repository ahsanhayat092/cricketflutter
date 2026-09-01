import 'package:flutter_test/flutter_test.dart';
import 'package:wpl_cricket_app/features/scoring/models/match_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/team_model.dart';
import 'package:wpl_cricket_app/features/standings/models/standing.dart';
import 'package:wpl_cricket_app/features/match_management/providers/tournament_providers.dart';

void main() {
  group('MatchStage Enum & Serialization Tests', () {
    test('MatchStage converts to/from Firestore string correctly', () {
      expect(MatchStage.league.toFirestoreString(), 'LEAGUE');
      expect(MatchStage.playoff.toFirestoreString(), 'PLAYOFF');
      expect(MatchStage.finalMatch.toFirestoreString(), 'FINAL');

      expect(MatchStageX.fromFirestoreString('LEAGUE'), MatchStage.league);
      expect(MatchStageX.fromFirestoreString('PLAYOFF'), MatchStage.playoff);
      expect(MatchStageX.fromFirestoreString('FINAL'), MatchStage.finalMatch);
      expect(MatchStageX.fromFirestoreString(null), MatchStage.league);
    });

    test('MatchStage displayName matches requirements', () {
      expect(MatchStage.finalMatch.displayName, '🏆 Grand Final');
      expect(MatchStage.playoff.displayName, '⚔️ Playoff (Rank 2 vs 3)');
      expect(MatchStage.league.displayName, 'League Match');
    });

    test('MatchModel stage helper getters work correctly', () {
      const playoff = MatchModel(id: 'm1', matchNumber: 10, stage: 'PLAYOFF', teamAId: 'a', teamBId: 'b', date: '2026-08-25');
      expect(playoff.isPlayoff, isTrue);
      expect(playoff.isFinal, isFalse);
      expect(playoff.stageDisplayName, '⚔️ Playoff (Rank 2 vs 3)');

      const grandFinal = MatchModel(id: 'm2', matchNumber: 11, stage: 'FINAL', teamAId: 'a', teamBId: 'b', date: '2026-08-25');
      expect(grandFinal.isPlayoff, isFalse);
      expect(grandFinal.isFinal, isTrue);
      expect(grandFinal.stageDisplayName, '🏆 Grand Final');
    });
  });

  group('Playoff & Grand Final Match Hydration Tests', () {
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

    test('Hydrates Playoff match with Rank 2 and Rank 3 teams', () {
      const playoffMatchTbd = MatchModel(
        id: 'match_10',
        matchNumber: 10,
        stage: 'PLAYOFF',
        teamAId: 'rank_2',
        teamBId: 'rank_3',
        date: '2026-08-25',
        status: 'UPCOMING',
      );

      final hydrated = hydrateMatchWithStandings(playoffMatchTbd, standings);

      expect(hydrated.teamAId, equals('team_tw')); // Rank 2
      expect(hydrated.teamBId, equals('team_bb')); // Rank 3
      expect(hydrated.isPlayoff, isTrue);
    });

    test('Hydrates Grand Final match with Rank 1 directly and Winner of Playoff', () {
      const completedPlayoff = MatchModel(
        id: 'match_10',
        matchNumber: 10,
        stage: 'PLAYOFF',
        teamAId: 'team_tw',
        teamBId: 'team_bb',
        winningTeamId: 'team_bb', // Playoff winner
        status: 'COMPLETED',
        date: '2026-08-25',
      );

      const finalMatchTbd = MatchModel(
        id: 'match_11',
        matchNumber: 11,
        stage: 'FINAL',
        teamAId: 'rank_1',
        teamBId: 'tbd',
        date: '2026-08-25',
        status: 'UPCOMING',
      );

      final hydrated = hydrateMatchWithStandings(
        finalMatchTbd,
        standings,
        allMatches: [completedPlayoff, finalMatchTbd],
      );

      expect(hydrated.teamAId, equals('team_rs')); // Rank 1 directly qualified
      expect(hydrated.teamBId, equals('team_bb')); // Winner of Playoff
      expect(hydrated.isFinal, isTrue);
    });

    test('Hydrates DIRECT_TOP2 Grand Final with Rank 1 and Rank 2 teams', () {
      const finalMatchTbd = MatchModel(
        id: 'match_final_direct',
        matchNumber: 15,
        stage: 'FINAL',
        teamAId: 'rank_1',
        teamBId: 'rank_2',
        date: '2026-08-25',
        status: 'UPCOMING',
      );

      final hydrated = hydrateMatchWithStandings(
        finalMatchTbd,
        standings,
        playoffFormat: 'DIRECT_TOP2',
      );

      expect(hydrated.teamAId, equals('team_rs')); // Rank 1
      expect(hydrated.teamBId, equals('team_tw')); // Rank 2
      expect(hydrated.isFinal, isTrue);
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
  });
}
