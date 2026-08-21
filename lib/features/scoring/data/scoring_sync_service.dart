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
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ScoringSyncService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Ensure user is authenticated before executing Firestore writes (Security Rules compliance)
  Future<void> ensureAuthenticated() async {
    if (_auth.currentUser == null) {
      try {
        debugPrint('[ScoringSyncService] No authenticated user found. Signing in anonymously...');
        await _auth.signInAnonymously();
        debugPrint('[ScoringSyncService] Anonymous authentication successful: ${_auth.currentUser?.uid}');
      } catch (e) {
        debugPrint('[ScoringSyncService] Authentication error: $e');
        rethrow;
      }
    }
  }

  /// 1. Start Match: Updates match lineup, toss, and creates 1st Innings atomically
  Future<void> startMatch({
    required String matchId,
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

    // 1. Update Match
    final matchRef = _firestore.doc(FirestorePaths.match(matchId));
    batch.set(matchRef, {
      'teamAPlayingVI': teamAPlayingVI,
      'teamAReserveId': teamAReserveId,
      'teamBPlayingVI': teamBPlayingVI,
      'teamBReserveId': teamBReserveId,
      'tossWinnerId': tossWinnerId,
      'tossDecision': tossDecision,
      'status': 'LIVE',
      'updatedAt': now,
    }, SetOptions(merge: true));

    // 2. Create Innings 1
    final inningsId = 'inn_${matchId}_1';
    final inningsRef = _firestore.doc(FirestorePaths.inning(inningsId));
    final firstInnings = InningsModel(
      id: inningsId,
      matchId: matchId,
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
      playerId: strikerId,
      battingOrder: 1,
    );
    final s2Score = BattingScore(
      id: '${inningsId}_$nonStrikerId',
      inningsId: inningsId,
      playerId: nonStrikerId,
      battingOrder: 2,
    );
    batch.set(_firestore.doc(FirestorePaths.battingScore(s1Score.id)), s1Score.toFirestore(), SetOptions(merge: true));
    batch.set(_firestore.doc(FirestorePaths.battingScore(s2Score.id)), s2Score.toFirestore(), SetOptions(merge: true));

    // 4. Opening Bowler score
    final bScore = BowlingScore(
      id: '${inningsId}_$bowlerId',
      inningsId: inningsId,
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

    // 1. Update Match (status, recentEvent, resultText, winningTeamId)
    final matchRef = _firestore.doc(FirestorePaths.match(match.id));
    final matchData = match.toFirestore();
    matchData['updatedAt'] = now;
    batch.set(matchRef, matchData, SetOptions(merge: true));

    // 2. Update Innings
    final inningsRef = _firestore.doc(FirestorePaths.inning(innings.id));
    final inningsData = innings.toFirestore();
    inningsData['updatedAt'] = now;
    batch.set(inningsRef, inningsData, SetOptions(merge: true));

    // 3. Batting Scores
    for (final score in battingScores.values) {
      final bRef = _firestore.doc(FirestorePaths.battingScore(score.id));
      batch.set(bRef, score.toFirestore(), SetOptions(merge: true));
    }

    // 4. Bowling Scores
    for (final score in bowlingScores.values) {
      final boRef = _firestore.doc(FirestorePaths.bowlingScore(score.id));
      batch.set(boRef, score.toFirestore(), SetOptions(merge: true));
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
          .where((m) => !m.isFinal)
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

        final inn1 = matchInnList.isNotEmpty
            ? matchInnList.firstWhere((i) => i.inningsNumber == 1, orElse: () => matchInnList.first)
            : null;
        final inn2 = matchInnList.length > 1
            ? matchInnList.firstWhere((i) => i.inningsNumber == 2, orElse: () => matchInnList.last)
            : null;

        final accA = stats[teamAId];
        final accB = stats[teamBId];

        if (accA != null) accA.played++;
        if (accB != null) accB.played++;

        final isTie = match.resultText?.toLowerCase().contains('tie') == true;
        final isNoResult = match.resultText?.toLowerCase().contains('no result') == true;

        if (isTie) {
          if (accA != null) { accA.tied++; accA.form.add('T'); }
          if (accB != null) { accB.tied++; accB.form.add('T'); }
        } else if (isNoResult) {
          if (accA != null) { accA.noResult++; accA.form.add('NR'); }
          if (accB != null) { accB.noResult++; accB.form.add('NR'); }
        } else if (match.winningTeamId != null && match.winningTeamId!.isNotEmpty) {
          if (match.winningTeamId == teamAId) {
            if (accA != null) { accA.won++; accA.form.add('W'); }
            if (accB != null) { accB.lost++; accB.form.add('L'); }
          } else if (match.winningTeamId == teamBId) {
            if (accB != null) { accB.won++; accB.form.add('W'); }
            if (accA != null) { accA.lost++; accA.form.add('L'); }
          }
        }

        // Add NRR runs and overs/balls
        if (inn1 != null && inn2 != null) {
          final maxBalls = match.maxBalls;

          // Innings 1:
          final inn1Team = inn1.battingTeamId;
          final inn1BowlTeam = inn1.bowlingTeamId;
          final int inn1BallsFaced = inn1.allOut ? match.maxBalls : inn1.balls;

          // Innings 2:
          final inn2Team = inn2.battingTeamId;
          final inn2BowlTeam = inn2.bowlingTeamId;
          final int inn2BallsFaced = inn2.allOut ? match.maxBalls : inn2.balls;

          if (stats.containsKey(inn1Team)) {
            stats[inn1Team]!.runsFor += inn1.runs;
            stats[inn1Team]!.ballsFor += inn1BallsFaced;
          }
          if (stats.containsKey(inn1BowlTeam)) {
            stats[inn1BowlTeam]!.runsAgainst += inn1.runs;
            stats[inn1BowlTeam]!.ballsAgainst += inn1BallsFaced;
          }

          if (stats.containsKey(inn2Team)) {
            stats[inn2Team]!.runsFor += inn2.runs;
            stats[inn2Team]!.ballsFor += inn2BallsFaced;
          }
          if (stats.containsKey(inn2BowlTeam)) {
            stats[inn2BowlTeam]!.runsAgainst += inn2.runs;
            stats[inn2BowlTeam]!.ballsAgainst += inn2BallsFaced;
          }
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
        final isQualified = position <= 2; // Top 2 qualify for Final
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
    } catch (e, stack) {
      debugPrint('[ScoringSyncService] Error recalculating standings: $e\n$stack');
    }
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
