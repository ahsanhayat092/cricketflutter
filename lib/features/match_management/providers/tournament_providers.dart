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

final scoringServiceProvider = Provider<FirebaseScoringService>((ref) {
  return FirebaseScoringService();
});

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return FirebasePlayerRepository();
});

final scoringSyncServiceProvider = Provider<ScoringSyncService>((ref) {
  return ScoringSyncService();
});

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

/// Realtime Matches Stream from Firestore (/matches)
final matchesProvider = StreamProvider<List<MatchModel>>((ref) {
  final service = ref.watch(scoringServiceProvider);
  return service.getMatchesStream();
});

/// Realtime Single Match Stream from Firestore (/matches/{matchId})
final singleMatchProvider = StreamProvider.family<MatchModel?, String>((ref, matchId) {
  final service = ref.watch(scoringServiceProvider);
  return service.getMatchStream(matchId);
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
