import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/firestore_helper.dart';
import '../../../core/utils/image_url_helper.dart';

typedef Player = PlayerModel;

class PlayerModel {
  final String id;
  final String teamId;
  final String name;
  final int? jerseyNumber;
  final String role; // "Batsman" | "Bowler" | "All-rounder" | "Wicketkeeper"
  final bool isCaptain;
  final bool isViceCaptain;
  final bool isPlayingVI;
  final String? designation; // "Captain" | "Vice Captain" | "Team Member"
  final String? battingStyle; // "Right-hand bat" | "Left-hand bat"
  final String? bowlingStyle; // "Right-arm off break" | "Right-arm fast" etc.
  final String? photoUrl;
  final String? createdAt;
  final String? updatedAt;

  const PlayerModel({
    required this.id,
    required this.teamId,
    required this.name,
    this.jerseyNumber,
    this.role = 'Batsman',
    this.isCaptain = false,
    this.isViceCaptain = false,
    this.isPlayingVI = true,
    this.designation,
    this.battingStyle,
    this.bowlingStyle,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  String get formattedPhotoUrl => ImageUrlHelper.formatDirectImageUrl(photoUrl);

  /// Parse directly from Cloud Firestore DocumentSnapshot
  factory PlayerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PlayerModel.fromMap(doc.id, data);
  }

  factory PlayerModel.fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) {
      return PlayerModel(id: id, teamId: '', name: 'Player $id');
    }
    return PlayerModel(
      id: id,
      teamId: data['teamId'] as String? ?? '',
      name: data['name'] as String? ?? 'Unknown',
      jerseyNumber: (data['jerseyNumber'] as num?)?.toInt(),
      role: data['role'] as String? ?? 'Batsman',
      isCaptain: data['isCaptain'] as bool? ?? false,
      isViceCaptain: data['isViceCaptain'] as bool? ?? false,
      isPlayingVI: data['isPlayingVI'] as bool? ?? true,
      designation: data['designation'] as String?,
      battingStyle: data['battingStyle'] as String?,
      bowlingStyle: data['bowlingStyle'] as String?,
      photoUrl: ImageUrlHelper.formatDirectImageUrl(data['photoUrl'] as String?),
      createdAt: parseFirestoreDateTimeString(data['createdAt']),
      updatedAt: parseFirestoreDateTimeString(data['updatedAt']),
    );
  }

  factory PlayerModel.fromJson(Map<String, dynamic> json) =>
      PlayerModel.fromMap(json['id'] as String? ?? '', json);

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'name': name,
      'jerseyNumber': jerseyNumber,
      'role': role,
      'isCaptain': isCaptain,
      'isViceCaptain': isViceCaptain,
      'isPlayingVI': isPlayingVI,
      'designation': designation ?? (isCaptain ? 'Captain' : (isViceCaptain ? 'Vice Captain' : 'Team Member')),
      'battingStyle': battingStyle,
      'bowlingStyle': bowlingStyle,
      'photoUrl': photoUrl,
      if (createdAt != null) 'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  PlayerModel copyWith({
    String? id,
    String? teamId,
    String? name,
    int? jerseyNumber,
    String? role,
    bool? isCaptain,
    bool? isViceCaptain,
    bool? isPlayingVI,
    String? designation,
    String? battingStyle,
    String? bowlingStyle,
    String? photoUrl,
    String? createdAt,
    String? updatedAt,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      name: name ?? this.name,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      role: role ?? this.role,
      isCaptain: isCaptain ?? this.isCaptain,
      isViceCaptain: isViceCaptain ?? this.isViceCaptain,
      isPlayingVI: isPlayingVI ?? this.isPlayingVI,
      designation: designation ?? this.designation,
      battingStyle: battingStyle ?? this.battingStyle,
      bowlingStyle: bowlingStyle ?? this.bowlingStyle,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
