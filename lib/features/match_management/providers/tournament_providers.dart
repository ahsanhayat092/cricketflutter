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

/// Helper to dynamically hydrate Final match teams from Standings (Rank 1 & Rank 2)
MatchModel hydrateMatchWithStandings(MatchModel match, List<StandingWithTeam> standings) {
  final isFinal = match.stage.toUpperCase() == 'FINAL' || match.matchNumber >= 10;
  if (!isFinal || standings.length < 2) return match;

  final rank1TeamId = standings[0].standing.teamId;
  final rank2TeamId = standings[1].standing.teamId;

  final isTeamAUnset = match.teamAId.isEmpty ||
      match.teamAId.toLowerCase() == 'rank_1' ||
      match.teamAId.toLowerCase() == 'rank1' ||
      match.teamAId.toLowerCase() == 'tbd' ||
      match.teamAId.toLowerCase() == 'team a';

  final isTeamBUnset = match.teamBId.isEmpty ||
      match.teamBId.toLowerCase() == 'rank_2' ||
      match.teamBId.toLowerCase() == 'rank2' ||
      match.teamBId.toLowerCase() == 'tbd' ||
      match.teamBId.toLowerCase() == 'team b';

  if (isTeamAUnset || isTeamBUnset) {
    return match.copyWith(
      teamAId: isTeamAUnset ? rank1TeamId : match.teamAId,
      teamBId: isTeamBUnset ? rank2TeamId : match.teamBId,
      stage: 'FINAL',
    );
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

/// Realtime Matches Stream from Firestore (/matches) with Finalist Hydration
final matchesProvider = StreamProvider<List<MatchModel>>((ref) {
  final service = ref.watch(scoringServiceProvider);
  final standingsAsync = ref.watch(standingsStreamProvider);
  final standings = standingsAsync.value ?? [];

  return service.getMatchesStream().map((matches) {
    return matches.map((m) => hydrateMatchWithStandings(m, standings)).toList();
  });
});

/// Realtime Single Match Stream from Firestore (/matches/{matchId}) with Finalist Hydration
final singleMatchProvider = StreamProvider.family<MatchModel?, String>((ref, matchId) {
  final service = ref.watch(scoringServiceProvider);
  final standingsAsync = ref.watch(standingsStreamProvider);
  final standings = standingsAsync.value ?? [];

  return service.getMatchStream(matchId).map((match) {
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
