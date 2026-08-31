import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
import '../../auth/models/app_user.dart';
import '../../auth/models/tournament_member_model.dart';
import '../../auth/services/scorer_security_service.dart';
import '../../auth/providers/auth_provider.dart';
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

final scorerSecurityServiceProvider = Provider<ScorerSecurityService>((ref) {
  return ScorerSecurityService();
});

/// StateNotifier to manage and persist Unlocked Tournaments locally
class UnlockedTournamentsNotifier extends StateNotifier<Set<String>> {
  final ScorerSecurityService _securityService;

  UnlockedTournamentsNotifier(this._securityService) : super({}) {
    _loadUnlocked();
  }

  Future<void> _loadUnlocked() async {
    final unlocked = await _securityService.getUnlockedTournamentIds();
    state = unlocked;
  }

  Future<void> unlockTournament(String tournamentId) async {
    await _securityService.unlockTournament(tournamentId);
    state = {...state, tournamentId};
  }

  Future<void> lockTournament(String tournamentId) async {
    await _securityService.lockTournament(tournamentId);
    final updated = Set<String>.from(state)..remove(tournamentId);
    state = updated;
  }

  Future<void> clearAll() async {
    await _securityService.clearAllUnlocked();
    state = {};
  }
}

final unlockedTournamentsProvider =
    StateNotifierProvider<UnlockedTournamentsNotifier, Set<String>>((ref) {
  final securityService = ref.watch(scorerSecurityServiceProvider);
  return UnlockedTournamentsNotifier(securityService);
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

/// Active Tournament ID in App Context (default: 'main' WASA Premier League)
final activeTournamentIdProvider = StateProvider<String>((ref) => 'main');

/// Realtime Stream of All Tournaments on SaaS Platform
final allTournamentsProvider = StreamProvider<List<TournamentModel>>((ref) {
  final service = ref.watch(scoringServiceProvider);
  return service.getAllTournamentsStream();
});

/// Realtime Stream of Active Tournament Document
final activeTournamentProvider = StreamProvider<TournamentModel?>((ref) {
  final service = ref.watch(scoringServiceProvider);
  final activeId = ref.watch(activeTournamentIdProvider);
  return service.getTournamentStream(tournamentId: activeId);
});

/// Ground Scorer Session Unlocked State (tournamentId -> isUnlocked via 4-Digit PIN)
final scorerPinSessionProvider = StateProvider<Map<String, bool>>((ref) => {});

/// Realtime Stream of Members for Active Tournament
final activeTournamentMembersProvider = StreamProvider<List<TournamentMemberModel>>((ref) {
  final service = ref.watch(scoringServiceProvider);
  final activeId = ref.watch(activeTournamentIdProvider);
  return service.getTournamentMembersStream(activeId);
});

/// Realtime Stream of Tournament Memberships for Logged-In User Email
final userTournamentMembershipsProvider = StreamProvider.family<List<TournamentMemberModel>, String>((ref, userEmail) {
  final service = ref.watch(scoringServiceProvider);
  return service.getUserMembershipsStream(userEmail);
});

/// Helper to scope tournaments strictly to assigned, owned, or PIN-unlocked tournaments
List<TournamentModel> getUserScorerTournaments({
  required List<TournamentModel> allTournaments,
  required AppUser user,
  required List<TournamentMemberModel> memberships,
  required Set<String> pinUnlockedTournamentIds,
}) {
  if (user.isPlatformAdmin) return allTournaments;

  final cleanEmail = user.email.toLowerCase().trim();
  final allowedMemberTournamentIds = memberships
      .where((m) => m.canScore)
      .map((m) => m.tournamentId)
      .toSet();

  return allTournaments.where((t) {
    // 1. Unlocked via 4-digit PIN in session / storage
    if (pinUnlockedTournamentIds.contains(t.id)) return true;

    // 2. Tournament Creator / Owner by ID or Email
    if (user.uid.isNotEmpty && user.uid != 'guest' && t.ownerId != null && t.ownerId == user.uid) {
      return true;
    }
    if (cleanEmail.isNotEmpty && t.ownerEmail != null && t.ownerEmail!.toLowerCase().trim() == cleanEmail) {
      return true;
    }

    // 3. Explicitly assigned membership (OWNER, ADMIN, SCORER)
    if (allowedMemberTournamentIds.contains(t.id)) {
      return true;
    }

    return false;
  }).toList();
}

/// Evaluates whether current user has tournament administration access (Owner, Co-Admin, Platform Admin)
final isTournamentAdminProvider = Provider.family<bool, String>((ref, tournamentId) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser.isPlatformAdmin) return true;

  final allTournamentsAsync = ref.watch(allTournamentsProvider);
  final allTournaments = allTournamentsAsync.value ?? [];
  final tournament = allTournaments.cast<TournamentModel?>().firstWhere(
        (t) => t?.id == tournamentId,
        orElse: () => null,
      );

  final cleanEmail = currentUser.email.toLowerCase().trim();
  if (tournament != null) {
    if (currentUser.uid.isNotEmpty && currentUser.uid != 'guest' && tournament.ownerId != null && tournament.ownerId == currentUser.uid) {
      return true;
    }
    if (cleanEmail.isNotEmpty && tournament.ownerEmail != null && tournament.ownerEmail!.toLowerCase().trim() == cleanEmail) {
      return true;
    }
  }

  if (cleanEmail.isNotEmpty) {
    final membershipsAsync = ref.watch(userTournamentMembershipsProvider(cleanEmail));
    final memberships = membershipsAsync.value ?? [];
    if (memberships.any((m) => m.tournamentId == tournamentId && m.canManage)) {
      return true;
    }
  }

  return false;
});

/// Evaluates whether current user has live scoring access for a specific tournament
final isTournamentScorableProvider = Provider.family<bool, String>((ref, tournamentId) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser.isPlatformAdmin) return true;

  final unlockedSet = ref.watch(unlockedTournamentsProvider);
  if (unlockedSet.contains(tournamentId)) return true;

  final allTournamentsAsync = ref.watch(allTournamentsProvider);
  final allTournaments = allTournamentsAsync.value ?? [];
  final tournament = allTournaments.cast<TournamentModel?>().firstWhere(
        (t) => t?.id == tournamentId,
        orElse: () => null,
      );

  final cleanEmail = currentUser.email.toLowerCase().trim();
  if (tournament != null) {
    if (currentUser.uid.isNotEmpty && currentUser.uid != 'guest' && tournament.ownerId != null && tournament.ownerId == currentUser.uid) {
      return true;
    }
    if (cleanEmail.isNotEmpty && tournament.ownerEmail != null && tournament.ownerEmail!.toLowerCase().trim() == cleanEmail) {
      return true;
    }
  }

  if (cleanEmail.isNotEmpty) {
    final membershipsAsync = ref.watch(userTournamentMembershipsProvider(cleanEmail));
    final memberships = membershipsAsync.value ?? [];
    if (memberships.any((m) => m.tournamentId == tournamentId && m.canScore)) {
      return true;
    }
  }

  return false;
});

/// List of Tournaments that the user is authorized to score
final scorableTournamentsProvider = Provider<List<TournamentModel>>((ref) {
  final allTournamentsAsync = ref.watch(allTournamentsProvider);
  final allTournaments = allTournamentsAsync.value ?? [];
  final currentUser = ref.watch(currentUserProvider);
  final unlockedSet = ref.watch(unlockedTournamentsProvider);
  final cleanEmail = currentUser.email.toLowerCase().trim();

  final membershipsAsync = cleanEmail.isNotEmpty
      ? ref.watch(userTournamentMembershipsProvider(cleanEmail))
      : const AsyncValue.data(<TournamentMemberModel>[]);
  final memberships = membershipsAsync.value ?? [];

  return getUserScorerTournaments(
    allTournaments: allTournaments,
    user: currentUser,
    memberships: memberships,
    pinUnlockedTournamentIds: unlockedSet,
  );
});

/// Realtime Teams Stream parameterized by Tournament ID
final tournamentTeamsProvider = StreamProvider.family<List<TeamModel>, String>((ref, tournamentId) {
  final service = ref.watch(scoringServiceProvider);
  final activeId = ref.watch(activeTournamentIdProvider);
  final targetId = tournamentId.isNotEmpty ? tournamentId : activeId;
  return service.getTeamsStream(tournamentId: targetId);
});

/// Realtime Teams Stream for Active Tournament (/teams where tournamentId == activeId)
final teamsProvider = StreamProvider<List<TeamModel>>((ref) {
  final activeId = ref.watch(activeTournamentIdProvider);
  final service = ref.watch(scoringServiceProvider);
  return service.getTeamsStream(tournamentId: activeId);
});

/// Realtime Single Team Stream directly from /teams/{teamId} (Direct Fetch Fallback)
final singleTeamStreamProvider = StreamProvider.family<TeamModel?, String>((ref, teamId) {
  if (teamId.isEmpty) return Stream.value(null);
  final service = ref.watch(scoringServiceProvider);
  return service.getTeamStream(teamId);
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

/// Realtime Matches Stream for Active Tournament with Playoff and Finalist Hydration
final matchesProvider = StreamProvider<List<MatchModel>>((ref) {
  final service = ref.watch(scoringServiceProvider);
  final activeId = ref.watch(activeTournamentIdProvider);
  final standingsAsync = ref.watch(standingsStreamProvider);
  final standings = standingsAsync.value ?? [];

  return service.getMatchesStream(tournamentId: activeId).map((matches) {
    return matches.map((m) => hydrateMatchWithStandings(m, standings, allMatches: matches)).toList();
  });
});

/// Realtime Single Match Stream from Firestore (/matches/{matchId}) with Playoff and Finalist Hydration
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

// Helper to get team by ID (with fallback to direct stream)
final teamByIdProvider = Provider.family<TeamModel?, String>((ref, teamId) {
  final teamsAsync = ref.watch(teamsProvider);
  final allTeams = teamsAsync.value ?? [];
  try {
    return allTeams.firstWhere((t) => t.id == teamId);
  } catch (_) {
    final direct = ref.watch(singleTeamStreamProvider(teamId)).value;
    return direct;
  }
});
