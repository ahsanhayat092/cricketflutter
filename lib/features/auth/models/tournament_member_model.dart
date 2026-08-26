import 'package:cloud_firestore/cloud_firestore.dart';

enum TournamentRole {
  owner,
  admin,
  scorer,
}

extension TournamentRoleX on TournamentRole {
  String toFirestoreString() {
    switch (this) {
      case TournamentRole.owner:
        return 'OWNER';
      case TournamentRole.admin:
        return 'ADMIN';
      case TournamentRole.scorer:
        return 'SCORER';
    }
  }

  static TournamentRole fromFirestoreString(String? val) {
    final v = val?.toUpperCase();
    if (v == 'OWNER') return TournamentRole.owner;
    if (v == 'ADMIN') return TournamentRole.admin;
    return TournamentRole.scorer;
  }

  String get displayName {
    switch (this) {
      case TournamentRole.owner:
        return '👑 Tournament Owner';
      case TournamentRole.admin:
        return '🛡️ Co-Administrator';
      case TournamentRole.scorer:
        return '🏏 Match Scorer';
    }
  }
}

class TournamentMemberModel {
  final String id; // format: ${tournamentId}_${cleanEmail}
  final String tournamentId;
  final String userId;
  final String userEmail;
  final String userName;
  final String role; // 'OWNER' | 'ADMIN' | 'SCORER'
  final String? invitedBy;
  final String? createdAt;

  const TournamentMemberModel({
    required this.id,
    required this.tournamentId,
    required this.userId,
    required this.userEmail,
    required this.userName,
    this.role = 'SCORER',
    this.invitedBy,
    this.createdAt,
  });

  TournamentRole get roleEnum => TournamentRoleX.fromFirestoreString(role);
  bool get isOwner => roleEnum == TournamentRole.owner;
  bool get isAdmin => roleEnum == TournamentRole.admin;
  bool get isScorer => roleEnum == TournamentRole.scorer;
  bool get canManage => isOwner || isAdmin;
  bool get canScore => isOwner || isAdmin || isScorer;

  factory TournamentMemberModel.fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) {
      return TournamentMemberModel(
        id: id,
        tournamentId: 'main',
        userId: '',
        userEmail: '',
        userName: '',
      );
    }
    return TournamentMemberModel(
      id: id,
      tournamentId: data['tournamentId'] as String? ?? 'main',
      userId: data['userId'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      role: data['role'] as String? ?? 'SCORER',
      invitedBy: data['invitedBy'] as String?,
      createdAt: data['createdAt'] as String?,
    );
  }

  factory TournamentMemberModel.fromFirestore(DocumentSnapshot doc) =>
      TournamentMemberModel.fromMap(doc.id, doc.data() as Map<String, dynamic>?);

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'role': role,
      if (invitedBy != null) 'invitedBy': invitedBy,
      'createdAt': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  TournamentMemberModel copyWith({
    String? id,
    String? tournamentId,
    String? userId,
    String? userEmail,
    String? userName,
    String? role,
    String? invitedBy,
    String? createdAt,
  }) {
    return TournamentMemberModel(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      role: role ?? this.role,
      invitedBy: invitedBy ?? this.invitedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
