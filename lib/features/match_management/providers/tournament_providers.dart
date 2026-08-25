import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../scoring/data/firebase_scoring_service.dart';
import '../../scoring/data/player_repository.dart';
import '../../scoring/data/scoring_sync_service.dart';
import '../../scoring/models/team_model.dart';
import '../../scoring/models/player_model.dart';
import '../../scoring/models/match_model.dart';
import '../../scoring/models/tournament_model.dart';
import '../../scoring/models/innings_model.dart';
import '../../scoring/models/batting_score.dart';
import '../../scoring/models/bowling_score.dart';
import '../../standings/providers/standings_provider.dart';
import '../../standings/models/standing.dart';

final scoringServiceProvider = Provider<FirebaseScoringService>((ref) {
  return FirebaseScoringService();
});

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return FirebasePlayerRepository();
});

final scoringSyncServiceProvider = Provider<ScoringSyncService>((ref) {
  return ScoringSyncService();
});

/// Helper to dynamically hydrate Playoff (Rank 2 vs Rank 3) and Final (Rank 1 vs Winner of Playoff / Rank 2)
MatchModel hydrateMatchWithStandings(
  MatchModel match,
  List<StandingWithTeam> standings, {
  List<MatchModel>? allMatches,
}) {
  final stageEnum = MatchStageX.fromFirestoreString(match.stage);

  // 1. PLAYOFF MATCH: Rank 2 vs Rank 3
  if (stageEnum == MatchStage.playoff) {
    if (standings.length < 3) return match;

    final rank2TeamId = standings[1].standing.teamId;
    final rank3TeamId = standings[2].standing.teamId;

    final isTeamAUnset = match.teamAId.isEmpty ||
        match.teamAId.toLowerCase().contains('rank_2') ||
        match.teamAId.toLowerCase().contains('rank2') ||
        match.teamAId.toLowerCase() == 'tbd' ||
        match.teamAId.toLowerCase() == 'team a';

    final isTeamBUnset = match.teamBId.isEmpty ||
        match.teamBId.toLowerCase().contains('rank_3') ||
        match.teamBId.toLowerCase().contains('rank3') ||
        match.teamBId.toLowerCase() == 'tbd' ||
        match.teamBId.toLowerCase() == 'team b';

    if (isTeamAUnset || isTeamBUnset) {
      return match.copyWith(
        teamAId: isTeamAUnset ? rank2TeamId : match.teamAId,
        teamBId: isTeamBUnset ? rank3TeamId : match.teamBId,
        stage: 'PLAYOFF',
      );
    }
    return match;
  }

  // 2. GRAND FINAL MATCH: Rank 1 vs Winner of Playoff (or Rank 2 if direct final)
  if (stageEnum == MatchStage.finalMatch) {
    if (standings.isEmpty) return match;

    final rank1TeamId = standings[0].standing.teamId;

    // Check if a playoff match exists and is completed
    String? playoffWinnerId;
    if (allMatches != null) {
      final playoffMatches = allMatches.where((m) =>
          m.id != match.id &&
          (MatchStageX.fromFirestoreString(m.stage) == MatchStage.playoff || m.matchNumber == 10));
      if (playoffMatches.isNotEmpty) {
        final playoff = playoffMatches.first;
        if (playoff.isCompleted && playoff.winningTeamId != null && playoff.winningTeamId!.isNotEmpty) {
          playoffWinnerId = playoff.winningTeamId;
        }
      }
    }

    final isTeamAUnset = match.teamAId.isEmpty ||
        match.teamAId.toLowerCase().contains('rank_1') ||
        match.teamAId.toLowerCase().contains('rank1') ||
        match.teamAId.toLowerCase() == 'tbd' ||
        match.teamAId.toLowerCase() == 'team a';

    final isTeamBUnset = match.teamBId.isEmpty ||
        match.teamBId.toLowerCase().contains('rank_2') ||
        match.teamBId.toLowerCase().contains('rank2') ||
        match.teamBId.toLowerCase().contains('playoff') ||
        match.teamBId.toLowerCase() == 'tbd' ||
        match.teamBId.toLowerCase() == 'team b';

    String? targetTeamB = match.teamBId;
    if (isTeamBUnset) {
      if (playoffWinnerId != null) {
        targetTeamB = playoffWinnerId;
      } else if (standings.length >= 2 &&
          (allMatches == null || !allMatches.any((m) => MatchStageX.fromFirestoreString(m.stage) == MatchStage.playoff))) {
        targetTeamB = standings[1].standing.teamId;
      }
    }

    if (isTeamAUnset || (isTeamBUnset && targetTeamB != match.teamBId)) {
      return match.copyWith(
        teamAId: isTeamAUnset ? rank1TeamId : match.teamAId,
        teamBId: targetTeamB,
        stage: 'FINAL',
      );
    }
    return match;
  }

  return match;
}

/// Realtime Tournament Singleton Stream from Firestore (/tournaments/main)
final tournamentProvider = StreamProvider<TournamentModel?>((ref) {
  final service = ref.watch(scoringServiceProvider);
  return service.getTournamentStream();
});

/// Realtime Teams Stream from Firestore (/teams)
final teamsProvider = StreamProvider<List<TeamModel>>((ref) {
  final service = ref.watch(scoringServiceProvider);
  return service.getTeamsStream();
});

/// Realtime Players Stream from Firestore (/players)
final playersProvider = StreamProvider<List<PlayerModel>>((ref) {
  final repo = ref.watch(playerRepositoryProvider);
  return repo.getAllPlayersStream();
});

/// Realtime Stream for Players of a Specific Team (/players where teamId == teamId)
final teamPlayersStreamProvider = StreamProvider.family<List<PlayerModel>, String>((ref, teamId) {
  final repo = ref.watch(playerRepositoryProvider);
  return repo.getPlayersByTeamStream(teamId);
});

/// Realtime Matches Stream from Firestore (/matches) with Playoff and Finalist Hydration
final matchesProvider = StreamProvider<List<MatchModel>>((ref) {
  final service = ref.watch(scoringServiceProvider);
  final standingsAsync = ref.watch(standingsStreamProvider);
  final standings = standingsAsync.value ?? [];

  return service.getMatchesStream().map((matches) {
    return matches.map((m) => hydrateMatchWithStandings(m, standings, allMatches: matches)).toList();
  });
});

/// Realtime Single Match Stream from Firestore (/matches/{matchId}) with Playoff and Finalist Hydration
final singleMatchProvider = StreamProvider.family<MatchModel?, String>((ref, matchId) {
  final service = ref.watch(scoringServiceProvider);
  final standingsAsync = ref.watch(standingsStreamProvider);
  final standings = standingsAsync.value ?? [];

  return service.getMatchStream(matchId).map((match) {
    if (match == null) return null;
    return hydrateMatchWithStandings(match, standings);
  });
});

/// Realtime Innings List Stream for a Match (/innings where matchId == matchId)
final matchInningsProvider = StreamProvider.family<List<InningsModel>, String>((ref, matchId) {
  final service = ref.watch(scoringServiceProvider);
  return service.getInningsForMatchStream(matchId);
});

/// Realtime Batting Scores Stream for an Innings (/battingScores where inningsId == inningsId)
final battingScoresProvider = StreamProvider.family<List<BattingScore>, String>((ref, inningsId) {
  final service = ref.watch(scoringServiceProvider);
  return service.getBattingScoresStream(inningsId);
});

/// Realtime Bowling Scores Stream for an Innings (/bowlingScores where inningsId == inningsId)
final bowlingScoresProvider = StreamProvider.family<List<BowlingScore>, String>((ref, inningsId) {
  final service = ref.watch(scoringServiceProvider);
  return service.getBowlingScoresStream(inningsId);
});

// Helper selector to get players by team ID
final playersByTeamProvider = Provider.family<List<PlayerModel>, String>((ref, teamId) {
  final playersAsync = ref.watch(teamPlayersStreamProvider(teamId));
  return playersAsync.value ?? [];
});

// Helper to get team by ID
final teamByIdProvider = Provider.family<TeamModel?, String>((ref, teamId) {
  final teamsAsync = ref.watch(teamsProvider);
  final allTeams = teamsAsync.value ?? [];
  try {
    return allTeams.firstWhere((t) => t.id == teamId);
  } catch (_) {
    return null;
  }
});
