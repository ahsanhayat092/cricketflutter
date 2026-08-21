import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/image_url_helper.dart';

typedef Team = TeamModel;

class TeamModel {
  final String id;
  final String tournamentId;
  final String name;
  final String shortName;
  final String groupName; // "A" | "B"
  final String logoUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String? createdAt;
  final String? updatedAt;

  const TeamModel({
    required this.id,
    this.tournamentId = 'main',
    required this.name,
    required this.shortName,
    this.groupName = 'A',
    this.logoUrl = '',
    this.primaryColor,
    this.secondaryColor,
    this.createdAt,
    this.updatedAt,
  });

  String get formattedLogoUrl {
    return ImageUrlHelper.formatDirectImageUrl(logoUrl);
  }

  factory TeamModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TeamModel.fromMap(doc.id, data);
  }

  factory TeamModel.fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) {
      return TeamModel(id: id, name: 'Team $id', shortName: id.toUpperCase());
    }
    return TeamModel(
      id: id,
      tournamentId: data['tournamentId'] as String? ?? 'main',
      name: data['name'] as String? ?? '',
      shortName: data['shortName'] as String? ?? '',
      groupName: data['groupName'] as String? ?? 'A',
      logoUrl: ImageUrlHelper.formatDirectImageUrl(data['logoUrl'] as String? ?? ''),
      primaryColor: data['primaryColor'] as String?,
      secondaryColor: data['secondaryColor'] as String?,
      createdAt: data['createdAt'] as String?,
      updatedAt: data['updatedAt'] as String?,
    );
  }

  factory TeamModel.fromJson(Map<String, dynamic> json) =>
      TeamModel.fromMap(json['id'] as String? ?? '', json);

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'name': name,
      'shortName': shortName,
      'groupName': groupName,
      'logoUrl': logoUrl,
      if (primaryColor != null) 'primaryColor': primaryColor,
      if (secondaryColor != null) 'secondaryColor': secondaryColor,
      if (createdAt != null) 'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  TeamModel copyWith({
    String? id,
    String? tournamentId,
    String? name,
    String? shortName,
    String? groupName,
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    String? createdAt,
    String? updatedAt,
  }) {
    return TeamModel(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      groupName: groupName ?? this.groupName,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
