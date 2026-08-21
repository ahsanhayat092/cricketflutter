import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../models/tournament_model.dart';
import '../models/team_model.dart';
import '../models/player_model.dart';
import '../models/match_model.dart';
import '../models/innings_model.dart';
import '../models/batting_score.dart';
import '../models/bowling_score.dart';
import '../../standings/models/standing.dart';
import '../../auth/models/app_user.dart';

class FirebaseScoringService {
  final FirebaseFirestore _firestore;

  FirebaseScoringService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ==========================================
  // 1. TOURNAMENTS
  // ==========================================

  /// Stream singleton tournament document (default "main")
  Stream<TournamentModel> getTournamentStream({String tournamentId = FirestorePaths.tournamentMainId}) {
    return _firestore
        .doc(FirestorePaths.tournament(tournamentId))
        .snapshots()
        .map((doc) => TournamentModel.fromMap(doc.data(), id: doc.id));
  }

  /// Get tournament once
  Future<TournamentModel?> getTournament({String tournamentId = FirestorePaths.tournamentMainId}) async {
    final doc = await _firestore.doc(FirestorePaths.tournament(tournamentId)).get();
    if (!doc.exists) return null;
    return TournamentModel.fromMap(doc.data(), id: doc.id);
  }

  /// Save or update tournament
  Future<void> saveTournament(TournamentModel tournament) async {
    await _firestore
        .doc(FirestorePaths.tournament(tournament.id))
        .set(tournament.toFirestore(), SetOptions(merge: true));
  }

  // ==========================================
  // 2. TEAMS
  // ==========================================

  /// Stream all teams for tournament
  Stream<List<TeamModel>> getTeamsStream({String tournamentId = 'main'}) {
    return _firestore
        .collection(FirestorePaths.teams)
        .where('tournamentId', isEqualTo: tournamentId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TeamModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// Fetch all teams once
  Future<List<TeamModel>> getTeams({String tournamentId = 'main'}) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.teams)
        .where('tournamentId', isEqualTo: tournamentId)
        .get();
    return snapshot.docs
        .map((doc) => TeamModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Fetch single team
  Future<TeamModel?> getTeam(String teamId) async {
    final doc = await _firestore.doc(FirestorePaths.team(teamId)).get();
    if (!doc.exists) return null;
    return TeamModel.fromMap(doc.id, doc.data());
  }

  /// Save or update team
  Future<void> saveTeam(TeamModel team) async {
    await _firestore
        .doc(FirestorePaths.team(team.id))
        .set(team.toFirestore(), SetOptions(merge: true));
  }

  // ==========================================
  // 3. PLAYERS
  // ==========================================

  /// Stream all players (or filtered by teamId)
  Stream<List<PlayerModel>> getPlayersStream({String? teamId}) {
    Query query = _firestore.collection(FirestorePaths.players);
    if (teamId != null && teamId.isNotEmpty) {
      query = query.where('teamId', isEqualTo: teamId);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => PlayerModel.fromMap(doc.id, doc.data() as Map<String, dynamic>?))
          .toList();
    });
  }

  /// Fetch players once
  Future<List<PlayerModel>> getPlayers({String? teamId}) async {
    Query query = _firestore.collection(FirestorePaths.players);
    if (teamId != null && teamId.isNotEmpty) {
      query = query.where('teamId', isEqualTo: teamId);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => PlayerModel.fromMap(doc.id, doc.data() as Map<String, dynamic>?))
        .toList();
  }

  /// Fetch single player
  Future<PlayerModel?> getPlayer(String playerId) async {
    final doc = await _firestore.doc(FirestorePaths.player(playerId)).get();
    if (!doc.exists) return null;
    return PlayerModel.fromMap(doc.id, doc.data());
  }

  /// Save or update player
  Future<void> savePlayer(PlayerModel player) async {
    await _firestore
        .doc(FirestorePaths.player(player.id))
        .set(player.toFirestore(), SetOptions(merge: true));
  }

  // ==========================================
  // 4. MATCHES
  // ==========================================

  /// Stream all matches for tournament
  Stream<List<MatchModel>> getMatchesStream({String tournamentId = 'main'}) {
    return _firestore
        .collection(FirestorePaths.matches)
        .where('tournamentId', isEqualTo: tournamentId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => MatchModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => a.matchNumber.compareTo(b.matchNumber));
      return list;
    });
  }

  /// Fetch all matches once
  Future<List<MatchModel>> getMatches({String tournamentId = 'main'}) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.matches)
        .where('tournamentId', isEqualTo: tournamentId)
        .get();
    final list = snapshot.docs
        .map((doc) => MatchModel.fromMap(doc.id, doc.data()))
        .toList();
    list.sort((a, b) => a.matchNumber.compareTo(b.matchNumber));
    return list;
  }

  /// Stream single match
  Stream<MatchModel> getMatchStream(String matchId) {
    return _firestore.doc(FirestorePaths.match(matchId)).snapshots().map((doc) {
      return MatchModel.fromMap(doc.id, doc.data());
    });
  }

  /// Fetch single match once
  Future<MatchModel?> getMatch(String matchId) async {
    final doc = await _firestore.doc(FirestorePaths.match(matchId)).get();
    if (!doc.exists) return null;
    return MatchModel.fromMap(doc.id, doc.data());
  }

  /// Save or update match
  Future<void> saveMatch(MatchModel match) async {
    await _firestore
        .doc(FirestorePaths.match(match.id))
        .set(match.toFirestore(), SetOptions(merge: true));
  }

  // ==========================================
  // 5. INNINGS
  // ==========================================

  /// Stream innings for a match
  Stream<List<InningsModel>> getInningsForMatchStream(String matchId) {
    return _firestore
        .collection(FirestorePaths.innings)
        .where('matchId', isEqualTo: matchId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => InningsModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => a.inningsNumber.compareTo(b.inningsNumber));
      return list;
    });
  }

  /// Fetch innings for match once
  Future<List<InningsModel>> getInningsForMatch(String matchId) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.innings)
        .where('matchId', isEqualTo: matchId)
        .get();
    final list = snapshot.docs
        .map((doc) => InningsModel.fromMap(doc.id, doc.data()))
        .toList();
    list.sort((a, b) => a.inningsNumber.compareTo(b.inningsNumber));
    return list;
  }

  /// Stream single inning
  Stream<InningsModel?> getInningStream(String inningsId) {
    return _firestore.doc(FirestorePaths.inning(inningsId)).snapshots().map((doc) {
      if (!doc.exists) return null;
      return InningsModel.fromMap(doc.id, doc.data());
    });
  }

  /// Save or update inning
  Future<void> saveInnings(InningsModel innings) async {
    await _firestore
        .doc(FirestorePaths.inning(innings.id))
        .set(innings.toFirestore(), SetOptions(merge: true));
  }

  /// Create new innings (alias)
  Future<void> createInnings(InningsModel innings) async => saveInnings(innings);

  // ==========================================
  // 6. BATTING SCORES
  // ==========================================

  /// Stream batting scores for an innings
  Stream<List<BattingScore>> getBattingScoresStream(String inningsId) {
    return _firestore
        .collection(FirestorePaths.battingScores)
        .where('inningsId', isEqualTo: inningsId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => BattingScore.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => a.battingOrder.compareTo(b.battingOrder));
      return list;
    });
  }

  /// Fetch batting scores once
  Future<List<BattingScore>> getBattingScores(String inningsId) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.battingScores)
        .where('inningsId', isEqualTo: inningsId)
        .get();
    final list = snapshot.docs
        .map((doc) => BattingScore.fromMap(doc.id, doc.data()))
        .toList();
    list.sort((a, b) => a.battingOrder.compareTo(b.battingOrder));
    return list;
  }

  /// Save batting score
  Future<void> saveBattingScore(BattingScore score) async {
    await _firestore
        .doc(FirestorePaths.battingScore(score.id))
        .set(score.toFirestore(), SetOptions(merge: true));
  }

  // ==========================================
  // 7. BOWLING SCORES
  // ==========================================

  /// Stream bowling scores for an innings
  Stream<List<BowlingScore>> getBowlingScoresStream(String inningsId) {
    return _firestore
        .collection(FirestorePaths.bowlingScores)
        .where('inningsId', isEqualTo: inningsId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BowlingScore.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// Fetch bowling scores once
  Future<List<BowlingScore>> getBowlingScores(String inningsId) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.bowlingScores)
        .where('inningsId', isEqualTo: inningsId)
        .get();
    return snapshot.docs
        .map((doc) => BowlingScore.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Save bowling score
  Future<void> saveBowlingScore(BowlingScore score) async {
    await _firestore
        .doc(FirestorePaths.bowlingScore(score.id))
        .set(score.toFirestore(), SetOptions(merge: true));
  }

  // ==========================================
  // 8. STANDINGS
  // ==========================================

  /// Stream tournament standings
  Stream<List<StandingModel>> getStandingsStream({String tournamentId = 'main'}) {
    return _firestore
        .collection(FirestorePaths.standings)
        .where('tournamentId', isEqualTo: tournamentId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => StandingModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) {
        final ptsComp = b.points.compareTo(a.points);
        if (ptsComp != 0) return ptsComp;
        final nrrComp = b.nrr.compareTo(a.nrr);
        if (nrrComp != 0) return nrrComp;
        return b.adminTiebreak.compareTo(a.adminTiebreak);
      });
      return list;
    });
  }

  /// Fetch standings once
  Future<List<StandingModel>> getStandings({String tournamentId = 'main'}) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.standings)
        .where('tournamentId', isEqualTo: tournamentId)
        .get();
    final list = snapshot.docs
        .map((doc) => StandingModel.fromMap(doc.id, doc.data()))
        .toList();
    list.sort((a, b) {
      final ptsComp = b.points.compareTo(a.points);
      if (ptsComp != 0) return ptsComp;
      return b.nrr.compareTo(a.nrr);
    });
    return list;
  }

  /// Save or update standing
  Future<void> saveStanding(StandingModel standing) async {
    await _firestore
        .doc(FirestorePaths.standing(standing.teamId))
        .set(standing.toFirestore(), SetOptions(merge: true));
  }

  // ==========================================
  // 9. USERS
  // ==========================================

  /// Stream user profile
  Stream<AppUser?> getUserStream(String uid) {
    return _firestore.doc(FirestorePaths.user(uid)).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.id, doc.data());
    });
  }

  /// Get user profile once
  Future<AppUser?> getUser(String uid) async {
    final doc = await _firestore.doc(FirestorePaths.user(uid)).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.id, doc.data());
  }

  /// Save or update user
  Future<void> saveUser(AppUser user) async {
    await _firestore
        .doc(FirestorePaths.user(user.uid))
        .set(user.toFirestore(), SetOptions(merge: true));
  }

  // ==========================================
  // ATOMIC SCORING TRANSACTION
  // ==========================================

  /// Sync atomic scoring result to Firestore in a WriteBatch
  Future<void> syncScoringState({
    required MatchModel match,
    required InningsModel innings,
    required Map<String, BattingScore> battingScores,
    required Map<String, BowlingScore> bowlingScores,
  }) async {
    final batch = _firestore.batch();

    // 1. Update Match
    final matchRef = _firestore.doc(FirestorePaths.match(match.id));
    batch.set(matchRef, match.toFirestore(), SetOptions(merge: true));

    // 2. Update Innings
    final inningsRef = _firestore.doc(FirestorePaths.inning(innings.id));
    batch.set(inningsRef, innings.toFirestore(), SetOptions(merge: true));

    // 3. Update Batting Scores
    for (final score in battingScores.values) {
      final bRef = _firestore.doc(FirestorePaths.battingScore(score.id));
      batch.set(bRef, score.toFirestore(), SetOptions(merge: true));
    }

    // 4. Update Bowling Scores
    for (final score in bowlingScores.values) {
      final boRef = _firestore.doc(FirestorePaths.bowlingScore(score.id));
      batch.set(boRef, score.toFirestore(), SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Update Match Lineup and Toss
  Future<void> updateMatchLineupAndToss({
    required String matchId,
    required List<String> teamAPlayingVI,
    required String? teamAReserveId,
    required List<String> teamBPlayingVI,
    required String? teamBReserveId,
    required String tossWinnerId,
    required String tossDecision,
  }) async {
    await _firestore.doc(FirestorePaths.match(matchId)).set({
      'teamAPlayingVI': teamAPlayingVI,
      'teamAReserveId': teamAReserveId,
      'teamBPlayingVI': teamBPlayingVI,
      'teamBReserveId': teamBReserveId,
      'tossWinnerId': tossWinnerId,
      'tossDecision': tossDecision,
      'status': 'LIVE',
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }
}
