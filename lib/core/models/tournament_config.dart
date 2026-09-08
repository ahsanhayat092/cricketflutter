import 'package:flutter/material.dart';

// =============================================================================
// UNIVERSAL TOURNAMENT CONFIGURATION DATA CONTRACT
// Pure data-driven models decoupling mobile app from hardcoded assumptions
// =============================================================================

class MetaConfig {
  final String preset; // e.g. 'T10', 'T20', 'TAPE_BALL_INDOOR'
  final String ballType; // e.g. 'HEAVY_TENNIS', 'LEATHER', 'TAPE_BALL'

  const MetaConfig({
    this.preset = 'T10',
    this.ballType = 'HEAVY_TENNIS',
  });

  factory MetaConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MetaConfig();
    return MetaConfig(
      preset: map['preset'] as String? ?? 'T10',
      ballType: map['ballType'] as String? ?? map['ball_type'] as String? ?? 'HEAVY_TENNIS',
    );
  }

  Map<String, dynamic> toMap() => {
        'preset': preset,
        'ballType': ballType,
      };
}

class NoBallRuleConfig {
  final int runs;
  final bool reball;
  final bool freeHit;

  const NoBallRuleConfig({
    this.runs = 1,
    this.reball = true,
    this.freeHit = true,
  });

  factory NoBallRuleConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const NoBallRuleConfig();
    return NoBallRuleConfig(
      runs: (map['runs'] as num?)?.toInt() ?? 1,
      reball: map['reball'] as bool? ?? true,
      freeHit: map['freeHit'] as bool? ?? map['free_hit'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'runs': runs,
        'reball': reball,
        'freeHit': freeHit,
      };
}

class WideRuleConfig {
  final int runs;
  final bool reball;

  const WideRuleConfig({
    this.runs = 1,
    this.reball = true,
  });

  factory WideRuleConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const WideRuleConfig();
    return WideRuleConfig(
      runs: (map['runs'] as num?)?.toInt() ?? 1,
      reball: map['reball'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'runs': runs,
        'reball': reball,
      };
}

class SuperOverConfig {
  final bool enabled;
  final int maxOvers;
  final int maxWickets;

  const SuperOverConfig({
    this.enabled = true,
    this.maxOvers = 1,
    this.maxWickets = 2,
  });

  factory SuperOverConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const SuperOverConfig();
    return SuperOverConfig(
      enabled: map['enabled'] as bool? ?? false,
      maxOvers: (map['maxOvers'] as num?)?.toInt() ?? 1,
      maxWickets: (map['maxWickets'] as num?)?.toInt() ?? 2,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'maxOvers': maxOvers,
        'maxWickets': maxWickets,
      };
}

class PowerplayConfig {
  final bool enabled;
  final List<int> overs;
  final int maxFieldersOutsideCircle;

  const PowerplayConfig({
    this.enabled = true,
    this.overs = const [1, 2, 3],
    this.maxFieldersOutsideCircle = 2,
  });

  factory PowerplayConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PowerplayConfig();
    final rawOvers = map['overs'] as List<dynamic>?;
    return PowerplayConfig(
      enabled: map['enabled'] as bool? ?? false,
      overs: rawOvers != null ? rawOvers.map((e) => (e as num).toInt()).toList() : const [],
      maxFieldersOutsideCircle: (map['maxFieldersOutsideCircle'] as num?)?.toInt() ?? 2,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'overs': overs,
        'maxFieldersOutsideCircle': maxFieldersOutsideCircle,
      };
}

class MatchRulesConfig {
  final int oversPerSide;
  final int ballsPerOver;
  final int maxOversPerBowler;
  final int playersPerTeam;
  final int maxDismissals;
  final bool allowLastManStanding;
  final NoBallRuleConfig noBallRule;
  final WideRuleConfig wideRule;
  final SuperOverConfig superOver;
  final PowerplayConfig powerplay;

  const MatchRulesConfig({
    this.oversPerSide = 10,
    this.ballsPerOver = 6,
    this.maxOversPerBowler = 2,
    this.playersPerTeam = 11,
    this.maxDismissals = 10,
    this.allowLastManStanding = false,
    this.noBallRule = const NoBallRuleConfig(),
    this.wideRule = const WideRuleConfig(),
    this.superOver = const SuperOverConfig(),
    this.powerplay = const PowerplayConfig(),
  });

  factory MatchRulesConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MatchRulesConfig();
    final players = (map['playersPerTeam'] as num?)?.toInt() ??
        (map['players_per_team'] as num?)?.toInt() ??
        11;
    final lms = map['allowLastManStanding'] as bool? ??
        map['allow_last_man_standing'] as bool? ??
        false;
    final defaultDismissals = lms ? players : (players > 1 ? players - 1 : 1);
    final dismissals = (map['maxDismissals'] as num?)?.toInt() ??
        (map['max_dismissals'] as num?)?.toInt() ??
        (map['maxWickets'] as num?)?.toInt() ??
        defaultDismissals;

    return MatchRulesConfig(
      oversPerSide: (map['oversPerSide'] as num?)?.toInt() ??
          (map['overs_per_side'] as num?)?.toInt() ??
          (map['overs'] as num?)?.toInt() ??
          10,
      ballsPerOver: (map['ballsPerOver'] as num?)?.toInt() ??
          (map['balls_per_over'] as num?)?.toInt() ??
          6,
      maxOversPerBowler: (map['maxOversPerBowler'] as num?)?.toInt() ??
          (map['max_overs_per_bowler'] as num?)?.toInt() ??
          2,
      playersPerTeam: players,
      maxDismissals: dismissals,
      allowLastManStanding: lms,
      noBallRule: NoBallRuleConfig.fromMap(map['noBallRule'] as Map<String, dynamic>?),
      wideRule: WideRuleConfig.fromMap(map['wideRule'] as Map<String, dynamic>?),
      superOver: SuperOverConfig.fromMap(map['superOver'] as Map<String, dynamic>?),
      powerplay: PowerplayConfig.fromMap(map['powerplay'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toMap() => {
        'oversPerSide': oversPerSide,
        'ballsPerOver': ballsPerOver,
        'maxOversPerBowler': maxOversPerBowler,
        'playersPerTeam': playersPerTeam,
        'maxDismissals': maxDismissals,
        'allowLastManStanding': allowLastManStanding,
        'noBallRule': noBallRule.toMap(),
        'wideRule': wideRule.toMap(),
        'superOver': superOver.toMap(),
        'powerplay': powerplay.toMap(),
      };
}

class StageGroupConfig {
  final String id;
  final String name;
  final String colorAccent;
  final int qualifyingSlots;

  const StageGroupConfig({
    required this.id,
    required this.name,
    this.colorAccent = '#06B6D4',
    this.qualifyingSlots = 2,
  });

  Color get color => parseHexColor(colorAccent, fallback: const Color(0xFF06B6D4));

  factory StageGroupConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const StageGroupConfig(id: 'A', name: 'Group A');
    return StageGroupConfig(
      id: map['id']?.toString() ?? 'A',
      name: map['name'] as String? ?? 'Group ${map['id'] ?? 'A'}',
      colorAccent: map['colorAccent'] as String? ?? map['color_accent'] as String? ?? '#06B6D4',
      qualifyingSlots: (map['qualifyingSlots'] as num?)?.toInt() ??
          (map['qualifying_slots'] as num?)?.toInt() ??
          2,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'colorAccent': colorAccent,
        'qualifyingSlots': qualifyingSlots,
      };
}

class AdvancementRuleConfig {
  final String type; // 'CROSS_SEMI_FINALS', 'DIRECT_FINAL', 'PAGE_PLAYOFF', etc.
  final String description;

  const AdvancementRuleConfig({
    this.type = 'CROSS_SEMI_FINALS',
    this.description = 'Top 2 from each group advance to Semi-Finals (A1 vs B2, B1 vs A2)',
  });

  factory AdvancementRuleConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AdvancementRuleConfig();
    return AdvancementRuleConfig(
      type: map['type'] as String? ?? 'CROSS_SEMI_FINALS',
      description: map['description'] as String? ??
          'Top 2 from each group advance to Semi-Finals (A1 vs B2, B1 vs A2)',
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'description': description,
      };
}

class TournamentStageConfig {
  final String id;
  final String name;
  final String type; // 'GROUPS', 'KNOCKOUT', 'LEAGUE'
  final int sequenceOrder;
  final List<StageGroupConfig> groups;
  final AdvancementRuleConfig? advancementRule;

  const TournamentStageConfig({
    required this.id,
    required this.name,
    required this.type,
    this.sequenceOrder = 1,
    this.groups = const [],
    this.advancementRule,
  });

  bool get isGroupsStage => type.toUpperCase() == 'GROUPS';
  bool get isKnockoutStage => type.toUpperCase() == 'KNOCKOUT';
  bool get isLeagueStage => type.toUpperCase() == 'LEAGUE';

  StageGroupConfig? findGroup(String groupId) {
    for (final g in groups) {
      if (g.id.toUpperCase() == groupId.toUpperCase()) return g;
    }
    return null;
  }

  factory TournamentStageConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const TournamentStageConfig(
        id: 'stage-1',
        name: 'League Stage',
        type: 'LEAGUE',
      );
    }

    final rawGroups = map['groups'] as List<dynamic>?;
    final groupsList = rawGroups != null
        ? rawGroups
            .map((g) => StageGroupConfig.fromMap(g as Map<String, dynamic>?))
            .toList()
        : <StageGroupConfig>[];

    return TournamentStageConfig(
      id: map['id']?.toString() ?? 'stage-1',
      name: map['name'] as String? ?? 'Stage',
      type: (map['type'] as String? ?? 'LEAGUE').toUpperCase(),
      sequenceOrder: (map['sequenceOrder'] as num?)?.toInt() ??
          (map['sequence_order'] as num?)?.toInt() ??
          1,
      groups: groupsList,
      advancementRule: map['advancementRule'] != null
          ? AdvancementRuleConfig.fromMap(map['advancementRule'] as Map<String, dynamic>?)
          : (map['advancement_rule'] != null
              ? AdvancementRuleConfig.fromMap(map['advancement_rule'] as Map<String, dynamic>?)
              : null),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'sequenceOrder': sequenceOrder,
        'groups': groups.map((g) => g.toMap()).toList(),
        if (advancementRule != null) 'advancementRule': advancementRule!.toMap(),
      };
}

class PointsConfig {
  final int win;
  final int tie;
  final int noResult;
  final int loss;

  const PointsConfig({
    this.win = 2,
    this.tie = 1,
    this.noResult = 1,
    this.loss = 0,
  });

  factory PointsConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PointsConfig();
    return PointsConfig(
      win: (map['win'] as num?)?.toInt() ?? 2,
      tie: (map['tie'] as num?)?.toInt() ?? 1,
      noResult: (map['noResult'] as num?)?.toInt() ??
          (map['no_result'] as num?)?.toInt() ??
          1,
      loss: (map['loss'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'win': win,
        'tie': tie,
        'noResult': noResult,
        'loss': loss,
      };
}

class TieBreakersConfig {
  final List<String> order;

  const TieBreakersConfig({
    this.order = const ['POINTS', 'NET_RUN_RATE', 'HEAD_TO_HEAD', 'TOTAL_WINS'],
  });

  factory TieBreakersConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const TieBreakersConfig();
    final rawOrder = map['order'] as List<dynamic>?;
    return TieBreakersConfig(
      order: rawOrder != null
          ? rawOrder.map((e) => e.toString().toUpperCase()).toList()
          : const ['POINTS', 'NET_RUN_RATE', 'HEAD_TO_HEAD', 'TOTAL_WINS'],
    );
  }

  Map<String, dynamic> toMap() => {
        'order': order,
      };
}

class TournamentConfig {
  final String version;
  final MetaConfig meta;
  final MatchRulesConfig matchRules;
  final List<TournamentStageConfig> stages;
  final PointsConfig pointsConfig;
  final TieBreakersConfig tieBreakers;

  const TournamentConfig({
    this.version = '1.0.0',
    this.meta = const MetaConfig(),
    this.matchRules = const MatchRulesConfig(),
    this.stages = const [],
    this.pointsConfig = const PointsConfig(),
    this.tieBreakers = const TieBreakersConfig(),
  });

  TournamentStageConfig? get groupsStage {
    for (final s in stages) {
      if (s.isGroupsStage) return s;
    }
    return null;
  }

  TournamentStageConfig? get knockoutStage {
    for (final s in stages) {
      if (s.isKnockoutStage) return s;
    }
    return null;
  }

  factory TournamentConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const TournamentConfig();

    final rawStages = map['stages'] as List<dynamic>?;
    final stagesList = rawStages != null
        ? (rawStages
            .map((s) => TournamentStageConfig.fromMap(s as Map<String, dynamic>?))
            .toList()
          ..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder)))
        : <TournamentStageConfig>[];

    return TournamentConfig(
      version: map['version'] as String? ?? '1.0.0',
      meta: MetaConfig.fromMap(map['meta'] as Map<String, dynamic>?),
      matchRules: MatchRulesConfig.fromMap(map['matchRules'] as Map<String, dynamic>? ??
          map['match_rules'] as Map<String, dynamic>?),
      stages: stagesList,
      pointsConfig: PointsConfig.fromMap(map['pointsConfig'] as Map<String, dynamic>? ??
          map['points_config'] as Map<String, dynamic>?),
      tieBreakers: TieBreakersConfig.fromMap(map['tieBreakers'] as Map<String, dynamic>? ??
          map['tie_breakers'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toMap() => {
        'version': version,
        'meta': meta.toMap(),
        'matchRules': matchRules.toMap(),
        'stages': stages.map((s) => s.toMap()).toList(),
        'pointsConfig': pointsConfig.toMap(),
        'tieBreakers': tieBreakers.toMap(),
      };
}

// =============================================================================
// UI PRESENTATION CONFIGURATION (DYNAMIC LAYOUT & VISUAL STYLING)
// =============================================================================

class GroupThemeConfig {
  final String name;
  final String primary;

  const GroupThemeConfig({
    required this.name,
    this.primary = '#06B6D4',
  });

  Color get primaryColor => parseHexColor(primary, fallback: const Color(0xFF06B6D4));

  factory GroupThemeConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const GroupThemeConfig(name: 'Group', primary: '#06B6D4');
    return GroupThemeConfig(
      name: map['name'] as String? ?? 'Group',
      primary: map['primary'] as String? ?? map['primaryColor'] as String? ?? '#06B6D4',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'primary': primary,
      };
}

class QualifierBadgeConfig {
  final int rankCutoff;
  final String label;
  final String description;
  final String color;

  const QualifierBadgeConfig({
    this.rankCutoff = 2,
    this.label = 'Q',
    this.description = 'Advance to Semi-Finals',
    this.color = '#10B981',
  });

  Color get badgeColor => parseHexColor(color, fallback: const Color(0xFF10B981));

  factory QualifierBadgeConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const QualifierBadgeConfig();
    return QualifierBadgeConfig(
      rankCutoff: (map['rankCutoff'] as num?)?.toInt() ??
          (map['rank_cutoff'] as num?)?.toInt() ??
          2,
      label: map['label'] as String? ?? 'Q',
      description: map['description'] as String? ?? 'Advance to Semi-Finals',
      color: map['color'] as String? ?? '#10B981',
    );
  }

  Map<String, dynamic> toMap() => {
        'rankCutoff': rankCutoff,
        'label': label,
        'description': description,
        'color': color,
      };
}

class UiPresentationConfig {
  final String standingsLayout; // 'GROUPED_TABS', 'SINGLE_LEAGUE', 'BRACKET_ONLY'
  final bool showNrr;
  final String scoringUiMode; // 'STANDARD_CRICKET', 'BOX_CRICKET', 'LAST_MAN_STANDING'
  final Map<String, GroupThemeConfig> groupThemes;
  final List<QualifierBadgeConfig> qualifierBadges;

  const UiPresentationConfig({
    this.standingsLayout = 'GROUPED_TABS',
    this.showNrr = true,
    this.scoringUiMode = 'STANDARD_CRICKET',
    this.groupThemes = const {},
    this.qualifierBadges = const [QualifierBadgeConfig()],
  });

  bool get isGroupedTabs => standingsLayout == 'GROUPED_TABS';
  bool get isSingleLeague => standingsLayout == 'SINGLE_LEAGUE';

  GroupThemeConfig getGroupTheme(String groupId, {String? defaultName, String? defaultColorHex}) {
    final key = groupId.trim().toUpperCase();
    if (groupThemes.containsKey(key)) {
      return groupThemes[key]!;
    }
    // Fallback default theme by group letter
    final fallbackColor = key == 'A'
        ? '#06B6D4'
        : (key == 'B' ? '#A855F7' : (defaultColorHex ?? '#F59E0B'));
    return GroupThemeConfig(
      name: defaultName ?? 'Group $key',
      primary: fallbackColor,
    );
  }

  QualifierBadgeConfig? getBadgeForPosition(int position) {
    for (final badge in qualifierBadges) {
      if (position <= badge.rankCutoff) {
        return badge;
      }
    }
    return null;
  }

  factory UiPresentationConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const UiPresentationConfig();

    final rawThemes = map['groupThemes'] as Map<String, dynamic>? ??
        map['group_themes'] as Map<String, dynamic>?;
    final themesMap = <String, GroupThemeConfig>{};
    if (rawThemes != null) {
      rawThemes.forEach((key, val) {
        themesMap[key.trim().toUpperCase()] =
            GroupThemeConfig.fromMap(val as Map<String, dynamic>?);
      });
    }

    final rawBadges = map['qualifierBadges'] as List<dynamic>? ??
        map['qualifier_badges'] as List<dynamic>?;
    final badgesList = rawBadges != null
        ? rawBadges
            .map((b) => QualifierBadgeConfig.fromMap(b as Map<String, dynamic>?))
            .toList()
        : const [QualifierBadgeConfig()];

    return UiPresentationConfig(
      standingsLayout: map['standingsLayout'] as String? ??
          map['standings_layout'] as String? ??
          'GROUPED_TABS',
      showNrr: map['showNrr'] as bool? ?? map['show_nrr'] as bool? ?? true,
      scoringUiMode: map['scoringUiMode'] as String? ??
          map['scoring_ui_mode'] as String? ??
          'STANDARD_CRICKET',
      groupThemes: themesMap,
      qualifierBadges: badgesList,
    );
  }

  Map<String, dynamic> toMap() => {
        'standingsLayout': standingsLayout,
        'showNrr': showNrr,
        'scoringUiMode': scoringUiMode,
        'groupThemes': groupThemes.map((k, v) => MapEntry(k, v.toMap())),
        'qualifierBadges': qualifierBadges.map((b) => b.toMap()).toList(),
      };
}

// =============================================================================
// COLOR PARSER UTILITY
// =============================================================================
Color parseHexColor(String? hexString, {Color fallback = const Color(0xFF00E5FF)}) {
  if (hexString == null || hexString.trim().isEmpty) return fallback;
  final buffer = StringBuffer();
  String cleaned = hexString.replaceFirst('#', '').trim();
  if (cleaned.length == 6) {
    buffer.write('ff');
    buffer.write(cleaned);
  } else if (cleaned.length == 8) {
    buffer.write(cleaned);
  } else {
    return fallback;
  }
  final value = int.tryParse(buffer.toString(), radix: 16);
  return value != null ? Color(value) : fallback;
}
