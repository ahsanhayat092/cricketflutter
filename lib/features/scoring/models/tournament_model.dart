class TournamentModel {
  final String id;
  final String name;
  final String shortName;
  final int winPoints;
  final int tiePoints;
  final int noResultPoints;
  final int lossPoints;
  final int oversPerSide;
  final String? championTeamId;
  final String? createdAt;
  final String? updatedAt;

  const TournamentModel({
    this.id = 'main',
    required this.name,
    required this.shortName,
    this.winPoints = 2,
    this.tiePoints = 1,
    this.noResultPoints = 1,
    this.lossPoints = 0,
    this.oversPerSide = 4,
    this.championTeamId,
    this.createdAt,
    this.updatedAt,
  });

  factory TournamentModel.fromMap(Map<String, dynamic>? data, {String id = 'main'}) {
    if (data == null) {
      return const TournamentModel(
        id: 'main',
        name: 'WASA Cricket Championship 2026',
        shortName: 'WASA 2026',
      );
    }
    return TournamentModel(
      id: id,
      name: data['name'] as String? ?? 'WASA Cricket Championship 2026',
      shortName: data['shortName'] as String? ?? 'WASA 2026',
      winPoints: (data['winPoints'] as num?)?.toInt() ?? 2,
      tiePoints: (data['tiePoints'] as num?)?.toInt() ?? 1,
      noResultPoints: (data['noResultPoints'] as num?)?.toInt() ?? 1,
      lossPoints: (data['lossPoints'] as num?)?.toInt() ?? 0,
      oversPerSide: (data['oversPerSide'] as num?)?.toInt() ?? 4,
      championTeamId: data['championTeamId'] as String?,
      createdAt: data['createdAt'] as String?,
      updatedAt: data['updatedAt'] as String?,
    );
  }

  factory TournamentModel.fromJson(Map<String, dynamic> json) =>
      TournamentModel.fromMap(json, id: json['id'] as String? ?? 'main');

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'shortName': shortName,
      'winPoints': winPoints,
      'tiePoints': tiePoints,
      'noResultPoints': noResultPoints,
      'lossPoints': lossPoints,
      'oversPerSide': oversPerSide,
      'championTeamId': championTeamId,
      if (createdAt != null) 'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  TournamentModel copyWith({
    String? id,
    String? name,
    String? shortName,
    int? winPoints,
    int? tiePoints,
    int? noResultPoints,
    int? lossPoints,
    int? oversPerSide,
    String? championTeamId,
    String? createdAt,
    String? updatedAt,
  }) {
    return TournamentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      winPoints: winPoints ?? this.winPoints,
      tiePoints: tiePoints ?? this.tiePoints,
      noResultPoints: noResultPoints ?? this.noResultPoints,
      lossPoints: lossPoints ?? this.lossPoints,
      oversPerSide: oversPerSide ?? this.oversPerSide,
      championTeamId: championTeamId ?? this.championTeamId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
