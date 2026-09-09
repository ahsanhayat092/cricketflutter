import 'package:flutter/foundation.dart';
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
import '../../auth/models/tournament_member_model.dart';

class FirebaseScoringService {
  final FirebaseFirestore _firestore;

  FirebaseScoringService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ==========================================
  // 1. TOURNAMENTS
  // ==========================================

  /// Stream all tournaments in SaaS platform
  Stream<List<TournamentModel>> getAllTournamentsStream() {
    return _firestore.collection(FirestorePaths.tournaments).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TournamentModel.fromMap(doc.data(), id: doc.id))
          .toList();
      // Ensure 'main' WASA tournament is included if not in Firestore yet
      if (!list.any((t) => t.id == 'main')) {
        list.insert(
          0,
          const TournamentModel(
            id: 'main',
            name: 'WASA Premier League 2026',
            shortName: 'WPL 2026',
            slug: 'wasa-2026',
          ),
        );
      }
      return list;
    });
  }

  /// Get all tournaments once
  Future<List<TournamentModel>> getAllTournaments() async {
    final snapshot = await _firestore.collection(FirestorePaths.tournaments).get();
    final list = snapshot.docs
        .map((doc) => TournamentModel.fromMap(doc.data(), id: doc.id))
        .toList();
    if (!list.any((t) => t.id == 'main')) {
      list.insert(
        0,
        const TournamentModel(
          id: 'main',
          name: 'WASA Premier League 2026',
          shortName: 'WPL 2026',
          slug: 'wasa-2026',
        ),
      );
    }
    return list;
  }

  /// Stream single tournament document
  Stream<TournamentModel> getTournamentStream({String tournamentId = FirestorePaths.tournamentMainId}) {
    return _firestore
        .doc(FirestorePaths.tournament(tournamentId))
        .snapshots()
        .map((doc) => TournamentModel.fromMap(doc.data(), id: doc.id));
  }

  /// Get tournament once
  Future<TournamentModel?> getTournament({String tournamentId = FirestorePaths.tournamentMainId}) async {
    final doc = await _firestore.doc(FirestorePaths.tournament(tournamentId)).get();
    if (!doc.exists) {
      if (tournamentId == 'main') {
        return const TournamentModel(
          id: 'main',
          name: 'WASA Premier League 2026',
          shortName: 'WPL 2026',
          slug: 'wasa-2026',
        );
      }
      return null;
    }
    return TournamentModel.fromMap(doc.data(), id: doc.id);
  }

  /// Save or update tournament
  Future<void> saveTournament(TournamentModel tournament) async {
    await _firestore
        .doc(FirestorePaths.tournament(tournament.id))
        .set(tournament.toFirestore(), SetOptions(merge: true));
  }

  /// Update Scorer 4-digit PIN for ground entry
  Future<void> updateScorerPin({required String tournamentId, required String newPin}) async {
    await _firestore.doc(FirestorePaths.tournament(tournamentId)).update({
      'scorerPin': newPin.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // ==========================================
  // 1B. TOURNAMENT MEMBERS (RBAC)
  // ==========================================

  /// Stream all members of a tournament (Owner, Admins, Scorers)
  Stream<List<TournamentMemberModel>> getTournamentMembersStream(String tournamentId) {
    return _firestore
        .collection(FirestorePaths.tournamentMembers)
        .where('tournamentId', isEqualTo: tournamentId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TournamentMemberModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// Stream tournament memberships for a specific logged-in user email
  Stream<List<TournamentMemberModel>> getUserMembershipsStream(String userEmail) {
    if (userEmail.isEmpty) return Stream.value([]);
    final cleanEmail = userEmail.toLowerCase().trim();
    return _firestore
        .collection(FirestorePaths.tournamentMembers)
        .where('userEmail', isEqualTo: cleanEmail)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TournamentMemberModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// Add or update a tournament member
  Future<void> saveTournamentMember(TournamentMemberModel member) async {
    final cleanEmail = member.userEmail.toLowerCase().trim();
    final memberId = '${member.tournamentId}_$cleanEmail';
    await _firestore
        .collection(FirestorePaths.tournamentMembers)
        .doc(memberId)
        .set(member.toMap(), SetOptions(merge: true));
  }

  /// Remove a member from tournament
  Future<void> removeTournamentMember(String memberDocId) async {
    await _firestore.collection(FirestorePaths.tournamentMembers).doc(memberDocId).delete();
  }

  // ==========================================
  // 2. TEAMS
  // ==========================================

  /// Stream all teams for tournament (both direct tournament teams and accepted invite memberships)
  Stream<List<TeamModel>> getTeamsStream({String tournamentId = 'main'}) {
    return _firestore.collection(FirestorePaths.teams).snapshots().asyncMap((snapshot) async {
      final directTeams = snapshot.docs
          .map((doc) => TeamModel.fromMap(doc.id, doc.data()))
          .where((t) {
            if (tournamentId == 'main') {
              return t.tournamentId.isEmpty || t.tournamentId == 'main';
            }
            return t.tournamentId == tournamentId;
          })
          .toList();

      final List<TeamModel> membershipTeams = [];
      try {
        final memSnap = await _firestore
            .collection(FirestorePaths.tournamentTeamMemberships)
            .where('tournamentId', isEqualTo: tournamentId)
            .get();

        for (final memDoc in memSnap.docs) {
          final data = memDoc.data();
          final rawStatus = (data['status'] as String?)?.toUpperCase().trim();
          if (rawStatus != 'ACCEPTED') continue;

          final teamId = (data['teamId'] as String?) ?? (data['team_id'] as String?) ?? memDoc.id;
          if (teamId.trim().isEmpty) continue;
          if (directTeams.any((t) => t.id == teamId)) continue;

          final memTeamName = (data['teamName'] as String?) ??
                              (data['name'] as String?) ??
                              (data['team_name'] as String?) ??
                              (data['title'] as String?);
          final memShortName = (data['teamShortName'] as String?) ??
                               (data['shortName'] as String?) ??
                               (data['team_short_name'] as String?) ??
                               (data['code'] as String?);
          final memLogoUrl = (data['teamLogoUrl'] as String?) ??
                             (data['logoUrl'] as String?) ??
                             (data['team_logo_url'] as String?) ??
                             (data['logo'] as String?) ??
                             '';

          final teamDoc = await _firestore.collection(FirestorePaths.teams).doc(teamId).get();
          if (teamDoc.exists && teamDoc.data() != null) {
            final docModel = TeamModel.fromMap(teamDoc.id, teamDoc.data()!);
            if (docModel.name.isNotEmpty && !docModel.name.startsWith('Team ')) {
              membershipTeams.add(docModel);
            } else if (memTeamName != null && memTeamName.trim().isNotEmpty) {
              membershipTeams.add(docModel.copyWith(
                name: memTeamName.trim(),
                shortName: memShortName?.trim().isNotEmpty == true ? memShortName!.trim() : docModel.shortName,
                logoUrl: memLogoUrl.isNotEmpty ? memLogoUrl : docModel.logoUrl,
              ));
            } else {
              membershipTeams.add(docModel);
            }
          } else if (memTeamName != null && memTeamName.trim().isNotEmpty) {
            membershipTeams.add(
              TeamModel(
                id: teamId,
                tournamentId: tournamentId,
                name: memTeamName.trim(),
                shortName: memShortName?.trim().isNotEmpty == true
                    ? memShortName!.trim()
                    : (memTeamName.trim().length <= 4 ? memTeamName.trim().toUpperCase() : memTeamName.trim().substring(0, memTeamName.trim().length.clamp(1, 3)).toUpperCase()),
                logoUrl: memLogoUrl,
                groupName: (data['groupName'] as String?) ?? (data['group_name'] as String?) ?? 'A',
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[FirebaseScoringService] Error streaming accepted team memberships: $e');
      }

      return deduplicateTeams(directTeams, membershipTeams);
    });
  }

  /// Deduplicate teams by both `id` AND normalized `name`.
  /// Prioritizes direct tournament team documents over membership fallback records.
  static List<TeamModel> deduplicateTeams(List<TeamModel> directTeams, List<TeamModel> membershipTeams) {
    final combined = [...directTeams, ...membershipTeams];
    final Map<String, TeamModel> uniqueById = {};
    final Map<String, TeamModel> uniqueByName = {};

    for (final team in combined) {
      final cleanName = team.name.trim().toLowerCase();

      // Only add if neither the ID nor the team name has already been encountered
      if (!uniqueById.containsKey(team.id) && !uniqueByName.containsKey(cleanName)) {
        uniqueById[team.id] = team;
        if (cleanName.isNotEmpty) {
          uniqueByName[cleanName] = team;
        }
      }
    }

    return uniqueById.values.toList();
  }

  /// Fetch all teams once (both direct and accepted invite memberships)
  Future<List<TeamModel>> getTeams({String tournamentId = 'main'}) async {
    final snapshot = await _firestore.collection(FirestorePaths.teams).get();
    final directTeams = snapshot.docs
        .map((doc) => TeamModel.fromMap(doc.id, doc.data()))
        .where((t) {
          if (tournamentId == 'main') {
            return t.tournamentId.isEmpty || t.tournamentId == 'main';
          }
          return t.tournamentId == tournamentId;
        })
        .toList();

    final List<TeamModel> membershipTeams = [];
    try {
      final memSnap = await _firestore
          .collection(FirestorePaths.tournamentTeamMemberships)
          .where('tournamentId', isEqualTo: tournamentId)
          .get();

      for (final memDoc in memSnap.docs) {
        final data = memDoc.data();
        final rawStatus = (data['status'] as String?)?.toUpperCase().trim();
        if (rawStatus != 'ACCEPTED') continue;

        final teamId = (data['teamId'] as String?) ?? (data['team_id'] as String?) ?? memDoc.id;
        if (teamId.trim().isEmpty) continue;
        if (directTeams.any((t) => t.id == teamId)) continue;

        final memTeamName = (data['teamName'] as String?) ??
                            (data['name'] as String?) ??
                            (data['team_name'] as String?) ??
                            (data['title'] as String?);
        final memShortName = (data['teamShortName'] as String?) ??
                             (data['shortName'] as String?) ??
                             (data['team_short_name'] as String?) ??
                             (data['code'] as String?);
        final memLogoUrl = (data['teamLogoUrl'] as String?) ??
                           (data['logoUrl'] as String?) ??
                           (data['team_logo_url'] as String?) ??
                           (data['logo'] as String?) ??
                           '';

        final teamDoc = await _firestore.collection(FirestorePaths.teams).doc(teamId).get();
        if (teamDoc.exists && teamDoc.data() != null) {
          final docModel = TeamModel.fromMap(teamDoc.id, teamDoc.data()!);
          if (docModel.name.isNotEmpty && !docModel.name.startsWith('Team ')) {
            membershipTeams.add(docModel);
          } else if (memTeamName != null && memTeamName.trim().isNotEmpty) {
            membershipTeams.add(docModel.copyWith(
              name: memTeamName.trim(),
              shortName: memShortName?.trim().isNotEmpty == true ? memShortName!.trim() : docModel.shortName,
              logoUrl: memLogoUrl.isNotEmpty ? memLogoUrl : docModel.logoUrl,
            ));
          } else {
            membershipTeams.add(docModel);
          }
        } else if (memTeamName != null && memTeamName.trim().isNotEmpty) {
          membershipTeams.add(
            TeamModel(
              id: teamId,
              tournamentId: tournamentId,
              name: memTeamName.trim(),
              shortName: memShortName?.trim().isNotEmpty == true
                  ? memShortName!.trim()
                  : (memTeamName.trim().length <= 4 ? memTeamName.trim().toUpperCase() : memTeamName.trim().substring(0, memTeamName.trim().length.clamp(1, 3)).toUpperCase()),
              logoUrl: memLogoUrl,
              groupName: (data['groupName'] as String?) ?? (data['group_name'] as String?) ?? 'A',
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[FirebaseScoringService] Error fetching accepted team memberships: $e');
    }

    return deduplicateTeams(directTeams, membershipTeams);
  }

  /// Fetch single team
  Future<TeamModel?> getTeam(String teamId) async {
    final doc = await _firestore.doc(FirestorePaths.team(teamId)).get();
    if (doc.exists && doc.data() != null) {
      return TeamModel.fromMap(doc.id, doc.data());
    }

    // Fallback: search in tournament_team_memberships
    try {
      final memSnap = await _firestore
          .collection(FirestorePaths.tournamentTeamMemberships)
          .where('teamId', isEqualTo: teamId)
          .limit(1)
          .get();
      if (memSnap.docs.isNotEmpty) {
        final data = memSnap.docs.first.data();
        final teamName = (data['teamName'] as String?) ??
                         (data['name'] as String?) ??
                         (data['team_name'] as String?);
        if (teamName != null && teamName.trim().isNotEmpty) {
          final short = (data['teamShortName'] as String?) ??
                        (data['shortName'] as String?) ??
                        (data['code'] as String?);
          final logo = (data['teamLogoUrl'] as String?) ??
                       (data['logoUrl'] as String?) ??
                       '';
          return TeamModel(
            id: teamId,
            tournamentId: data['tournamentId'] as String? ?? 'main',
            name: teamName.trim(),
            shortName: short?.trim().isNotEmpty == true
                ? short!.trim()
                : (teamName.trim().length <= 4 ? teamName.trim().toUpperCase() : teamName.trim().substring(0, teamName.trim().length.clamp(1, 3)).toUpperCase()),
            logoUrl: logo,
            groupName: data['groupName'] as String? ?? 'A',
          );
        }
      }
    } catch (_) {}

    return null;
  }

  /// Stream single team directly from /teams/{teamId} with fallback
  Stream<TeamModel?> getTeamStream(String teamId) {
    if (teamId.isEmpty) return Stream.value(null);
    return _firestore.doc(FirestorePaths.team(teamId)).snapshots().asyncMap((doc) async {
      if (doc.exists && doc.data() != null) {
        return TeamModel.fromMap(doc.id, doc.data());
      }
      return getTeam(teamId);
    });
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
    return _firestore.collection(FirestorePaths.matches).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => MatchModel.fromMap(doc.id, doc.data()))
          .where((m) {
            if (tournamentId == 'main') {
              return m.tournamentId.isEmpty || m.tournamentId == 'main';
            }
            return m.tournamentId == tournamentId;
          })
          .toList();
      list.sort((a, b) => a.matchNumber.compareTo(b.matchNumber));
      return list;
    });
  }

  /// Fetch all matches once
  Future<List<MatchModel>> getMatches({String tournamentId = 'main'}) async {
    final snapshot = await _firestore.collection(FirestorePaths.matches).get();
    final list = snapshot.docs
        .map((doc) => MatchModel.fromMap(doc.id, doc.data()))
        .where((m) {
          if (tournamentId == 'main') {
            return m.tournamentId.isEmpty || m.tournamentId == 'main';
          }
          return m.tournamentId == tournamentId;
        })
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
    return _firestore.collection(FirestorePaths.standings).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => StandingModel.fromMap(doc.id, doc.data()))
          .where((s) {
            if (tournamentId == 'main') {
              return s.tournamentId.isEmpty || s.tournamentId == 'main';
            }
            return s.tournamentId == tournamentId;
          })
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
    final snapshot = await _firestore.collection(FirestorePaths.standings).get();
    final list = snapshot.docs
        .map((doc) => StandingModel.fromMap(doc.id, doc.data()))
        .where((s) {
          if (tournamentId == 'main') {
            return s.tournamentId.isEmpty || s.tournamentId == 'main';
          }
          return s.tournamentId == tournamentId;
        })
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

  /// Update Bowler Quota for Match
  Future<void> updateMatchBowlerQuota({
    required String matchId,
    required int maxOverPerBowler,
  }) async {
    await _firestore.doc(FirestorePaths.match(matchId)).set({
      'maxOverPerBowler': maxOverPerBowler,
      'rules.maxOverPerBowler': maxOverPerBowler,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }
}
