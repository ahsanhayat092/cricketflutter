import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../scoring/models/team_model.dart';
import '../models/standing.dart';

import '../../match_management/providers/tournament_providers.dart';

/// StreamProvider for live standings joined with team metadata strictly from Cloud Firestore
final standingsStreamProvider = StreamProvider<List<StandingWithTeam>>((ref) {
  final firestore = FirebaseFirestore.instance;
  final activeTournamentId = ref.watch(activeTournamentIdProvider);

  return firestore
      .collection('standings')
      .snapshots()
      .asyncMap((standingsSnap) async {
    final teamsSnap = await firestore
        .collection('teams')
        .get();

    final teamsMap = {
      for (var doc in teamsSnap.docs) doc.id: TeamModel.fromFirestore(doc)
    };

    final list = standingsSnap.docs
        .map((doc) => StandingModel.fromFirestore(doc))
        .where((s) {
          if (activeTournamentId == 'main') {
            return s.tournamentId.isEmpty || s.tournamentId == 'main';
          }
          return s.tournamentId == activeTournamentId;
        })
        .map((standing) {
          return StandingWithTeam(
            standing: standing,
            team: teamsMap[standing.teamId],
          );
        })
        .toList();

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
