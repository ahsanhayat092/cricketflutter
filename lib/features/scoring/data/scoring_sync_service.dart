import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../models/match_model.dart';
import '../models/innings_model.dart';
import '../models/batting_score.dart';
import '../models/bowling_score.dart';
import '../../standings/models/standing.dart';

class ScoringSyncService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  ScoringSyncService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _customFirestore = firestore,
        _customAuth = auth;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  /// Ensure user session is retained before executing Firestore writes
  Future<void> ensureAuthenticated() async {
    if (_auth.currentUser != null) {
      debugPrint('[ScoringSyncService] Active authenticated session retained: ${_auth.currentUser?.email ?? _auth.currentUser?.uid}');
    }
  }

  /// 1. Start Match: Updates match lineup, toss, and creates 1st Innings atomically
  Future<void> startMatch({
    required String matchId,
    String? tournamentId,
    String? teamAId,
    String? teamBId,
    required List<String> teamAPlayingVI,
    required String? teamAReserveId,
    required List<String> teamBPlayingVI,
    required String? teamBReserveId,
    required String tossWinnerId,
    required String tossDecision,
    required String battingTeamId,
    required String bowlingTeamId,
    required String strikerId,
    required String nonStrikerId,
    required String bowlerId,
  }) async {
    await ensureAuthenticated();

    final batch = _firestore.batch();
    final now = DateTime.now().toIso8601String();
    final targetTournamentId = (tournamentId != null && tournamentId.isNotEmpty) ? tournamentId : 'main';

    // 1. Update Match
    final Map<String, dynamic> matchUpdate = {
      'tournamentId': targetTournamentId,
      'teamAPlayingVI': teamAPlayingVI,
      'teamAReserveId': teamAReserveId,
      'teamBPlayingVI': teamBPlayingVI,
      'teamBReserveId': teamBReserveId,
      'tossWinnerId': tossWinnerId,
      'tossDecision': tossDecision,
      'status': 'LIVE',
      'updatedAt': now,
    };
    if (teamAId != null && teamAId.isNotEmpty) {
      matchUpdate['teamAId'] = teamAId;
    }
    if (teamBId != null && teamBId.isNotEmpty) {
      matchUpdate['teamBId'] = teamBId;
    }

    final matchRef = _firestore.doc(FirestorePaths.match(matchId));
    batch.set(matchRef, matchUpdate, SetOptions(merge: true));

    // 2. Create Innings 1
    final inningsId = 'inn_${matchId}_1';
    final inningsRef = _firestore.doc(FirestorePaths.inning(inningsId));
    final firstInnings = InningsModel(
      id: inningsId,
      matchId: matchId,
      tournamentId: targetTournamentId,
      inningsNumber: 1,
      battingTeamId: battingTeamId,
      bowlingTeamId: bowlingTeamId,
      createdAt: now,
      updatedAt: now,
    );
    batch.set(inningsRef, firstInnings.toFirestore(), SetOptions(merge: true));

    // 3. Opening Batsmen scores
    final s1Score = BattingScore(
      id: '${inningsId}_$strikerId',
      inningsId: inningsId,
      matchId: matchId,
      tournamentId: targetTournamentId,
      playerId: strikerId,
      battingOrder: 1,
    );
    final s2Score = BattingScore(
      id: '${inningsId}_$nonStrikerId',
      inningsId: inningsId,
      matchId: matchId,
      tournamentId: targetTournamentId,
      playerId: nonStrikerId,
      battingOrder: 2,
    );
    batch.set(_firestore.doc(FirestorePaths.battingScore(s1Score.id)), s1Score.toFirestore(), SetOptions(merge: true));
    batch.set(_firestore.doc(FirestorePaths.battingScore(s2Score.id)), s2Score.toFirestore(), SetOptions(merge: true));

    // 4. Opening Bowler score
    final bScore = BowlingScore(
      id: '${inningsId}_$bowlerId',
      inningsId: inningsId,
      matchId: matchId,
      tournamentId: targetTournamentId,
      playerId: bowlerId,
    );
    batch.set(_firestore.doc(FirestorePaths.bowlingScore(bScore.id)), bScore.toFirestore(), SetOptions(merge: true));

    await batch.commit();
    debugPrint('[ScoringSyncService] Match $matchId successfully started in Firestore.');
  }

  /// 2. Atomic Ball Record: Syncs Match, Innings, Batting Scores, and Bowling Scores
  Future<void> recordDeliveryAtomic({
    required MatchModel match,
    required InningsModel innings,
    required Map<String, BattingScore> battingScores,
    required Map<String, BowlingScore> bowlingScores,
  }) async {
    await ensureAuthenticated();

    final batch = _firestore.batch();
    final now = DateTime.now().toIso8601String();
    final effectiveTourId = match.tournamentId.isNotEmpty
        ? match.tournamentId
        : (innings.tournamentId.isNotEmpty ? innings.tournamentId : 'main');

    // 1. Update Match (status, recentEvent, resultText, winningTeamId)
    final matchRef = _firestore.doc(FirestorePaths.match(match.id));
    final matchData = match.toFirestore();
    matchData['updatedAt'] = now;
    if ((matchData['tournamentId'] == null || matchData['tournamentId'] == '') && effectiveTourId.isNotEmpty) {
      matchData['tournamentId'] = effectiveTourId;
    }
    batch.set(matchRef, matchData, SetOptions(merge: true));

    // 2. Update Innings
    final inningsRef = _firestore.doc(FirestorePaths.inning(innings.id));
    final inningsData = innings.toFirestore();
    inningsData['updatedAt'] = now;
    if ((inningsData['tournamentId'] == null || inningsData['tournamentId'] == '') && effectiveTourId.isNotEmpty) {
      inningsData['tournamentId'] = effectiveTourId;
    }
    if ((inningsData['matchId'] == null || inningsData['matchId'] == '') && match.id.isNotEmpty) {
      inningsData['matchId'] = match.id;
    }
    batch.set(inningsRef, inningsData, SetOptions(merge: true));

    // 3. Batting Scores
    for (final score in battingScores.values) {
      if (score.id.trim().isEmpty || score.playerId.trim().isEmpty) continue;
      final bRef = _firestore.doc(FirestorePaths.battingScore(score.id));
      final bData = score.toFirestore();
      if ((bData['tournamentId'] == null || bData['tournamentId'] == '') && effectiveTourId.isNotEmpty) {
        bData['tournamentId'] = effectiveTourId;
      }
      if ((bData['matchId'] == null || bData['matchId'] == '') && match.id.isNotEmpty) {
        bData['matchId'] = match.id;
      }
      batch.set(bRef, bData, SetOptions(merge: true));
    }

    // 4. Bowling Scores
    for (final score in bowlingScores.values) {
      if (score.id.trim().isEmpty || score.playerId.trim().isEmpty) continue;
      final boRef = _firestore.doc(FirestorePaths.bowlingScore(score.id));
      final boData = score.toFirestore();
      if ((boData['tournamentId'] == null || boData['tournamentId'] == '') && effectiveTourId.isNotEmpty) {
        boData['tournamentId'] = effectiveTourId;
      }
      if ((boData['matchId'] == null || boData['matchId'] == '') && match.id.isNotEmpty) {
        boData['matchId'] = match.id;
      }
      batch.set(boRef, boData, SetOptions(merge: true));
    }

    await batch.commit();
    debugPrint('[ScoringSyncService] Delivery synced atomically to Firestore (Match: ${match.id}, Inn: ${innings.id})');

    // 5. If Match is Completed, automatically calculate & update Points Table / Standings
    if (match.isCompleted) {
      recalculateTournamentStandings(tournamentId: match.tournamentId);
    }
  }

  /// 3. Save Innings
  Future<void> saveInnings(InningsModel innings) async {
    await ensureAuthenticated();
    await _firestore
        .doc(FirestorePaths.inning(innings.id))
        .set(innings.toFirestore(), SetOptions(merge: true));
  }

  /// 4. Finalize Match: Marks match as COMPLETED and updates standings
  Future<void> finalizeMatch({
    required String matchId,
    required String winningTeamId,
    required String resultText,
    String? playerOfMatchId,
    String tournamentId = 'main',
  }) async {
    await ensureAuthenticated();

    await _firestore.doc(FirestorePaths.match(matchId)).set({
      'status': 'COMPLETED',
      'winningTeamId': winningTeamId,
      'resultText': resultText,
      'playerOfMatchId': playerOfMatchId,
      'completedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    debugPrint('[ScoringSyncService] Match $matchId finalized as COMPLETED.');
    await recalculateTournamentStandings(tournamentId: tournamentId);
  }

  /// 5. Automatically Recalculate and Update Points Table / Standings in Firestore
  Future<void> recalculateTournamentStandings({String tournamentId = 'main'}) async {
    try {
      await ensureAuthenticated();

      // 1. Fetch all teams in tournament
      final teamsSnap = await _firestore
          .collection(FirestorePaths.teams)
          .where('tournamentId', isEqualTo: tournamentId)
          .get();

      final teamIds = teamsSnap.docs.map((doc) => doc.id).toList();
      if (teamIds.isEmpty) return;

      // 2. Fetch all completed LEAGUE matches in tournament
      final matchesSnap = await _firestore
          .collection(FirestorePaths.matches)
          .where('status', isEqualTo: 'COMPLETED')
          .get();

      // Only count league matches for round-robin standings
      final completedMatches = matchesSnap.docs
          .map((doc) => MatchModel.fromFirestore(doc))
          .where((m) => !m.isFinal && !m.isPlayoff)
          .toList();

      // 3. Fetch all innings for completed matches
      final inningsSnap = await _firestore.collection(FirestorePaths.innings).get();
      final allInnings = inningsSnap.docs.map((doc) => InningsModel.fromFirestore(doc)).toList();
      final inningsByMatch = <String, List<InningsModel>>{};
      for (final inn in allInnings) {
        inningsByMatch.putIfAbsent(inn.matchId, () => []).add(inn);
      }

      // 4. Compute statistics for each team
      final Map<String, _TeamStandingAccumulator> stats = {
        for (final tId in teamIds)
          tId: _TeamStandingAccumulator(teamId: tId, tournamentId: tournamentId)
      };

      for (final match in completedMatches) {
        final teamAId = match.teamAId;
        final teamBId = match.teamBId;
        final matchInnList = inningsByMatch[match.id] ?? [];

        if (matchInnList.isEmpty) continue;

        final statA = stats[teamAId];
        final statB = stats[teamBId];

        if (statA == null || statB == null) continue;

        statA.played += 1;
        statB.played += 1;

        final inn1 = matchInnList.firstWhere(
          (i) => i.inningsNumber == 1,
          orElse: () => matchInnList[0],
        );
        final inn2 = matchInnList.length > 1
            ? matchInnList.firstWhere((i) => i.inningsNumber == 2, orElse: () => matchInnList[1])
            : null;

        // Innings 1 stats
        final inn1BattingTeam = inn1.battingTeamId;
        final inn1Runs = inn1.runs;
        final inn1Balls = inn1.balls;
        final matchMaxWickets = match.maxWickets;
        final inn1IsAllOut = inn1.allOut || (inn1.wickets >= matchMaxWickets);
        final inn1EffectiveBalls = inn1IsAllOut ? match.maxBalls : inn1Balls;

        if (inn1BattingTeam == teamAId) {
          statA.runsFor += inn1Runs;
          statA.ballsFor += inn1EffectiveBalls;

          statB.runsAgainst += inn1Runs;
          statB.ballsAgainst += inn1EffectiveBalls;
        } else {
          statB.runsFor += inn1Runs;
          statB.ballsFor += inn1EffectiveBalls;

          statA.runsAgainst += inn1Runs;
          statA.ballsAgainst += inn1EffectiveBalls;
        }

        // Innings 2 stats
        if (inn2 != null) {
          final inn2BattingTeam = inn2.battingTeamId;
          final inn2Runs = inn2.runs;
          final inn2Balls = inn2.balls;
          final inn2IsAllOut = inn2.allOut || (inn2.wickets >= matchMaxWickets);
          final inn2EffectiveBalls = inn2IsAllOut ? match.maxBalls : inn2Balls;

          if (inn2BattingTeam == teamAId) {
            statA.runsFor += inn2Runs;
            statA.ballsFor += inn2EffectiveBalls;

            statB.runsAgainst += inn2Runs;
            statB.ballsAgainst += inn2EffectiveBalls;
          } else {
            statB.runsFor += inn2Runs;
            statB.ballsFor += inn2EffectiveBalls;

            statA.runsAgainst += inn2Runs;
            statA.ballsAgainst += inn2EffectiveBalls;
          }
        }

        // Match Outcome
        if (match.winningTeamId != null && match.winningTeamId!.isNotEmpty) {
          if (match.winningTeamId == teamAId) {
            statA.won += 1;
            statA.form.add('W');
            statB.lost += 1;
            statB.form.add('L');
          } else if (match.winningTeamId == teamBId) {
            statB.won += 1;
            statB.form.add('W');
            statA.lost += 1;
            statA.form.add('L');
          }
        } else if (match.status == 'TIED') {
          statA.tied += 1;
          statA.form.add('T');
          statB.tied += 1;
          statB.form.add('T');
        } else if (match.status == 'NO_RESULT' || match.status == 'ABANDONED') {
          statA.noResult += 1;
          statA.form.add('NR');
          statB.noResult += 1;
          statB.form.add('NR');
        }
      }

      // 5. Calculate Points, NRR, and Rank Positions
      final standingList = stats.values.map((s) => s.toStandingModel()).toList();

      // Sort: Points DESC, NRR DESC, Won DESC
      standingList.sort((a, b) {
        if (b.points != a.points) return b.points.compareTo(a.points);
        if (b.nrr != a.nrr) return b.nrr.compareTo(a.nrr);
        return b.won.compareTo(a.won);
      });

      // 6. Write Standings to Firestore atomically
      final batch = _firestore.batch();
      final now = DateTime.now().toIso8601String();

      for (int i = 0; i < standingList.length; i++) {
        final position = i + 1;
        // Rank 1: Direct Final qualifier; Rank 2 & 3: Playoff qualifiers
        final isQualified = position <= 3;
        final standing = standingList[i].copyWith(
          position: position,
          qualified: isQualified,
          updatedAt: now,
        );

        final docRef = _firestore.collection(FirestorePaths.standings).doc(standing.teamId);
        batch.set(docRef, standing.toFirestore(), SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint('[ScoringSyncService] Successfully recalculated and updated tournament standings in Firestore.');

      // Auto-update Playoff and Grand Final fixtures
      await maybeUpdatePlayoffAndFinalFixtures(tournamentId);
    } catch (e, stack) {
      debugPrint('[ScoringSyncService] Error recalculating standings: $e\n$stack');
    }
  }

  /// Auto-Update Playoff and Grand Final Fixtures in Firestore with Qualified Teams from Standings
  Future<void> maybeUpdatePlayoffAndFinalFixtures(String tournamentId) async {
    try {
      final standingsSnap = await _firestore
          .collection(FirestorePaths.standings)
          .where('tournamentId', isEqualTo: tournamentId)
          .get();

      final standings = standingsSnap.docs
          .map((d) => StandingModel.fromFirestore(d))
          .toList();

      standings.sort((a, b) {
        if (a.position != b.position) {
          return a.position.compareTo(b.position);
        }
        if (b.points != a.points) {
          return b.points.compareTo(a.points);
        }
        return b.nrr.compareTo(a.nrr);
      });

      if (standings.isEmpty) return;
      final rank1TeamId = standings[0].teamId;
      final rank2TeamId = standings.length > 1 ? standings[1].teamId : null;
      final rank3TeamId = standings.length > 2 ? standings[2].teamId : null;

      final matchesSnap = await _firestore
          .collection(FirestorePaths.matches)
          .where('tournamentId', isEqualTo: tournamentId)
          .get();

      final matches = matchesSnap.docs
          .map((d) => MatchModel.fromMap(d.id, d.data()))
          .toList();

      // 1. Update Playoff Fixture: Rank 2 vs Rank 3
      if (rank2TeamId != null && rank3TeamId != null) {
        final playoffMatches = matches.where((m) =>
            m.stage.toUpperCase() == 'PLAYOFF' ||
            MatchStageX.fromFirestoreString(m.stage) == MatchStage.playoff).toList();

        if (playoffMatches.isNotEmpty) {
          final playoff = playoffMatches.first;
          if (!playoff.isCompleted && !playoff.isLive) {
            if (playoff.teamAId != rank2TeamId || playoff.teamBId != rank3TeamId) {
              await _firestore.collection(FirestorePaths.matches).doc(playoff.id).update({
                'teamAId': rank2TeamId,
                'teamBId': rank3TeamId,
                'stage': 'PLAYOFF',
                'updatedAt': DateTime.now().toIso8601String(),
              });
              debugPrint('[ScoringSyncService] Updated Playoff (${playoff.id}) with Rank 2 ($rank2TeamId) vs Rank 3 ($rank3TeamId)');
            }
          }
        }
      }

      // 2. Update Grand Final Fixture: Rank 1 vs Playoff Winner (or Rank 2)
      final finalMatches = matches.where((m) =>
          m.stage.toUpperCase() == 'FINAL' ||
          MatchStageX.fromFirestoreString(m.stage) == MatchStage.finalMatch).toList();

      if (finalMatches.isNotEmpty) {
        final finalMatch = finalMatches.first;
        if (!finalMatch.isCompleted && !finalMatch.isLive) {
          final playoffMatches = matches.where((m) =>
              m.id != finalMatch.id &&
              (m.stage.toUpperCase() == 'PLAYOFF' || MatchStageX.fromFirestoreString(m.stage) == MatchStage.playoff)).toList();

          String? targetFinalOpponent = finalMatch.teamBId;
          if (playoffMatches.isNotEmpty) {
            final playoff = playoffMatches.first;
            if (playoff.isCompleted && playoff.winningTeamId != null && playoff.winningTeamId!.isNotEmpty) {
              targetFinalOpponent = playoff.winningTeamId;
            }
          } else if (rank2TeamId != null) {
            targetFinalOpponent = rank2TeamId;
          }

          if (finalMatch.teamAId != rank1TeamId || (targetFinalOpponent != null && finalMatch.teamBId != targetFinalOpponent)) {
            final Map<String, dynamic> updateData = {
              'teamAId': rank1TeamId,
              'stage': 'FINAL',
              'updatedAt': DateTime.now().toIso8601String(),
            };
            if (targetFinalOpponent != null && targetFinalOpponent.isNotEmpty) {
              updateData['teamBId'] = targetFinalOpponent;
            }
            await _firestore.collection(FirestorePaths.matches).doc(finalMatch.id).update(updateData);
            debugPrint('[ScoringSyncService] Updated Grand Final (${finalMatch.id}) with Rank 1 ($rank1TeamId) vs $targetFinalOpponent');
          }
        }
      }
    } catch (e, stack) {
      debugPrint('[ScoringSyncService] Error updating Playoff & Final fixtures: $e\n$stack');
    }
  }

  /// Swaps a wrongly attributed player on the batting or bowling scorecard in Firestore
  Future<void> swapScorecardPlayer({
    required String matchId,
    required String inningsId,
    required int inningsNumber,
    required String oldPlayerId,
    required String newPlayerId,
    required String newPlayerName,
    required bool isBatting,
  }) async {
    await ensureAuthenticated();
    final batch = _firestore.batch();
    final now = DateTime.now().toIso8601String();

    if (isBatting) {
      final oldDocRef = _firestore.doc(FirestorePaths.battingScore('${inningsId}_$oldPlayerId'));
      final newDocRef = _firestore.doc(FirestorePaths.battingScore('${inningsId}_$newPlayerId'));

      final oldSnapshot = await oldDocRef.get();
      if (oldSnapshot.exists) {
        final data = Map<String, dynamic>.from(oldSnapshot.data() ?? {});
        data['id'] = '${inningsId}_$newPlayerId';
        data['playerId'] = newPlayerId;
        data['updatedAt'] = now;
        batch.set(newDocRef, data, SetOptions(merge: true));
        batch.delete(oldDocRef);
      }
    } else {
      final oldDocRef = _firestore.doc(FirestorePaths.bowlingScore('${inningsId}_$oldPlayerId'));
      final newDocRef = _firestore.doc(FirestorePaths.bowlingScore('${inningsId}_$newPlayerId'));

      final oldSnapshot = await oldDocRef.get();
      if (oldSnapshot.exists) {
        final data = Map<String, dynamic>.from(oldSnapshot.data() ?? {});
        data['id'] = '${inningsId}_$newPlayerId';
        data['playerId'] = newPlayerId;
        data['updatedAt'] = now;
        batch.set(newDocRef, data, SetOptions(merge: true));
        batch.delete(oldDocRef);
      }
    }

    // Also update match document if web format uses embedded innings map
    final matchRef = _firestore.doc(FirestorePaths.match(matchId));
    final matchSnap = await matchRef.get();
    if (matchSnap.exists) {
      final matchData = matchSnap.data();
      final inningsKey = inningsNumber == 1 ? 'innings1' : 'innings2';
      if (matchData != null && matchData.containsKey(inningsKey)) {
        final Map<String, dynamic> innings = Map<String, dynamic>.from(matchData[inningsKey] ?? {});
        if (isBatting) {
          final List batting = List.from(innings['batting'] ?? []);
          for (var i = 0; i < batting.length; i++) {
            if (batting[i]['playerId'] == oldPlayerId) {
              batting[i]['playerId'] = newPlayerId;
              batting[i]['name'] = newPlayerName;
            }
          }
          innings['batting'] = batting;
          if (innings['strikerId'] == oldPlayerId) innings['strikerId'] = newPlayerId;
          if (innings['nonStrikerId'] == oldPlayerId) innings['nonStrikerId'] = newPlayerId;
        } else {
          final List bowling = List.from(innings['bowling'] ?? []);
          for (var i = 0; i < bowling.length; i++) {
            if (bowling[i]['playerId'] == oldPlayerId) {
              bowling[i]['playerId'] = newPlayerId;
              bowling[i]['name'] = newPlayerName;
            }
          }
          innings['bowling'] = bowling;
          if (innings['currentBowlerId'] == oldPlayerId) innings['currentBowlerId'] = newPlayerId;
        }
        batch.update(matchRef, {
          inningsKey: innings,
          'updatedAt': now,
        });
      }
    }

    await batch.commit();
  }

  /// Updates match lineups (Playing VI and Reserves) in Firestore
  Future<void> updateMatchLineup({
    required String matchId,
    required List<String> teamAPlayingVI,
    String? teamAReserveId,
    required List<String> teamBPlayingVI,
    String? teamBReserveId,
  }) async {
    await ensureAuthenticated();
    final matchRef = _firestore.doc(FirestorePaths.match(matchId));
    await matchRef.update({
      'teamAPlayingVI': teamAPlayingVI,
      'teamAReserveId': teamAReserveId,
      'teamBPlayingVI': teamBPlayingVI,
      'teamBReserveId': teamBReserveId,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}

class _TeamStandingAccumulator {
  final String teamId;
  final String tournamentId;
  int played = 0;
  int won = 0;
  int lost = 0;
  int tied = 0;
  int noResult = 0;
  int runsFor = 0;
  int ballsFor = 0;
  int runsAgainst = 0;
  int ballsAgainst = 0;
  final List<String> form = [];

  _TeamStandingAccumulator({required this.teamId, required this.tournamentId});

  StandingModel toStandingModel() {
    final points = (won * 2) + (tied * 1) + (noResult * 1);

    // Calculate NRR: (RunsFor / OversFor) - (RunsAgainst / OversAgainst)
    final oversFor = ballsFor / 6.0;
    final oversAgainst = ballsAgainst / 6.0;

    final runRateFor = oversFor > 0 ? (runsFor / oversFor) : 0.0;
    final runRateAgainst = oversAgainst > 0 ? (runsAgainst / oversAgainst) : 0.0;

    final calculatedNrr = double.parse((runRateFor - runRateAgainst).toStringAsFixed(3));

    // Keep last 5 match forms
    final recentForm = form.length > 5 ? form.sublist(form.length - 5) : form;

    return StandingModel(
      id: teamId,
      tournamentId: tournamentId,
      teamId: teamId,
      played: played,
      won: won,
      lost: lost,
      tied: tied,
      noResult: noResult,
      points: points,
      runsFor: runsFor,
      ballsFor: ballsFor,
      runsAgainst: runsAgainst,
      ballsAgainst: ballsAgainst,
      nrr: calculatedNrr,
      form: recentForm,
    );
  }
}
