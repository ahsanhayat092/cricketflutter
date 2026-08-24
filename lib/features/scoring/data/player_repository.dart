import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../models/player_model.dart';

abstract class PlayerRepository {
  Stream<List<PlayerModel>> getPlayersByTeamStream(String teamId);
  Stream<List<PlayerModel>> getAllPlayersStream();
  Future<List<PlayerModel>> getPlayersByTeam(String teamId);
  Future<PlayerModel?> getPlayer(String playerId);
  Future<void> savePlayer(PlayerModel player);
  Future<String> addPlayerToSquad({
    required String teamId,
    required String name,
    required String role,
    String designation = 'Team Member',
    int? jerseyNumber,
  });
}

class FirebasePlayerRepository implements PlayerRepository {
  final FirebaseFirestore _firestore;

  FirebasePlayerRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<PlayerModel>> getPlayersByTeamStream(String teamId) {
    return _firestore
        .collection(FirestorePaths.players)
        .where('teamId', isEqualTo: teamId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => PlayerModel.fromFirestore(doc)).toList();
    });
  }

  @override
  Stream<List<PlayerModel>> getAllPlayersStream() {
    return _firestore
        .collection(FirestorePaths.players)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => PlayerModel.fromFirestore(doc)).toList();
    });
  }

  @override
  Future<List<PlayerModel>> getPlayersByTeam(String teamId) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.players)
        .where('teamId', isEqualTo: teamId)
        .get();
    return snapshot.docs.map((doc) => PlayerModel.fromFirestore(doc)).toList();
  }

  @override
  Future<PlayerModel?> getPlayer(String playerId) async {
    final doc = await _firestore.doc(FirestorePaths.player(playerId)).get();
    if (!doc.exists) return null;
    return PlayerModel.fromFirestore(doc);
  }

  @override
  Future<void> savePlayer(PlayerModel player) async {
    await _firestore
        .doc(FirestorePaths.player(player.id))
        .set(player.toFirestore(), SetOptions(merge: true));
  }

  @override
  Future<String> addPlayerToSquad({
    required String teamId,
    required String name,
    required String role,
    String designation = 'Team Member',
    int? jerseyNumber,
  }) async {
    final now = DateTime.now().toIso8601String();
    final isCaptain = designation == 'Captain';
    final isViceCaptain = designation == 'Vice Captain';
    final docRef = await _firestore.collection(FirestorePaths.players).add({
      'teamId': teamId,
      'name': name.trim(),
      'role': role,
      'designation': designation,
      'isCaptain': isCaptain,
      'isViceCaptain': isViceCaptain,
      'isPlayingVI': true,
      'jerseyNumber': jerseyNumber,
      'battingStyle': null,
      'bowlingStyle': null,
      'photoUrl': null,
      'createdAt': now,
      'updatedAt': now,
    });
    return docRef.id;
  }
}
