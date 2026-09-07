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
    final Map<String, TeamModel> teamsById = {
      for (final team in tournamentTeams) team.id: team,
    };
    final Map<String, TeamModel> teamsByName = {
      for (final team in tournamentTeams)
        if (team.name.trim().isNotEmpty) team.name.trim().toLowerCase(): team,
    };

    // 2. Filter standings strictly to documents belonging to actual tournament teams
    final List<StandingWithTeam> list = [];
    final Set<String> processedTeamIds = {};
    final Set<String> processedTeamNames = {};

    for (final doc in standingsSnap.docs) {
      final standing = StandingModel.fromFirestore(doc);

      // Check tournament scoping
      final isMatchingTournament = activeTournamentId == 'main'
          ? (standing.tournamentId.isEmpty || standing.tournamentId == 'main')
          : (standing.tournamentId == activeTournamentId);

      if (!isMatchingTournament) continue;

      // Match to tournament team by teamId, doc id, or team name
      final standingTeamName = standing.teamName?.trim().toLowerCase();
      final team = teamsById[standing.teamId] ??
                   teamsById[standing.id] ??
                   (standingTeamName != null && standingTeamName.isNotEmpty ? teamsByName[standingTeamName] : null);

      if (team == null) {
        // Exclude orphan/phantom standing records not in this tournament's team roster
        continue;
      }

      final cleanTeamName = team.name.trim().toLowerCase();
      if (processedTeamIds.contains(team.id) ||
          (cleanTeamName.isNotEmpty && processedTeamNames.contains(cleanTeamName))) {
        // Already processed this team! Avoid duplicate row in points table
        continue;
      }

      final effectiveGroup = (standing.groupName != null && standing.groupName!.isNotEmpty)
          ? standing.groupName
          : (team.groupName.isNotEmpty ? team.groupName : null);

      list.add(StandingWithTeam(
        standing: standing.copyWith(
          teamId: team.id,
          groupName: effectiveGroup,
        ),
        team: team,
      ));
      processedTeamIds.add(team.id);
      if (cleanTeamName.isNotEmpty) {
        processedTeamNames.add(cleanTeamName);
      }
    }

    // 3. For any participating tournament team that does not have a standings doc yet, create default 0-0 entry
    for (final team in tournamentTeams) {
      final cleanTeamName = team.name.trim().toLowerCase();
      if (!processedTeamIds.contains(team.id) &&
          (cleanTeamName.isEmpty || !processedTeamNames.contains(cleanTeamName))) {
        list.add(StandingWithTeam(
          standing: StandingModel(
            id: team.id,
            tournamentId: activeTournamentId,
            teamId: team.id,
            groupName: team.groupName.isNotEmpty ? team.groupName : null,
            position: list.length + 1,
          ),
          team: team,
        ));
        processedTeamIds.add(team.id);
        if (cleanTeamName.isNotEmpty) {
          processedTeamNames.add(cleanTeamName);
        }
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
