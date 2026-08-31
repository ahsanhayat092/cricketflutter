import 'match_rules_model.dart';

class TournamentBranding {
  final String primaryColor;
  final String accentColor;

  const TournamentBranding({
    this.primaryColor = '#0F172A',
    this.accentColor = '#F59E0B',
  });

  factory TournamentBranding.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const TournamentBranding();
    return TournamentBranding(
      primaryColor: data['primaryColor'] as String? ?? '#0F172A',
      accentColor: data['accentColor'] as String? ?? '#F59E0B',
    );
  }

  Map<String, dynamic> toMap() => {
        'primaryColor': primaryColor,
        'accentColor': accentColor,
      };
}

class TournamentModel {
  final String id;
  final String name;
  final String shortName;
  final String slug;
  final String formatType; // 'TAPE_BALL_INDOOR' | 'T10' | 'T20' | 'ODI' | 'CUSTOM'
  final int oversPerSide;
  final int maxOverPerBowler;
  final int playersPerTeam;
  final int maxWickets;
  final bool allowLastManStanding;
  final String scorerPin; // 4-digit PIN, default '1234'
  final String? ownerId;
  final String? ownerEmail;
  final TournamentBranding branding;
  final String venueName;
  final String? venueMapsUrl;
  final String status; // 'UPCOMING' | 'LIVE' | 'COMPLETED'
  final int winPoints;
  final int tiePoints;
  final int noResultPoints;
  final int lossPoints;
  final String? championTeamId;
  final String? createdAt;
  final String? updatedAt;

  const TournamentModel({
    this.id = 'main',
    required this.name,
    required this.shortName,
    this.slug = 'wasa-2026',
    this.formatType = 'TAPE_BALL_INDOOR',
    this.oversPerSide = 4,
    this.maxOverPerBowler = 1,
    this.playersPerTeam = 6,
    this.maxWickets = 6,
    this.allowLastManStanding = true,
    this.scorerPin = '1234',
    this.ownerId,
    this.ownerEmail,
    this.branding = const TournamentBranding(),
    this.venueName = 'WASA Sports Complex',
    this.venueMapsUrl,
    this.status = 'LIVE',
    this.winPoints = 2,
    this.tiePoints = 1,
    this.noResultPoints = 1,
    this.lossPoints = 0,
    this.championTeamId,
    this.createdAt,
    this.updatedAt,
  });

  MatchRulesModel get rules => MatchRulesModel(
        formatType: formatType,
        oversPerSide: oversPerSide,
        maxOverPerBowler: maxOverPerBowler,
        playersPerTeam: playersPerTeam,
        maxWickets: maxWickets,
        allowLastManStanding: allowLastManStanding,
        freeHitEnabled: true,
        noBallRuns: 1,
        wideRuns: 1,
      );

  bool isPinValid(String pin) => pin.trim() == scorerPin.trim();

  String get shareUrl => 'https://wasacricket.vercel.app/t/$slug';

  String get shareWhatsAppText =>
      '🏏 Follow *$name* on PitchPe!\n📊 Live Scores & Standings: $shareUrl';

  factory TournamentModel.fromMap(Map<String, dynamic>? data, {String id = 'main'}) {
    if (data == null) {
      return const TournamentModel(
        id: 'main',
        name: 'WASA Premier League 2026',
        shortName: 'WPL 2026',
        slug: 'wasa-2026',
      );
    }
    return TournamentModel(
      id: id,
      name: data['name'] as String? ?? 'WASA Premier League 2026',
      shortName: data['shortName'] as String? ?? 'WPL 2026',
      slug: data['slug'] as String? ?? (id == 'main' ? 'wasa-2026' : id),
      formatType: data['formatType'] as String? ?? 'TAPE_BALL_INDOOR',
      oversPerSide: (data['oversPerSide'] as num?)?.toInt() ?? 4,
      maxOverPerBowler: (data['maxOverPerBowler'] as num?)?.toInt() ?? 1,
      playersPerTeam: (data['playersPerTeam'] as num?)?.toInt() ?? 6,
      maxWickets: (data['maxWickets'] as num?)?.toInt() ?? 6,
      allowLastManStanding: data['allowLastManStanding'] as bool? ?? true,
      scorerPin: data['scorerPin'] as String? ?? '1234',
      ownerId: data['ownerId'] as String?,
      ownerEmail: data['ownerEmail'] as String?,
      branding: TournamentBranding.fromMap(data['branding'] as Map<String, dynamic>?),
      venueName: data['venueName'] as String? ?? 'WASA Sports Complex',
      venueMapsUrl: data['venueMapsUrl'] as String?,
      status: data['status'] as String? ?? 'LIVE',
      winPoints: (data['winPoints'] as num?)?.toInt() ?? 2,
      tiePoints: (data['tiePoints'] as num?)?.toInt() ?? 1,
      noResultPoints: (data['noResultPoints'] as num?)?.toInt() ?? 1,
      lossPoints: (data['lossPoints'] as num?)?.toInt() ?? 0,
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
      'slug': slug,
      'formatType': formatType,
      'oversPerSide': oversPerSide,
      'maxOverPerBowler': maxOverPerBowler,
      'playersPerTeam': playersPerTeam,
      'maxWickets': maxWickets,
      'allowLastManStanding': allowLastManStanding,
      'scorerPin': scorerPin,
      if (ownerId != null) 'ownerId': ownerId,
      if (ownerEmail != null) 'ownerEmail': ownerEmail,
      'branding': branding.toMap(),
      'venueName': venueName,
      if (venueMapsUrl != null) 'venueMapsUrl': venueMapsUrl,
      'status': status,
      'winPoints': winPoints,
      'tiePoints': tiePoints,
      'noResultPoints': noResultPoints,
      'lossPoints': lossPoints,
      if (championTeamId != null) 'championTeamId': championTeamId,
      if (createdAt != null) 'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  TournamentModel copyWith({
    String? id,
    String? name,
    String? shortName,
    String? slug,
    String? formatType,
    int? oversPerSide,
    int? maxOverPerBowler,
    int? playersPerTeam,
    int? maxWickets,
    bool? allowLastManStanding,
    String? scorerPin,
    String? ownerId,
    String? ownerEmail,
    TournamentBranding? branding,
    String? venueName,
    String? venueMapsUrl,
    String? status,
    int? winPoints,
    int? tiePoints,
    int? noResultPoints,
    int? lossPoints,
    String? championTeamId,
    String? createdAt,
    String? updatedAt,
  }) {
    return TournamentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      slug: slug ?? this.slug,
      formatType: formatType ?? this.formatType,
      oversPerSide: oversPerSide ?? this.oversPerSide,
      maxOverPerBowler: maxOverPerBowler ?? this.maxOverPerBowler,
      playersPerTeam: playersPerTeam ?? this.playersPerTeam,
      maxWickets: maxWickets ?? this.maxWickets,
      allowLastManStanding: allowLastManStanding ?? this.allowLastManStanding,
      scorerPin: scorerPin ?? this.scorerPin,
      ownerId: ownerId ?? this.ownerId,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      branding: branding ?? this.branding,
      venueName: venueName ?? this.venueName,
      venueMapsUrl: venueMapsUrl ?? this.venueMapsUrl,
      status: status ?? this.status,
      winPoints: winPoints ?? this.winPoints,
      tiePoints: tiePoints ?? this.tiePoints,
      noResultPoints: noResultPoints ?? this.noResultPoints,
      lossPoints: lossPoints ?? this.lossPoints,
      championTeamId: championTeamId ?? this.championTeamId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
