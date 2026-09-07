import '../../../core/constants/app_constants.dart';
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
  final String playoffFormat; // 'DIRECT_TOP2' | 'PAGE_PLAYOFF_TOP3' | 'IPL_TOP4' | 'SEMI_FINALS'
  final String stageFormat; // 'ROUND_ROBIN' | 'GROUPS_AND_KNOCKOUT'
  final String? groupPlayoffFormat; // 'GROUP_SEMI_FINALS' | 'GROUP_DIRECT_FINAL'
  final List<String>? groups; // e.g. ['A', 'B']
  final int? groupCount; // e.g. 2
  final int teamsPerGroupAdvance; // default 2
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
    this.slug = 'cricket-tournament',
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
    this.venueName = 'Cricket Ground',
    this.venueMapsUrl,
    this.status = 'LIVE',
    this.playoffFormat = 'PAGE_PLAYOFF_TOP3',
    this.stageFormat = 'ROUND_ROBIN',
    this.groupPlayoffFormat,
    this.groups,
    this.groupCount,
    this.teamsPerGroupAdvance = 2,
    this.winPoints = 2,
    this.tiePoints = 1,
    this.noResultPoints = 1,
    this.lossPoints = 0,
    this.championTeamId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isGroupsAndKnockout => stageFormat == 'GROUPS_AND_KNOCKOUT';

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

  String get shareUrl => 'https://pitchpe.vercel.app/t/$slug';

  String get shareWhatsAppText =>
      '🏏 Follow *$name* on PitchPe!\n📊 Live Scores & Standings: $shareUrl';

  factory TournamentModel.fromMap(Map<String, dynamic>? data, {String id = 'main'}) {
    if (data == null) {
      return const TournamentModel(
        id: 'main',
        name: 'Cricket Tournament',
        shortName: 'CRIC',
        slug: 'cricket-tournament',
      );
    }
    final formatType = data['formatType'] as String? ?? 'TAPE_BALL_INDOOR';
    final overs = (data['oversPerSide'] as num?)?.toInt() ??
        (data['overs_per_side'] as num?)?.toInt() ??
        (data['overs'] as num?)?.toInt() ??
        (data['maxOvers'] as num?)?.toInt() ??
        (formatType == 'T20' ? 20 : (formatType == 'T10' ? 10 : 4));

    final defaultPlayers = (formatType == 'T20' || formatType == 'T10' || formatType == 'ODI' || formatType == 'TEST') ? 11 : 6;
    final players = (data['playersPerTeam'] as num?)?.toInt() ??
        (data['players_per_team'] as num?)?.toInt() ??
        (data['players'] as num?)?.toInt() ??
        (data['teamSize'] as num?)?.toInt() ??
        (data['team_size'] as num?)?.toInt() ??
        (data['squadSize'] as num?)?.toInt() ??
        (data['squad_size'] as num?)?.toInt() ??
        (data['playingSquadSize'] as num?)?.toInt() ??
        (data['playing_squad_size'] as num?)?.toInt() ??
        (data['totalPlayers'] as num?)?.toInt() ??
        defaultPlayers;

    final lms = data['allowLastManStanding'] as bool? ??
        (data['allow_last_man_standing'] as bool?) ??
        (formatType == 'T20' || formatType == 'ODI' || formatType == 'TEST' || players > 8
            ? false
            : (players <= 8));

    final explicitMaxWickets = (data['maxWickets'] as num?)?.toInt() ??
        (data['max_wickets'] as num?)?.toInt();
    final defaultMaxWickets = lms ? players : (players > 1 ? players - 1 : 1);
    final effectiveMaxWickets = (explicitMaxWickets != null && explicitMaxWickets > 0 && !(players >= 10 && explicitMaxWickets <= 6))
        ? explicitMaxWickets
        : defaultMaxWickets;

    final explicitMaxBowler = (data['maxOverPerBowler'] as num?)?.toInt() ??
        (data['max_over_per_bowler'] as num?)?.toInt() ??
        (data['max_overs_per_bowler'] as num?)?.toInt() ??
        (data['maxOversPerBowler'] as num?)?.toInt();
    final effectiveMaxBowler = explicitMaxBowler != null && explicitMaxBowler > 0
        ? explicitMaxBowler
        : AppConstants.getMaxOverPerBowler(oversPerSide: overs);

    final rawGroups = data['groups'] as List<dynamic>?;
    final List<String>? groupsList = rawGroups?.map((e) => e.toString()).toList();

    return TournamentModel(
      id: id,
      name: data['name'] as String? ?? 'Cricket Tournament',
      shortName: data['shortName'] as String? ?? 'CRIC',
      slug: data['slug'] as String? ?? (id == 'main' ? 'cricket-tournament' : id),
      formatType: formatType,
      oversPerSide: overs,
      maxOverPerBowler: effectiveMaxBowler,
      playersPerTeam: players,
      maxWickets: effectiveMaxWickets,
      allowLastManStanding: lms,
      scorerPin: data['scorerPin'] as String? ?? data['scorer_pin'] as String? ?? '1234',
      ownerId: data['ownerId'] as String? ?? data['owner_id'] as String?,
      ownerEmail: data['ownerEmail'] as String? ?? data['owner_email'] as String?,
      branding: TournamentBranding.fromMap(data['branding'] as Map<String, dynamic>?),
      venueName: data['venueName'] as String? ?? data['venue_name'] as String? ?? 'Cricket Ground',
      venueMapsUrl: data['venueMapsUrl'] as String? ?? data['venue_maps_url'] as String?,
      status: data['status'] as String? ?? 'LIVE',
      playoffFormat: data['playoffFormat'] as String? ?? data['playoff_format'] as String? ?? 'PAGE_PLAYOFF_TOP3',
      stageFormat: data['stageFormat'] as String? ?? data['stage_format'] as String? ?? 'ROUND_ROBIN',
      groupPlayoffFormat: data['groupPlayoffFormat'] as String? ?? data['group_playoff_format'] as String?,
      groups: groupsList,
      groupCount: (data['groupCount'] as num?)?.toInt() ?? (data['group_count'] as num?)?.toInt() ?? groupsList?.length,
      teamsPerGroupAdvance: (data['teamsPerGroupAdvance'] as num?)?.toInt() ?? (data['teams_per_group_advance'] as num?)?.toInt() ?? 2,
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
      'playoffFormat': playoffFormat,
      'stageFormat': stageFormat,
      if (groupPlayoffFormat != null) 'groupPlayoffFormat': groupPlayoffFormat,
      if (groups != null) 'groups': groups,
      if (groupCount != null) 'groupCount': groupCount,
      'teamsPerGroupAdvance': teamsPerGroupAdvance,
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
    String? playoffFormat,
    String? stageFormat,
    String? groupPlayoffFormat,
    List<String>? groups,
    int? groupCount,
    int? teamsPerGroupAdvance,
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
      playoffFormat: playoffFormat ?? this.playoffFormat,
      stageFormat: stageFormat ?? this.stageFormat,
      groupPlayoffFormat: groupPlayoffFormat ?? this.groupPlayoffFormat,
      groups: groups ?? this.groups,
      groupCount: groupCount ?? this.groupCount,
      teamsPerGroupAdvance: teamsPerGroupAdvance ?? this.teamsPerGroupAdvance,
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
