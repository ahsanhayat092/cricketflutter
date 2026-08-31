import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../scoring/models/team_model.dart';
import '../models/standing.dart';

import '../../match_management/providers/tournament_providers.dart';

/// StreamProvider for live standings joined with team metadata strictly from Cloud Firestore
final standingsStreamProvider = StreamProvider<List<StandingWithTeam>>((ref) {
  final firestore = FirebaseFirestore.instance;
  final activeTournamentId = ref.watch(activeTournamentIdProvider);
  final service = ref.watch(scoringServiceProvider);

  return firestore
      .collection('standings')
      .snapshots()
      .asyncMap((standingsSnap) async {
    // 1. Get the authoritative list of participating teams for this tournament
    final List<TeamModel> tournamentTeams = await service.getTeams(tournamentId: activeTournamentId);
    final Map<String, TeamModel> teamsMap = {
      for (final team in tournamentTeams) team.id: team,
    };
    final Set<String> validTeamIds = teamsMap.keys.toSet();

    // 2. Filter standings strictly to documents belonging to actual tournament teams
    final List<StandingWithTeam> list = [];
    final Set<String> processedTeamIds = {};

    for (final doc in standingsSnap.docs) {
      final standing = StandingModel.fromFirestore(doc);

      // Check tournament scoping
      final isMatchingTournament = activeTournamentId == 'main'
          ? (standing.tournamentId.isEmpty || standing.tournamentId == 'main')
          : (standing.tournamentId == activeTournamentId);

      if (!isMatchingTournament) continue;

      // CRITICAL: Exclude orphan/phantom standing records not in this tournament's team roster
      final matchedTeamId = validTeamIds.contains(standing.teamId)
          ? standing.teamId
          : (validTeamIds.contains(standing.id) ? standing.id : null);

      if (matchedTeamId == null) {
        // This is a phantom/orphan standing doc for a non-participating team — discard it!
        continue;
      }

      final team = teamsMap[matchedTeamId];
      if (team != null) {
        list.add(StandingWithTeam(
          standing: standing,
          team: team,
        ));
        processedTeamIds.add(matchedTeamId);
      }
    }

    // 3. For any participating tournament team that does not have a standings doc yet, create default 0-0 entry
    for (final team in tournamentTeams) {
      if (!processedTeamIds.contains(team.id)) {
        list.add(StandingWithTeam(
          standing: StandingModel(
            id: team.id,
            tournamentId: activeTournamentId,
            teamId: team.id,
            position: list.length + 1,
          ),
          team: team,
        ));
      }
    }

    // Sort strictly by position ASC (1, 2, 3...) or by Points then NRR if position is equal
    list.sort((a, b) {
      if (a.standing.position != b.standing.position) {
        return a.standing.position.compareTo(b.standing.position);
      }
      if (b.standing.points != a.standing.points) {
        return b.standing.points.compareTo(a.standing.points);
      }
      return b.standing.nrr.compareTo(a.standing.nrr);
    });

    return list;
  });
});

// Backward compatibility alias for any existing consumers
final standingsProvider = Provider<List<TeamStanding>>((ref) {
  final asyncVal = ref.watch(standingsStreamProvider);
  final list = asyncVal.value ?? [];
  return list.map((item) {
    return TeamStanding(
      teamId: item.standing.teamId,
      teamName: item.teamName,
      shortName: item.shortName,
      logoUrl: item.logoUrl,
      played: item.standing.played,
      won: item.standing.won,
      lost: item.standing.lost,
      tied: item.standing.tied,
      noResult: item.standing.noResult,
      points: item.standing.points,
      netRunRate: item.standing.nrr,
    );
  }).toList();
});
