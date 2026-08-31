import 'package:cloud_firestore/cloud_firestore.dart';
import '../../scoring/models/team_model.dart';

typedef Standing = StandingModel;

class StandingModel {
  final String id;
  final String tournamentId;
  final String teamId;
  final int played;
  final int won;
  final int lost;
  final int tied;
  final int noResult;
  final int points;
  final int runsFor;
  final int ballsFor;
  final int runsAgainst;
  final int ballsAgainst;
  final double nrr;
  final int position;
  final bool qualified;
  final int adminTiebreak;
  final List<String> form;
  final String? teamName;
  final String? shortName;
  final String? logoUrl;
  final String? updatedAt;

  const StandingModel({
    this.id = '',
    this.tournamentId = 'main',
    required this.teamId,
    this.played = 0,
    this.won = 0,
    this.lost = 0,
    this.tied = 0,
    this.noResult = 0,
    this.points = 0,
    this.runsFor = 0,
    this.ballsFor = 0,
    this.runsAgainst = 0,
    this.ballsAgainst = 0,
    this.nrr = 0.0,
    this.position = 1,
    this.qualified = false,
    this.adminTiebreak = 0,
    this.form = const [],
    this.teamName,
    this.shortName,
    this.logoUrl,
    this.updatedAt,
  });

  String get nrrFormatted {
    if (nrr > 0) return '+${nrr.toStringAsFixed(3)}';
    return nrr.toStringAsFixed(3);
  }

  factory StandingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return StandingModel.fromMap(doc.id, data);
  }

  factory StandingModel.fromMap(String docId, Map<String, dynamic>? data) {
    if (data == null) {
      return StandingModel(id: docId, teamId: docId);
    }

    final rawForm = data['form'];
    List<String> formList = [];
    if (rawForm is List) {
      formList = rawForm.map((e) => e.toString().toUpperCase()).toList();
    } else if (rawForm is String) {
      formList = rawForm.split(',').map((e) => e.trim().toUpperCase()).where((e) => e.isNotEmpty).toList();
    }

    final rawTeamName = (data['teamName'] as String?) ??
        (data['team_name'] as String?) ??
        (data['name'] as String?);
    final rawShortName = (data['teamShortName'] as String?) ??
        (data['shortName'] as String?) ??
        (data['team_short_name'] as String?) ??
        (data['code'] as String?);
    final rawLogoUrl = (data['teamLogoUrl'] as String?) ??
        (data['logoUrl'] as String?) ??
        (data['team_logo_url'] as String?) ??
        (data['logo'] as String?);

    return StandingModel(
      id: docId,
      tournamentId: data['tournamentId'] as String? ?? 'main',
      teamId: data['teamId'] as String? ?? docId,
      played: (data['played'] as num?)?.toInt() ?? 0,
      won: (data['won'] as num?)?.toInt() ?? 0,
      lost: (data['lost'] as num?)?.toInt() ?? 0,
      tied: (data['tied'] as num?)?.toInt() ?? 0,
      noResult: (data['noResult'] as num?)?.toInt() ?? 0,
      points: (data['points'] as num?)?.toInt() ?? 0,
      runsFor: (data['runsFor'] as num?)?.toInt() ?? 0,
      ballsFor: (data['ballsFor'] as num?)?.toInt() ?? 0,
      runsAgainst: (data['runsAgainst'] as num?)?.toInt() ?? 0,
      ballsAgainst: (data['ballsAgainst'] as num?)?.toInt() ?? 0,
      nrr: (data['nrr'] as num?)?.toDouble() ?? (data['netRunRate'] as num?)?.toDouble() ?? 0.0,
      position: (data['position'] as num?)?.toInt() ?? 1,
      qualified: data['qualified'] as bool? ?? false,
      adminTiebreak: (data['adminTiebreak'] as num?)?.toInt() ?? 0,
      form: formList,
      teamName: rawTeamName,
      shortName: rawShortName,
      logoUrl: rawLogoUrl,
      updatedAt: data['updatedAt'] as String?,
    );
  }

  factory StandingModel.fromJson(Map<String, dynamic> json) =>
      StandingModel.fromMap(json['teamId'] as String? ?? '', json);

  Map<String, dynamic> toMap() {
    return {
      'tournamentId': tournamentId,
      'teamId': teamId,
      'played': played,
      'won': won,
      'lost': lost,
      'tied': tied,
      'noResult': noResult,
      'points': points,
      'runsFor': runsFor,
      'ballsFor': ballsFor,
      'runsAgainst': runsAgainst,
      'ballsAgainst': ballsAgainst,
      'nrr': nrr,
      'position': position,
      'qualified': qualified,
      'adminTiebreak': adminTiebreak,
      'form': form,
      if (teamName != null) 'teamName': teamName,
      if (shortName != null) 'shortName': shortName,
      if (logoUrl != null) 'logoUrl': logoUrl,
      'updatedAt': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  StandingModel copyWith({
    String? id,
    String? tournamentId,
    String? teamId,
    int? played,
    int? won,
    int? lost,
    int? tied,
    int? noResult,
    int? points,
    int? runsFor,
    int? ballsFor,
    int? runsAgainst,
    int? ballsAgainst,
    double? nrr,
    int? position,
    bool? qualified,
    int? adminTiebreak,
    List<String>? form,
    String? teamName,
    String? shortName,
    String? logoUrl,
    String? updatedAt,
  }) {
    return StandingModel(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      teamId: teamId ?? this.teamId,
      played: played ?? this.played,
      won: won ?? this.won,
      lost: lost ?? this.lost,
      tied: tied ?? this.tied,
      noResult: noResult ?? this.noResult,
      points: points ?? this.points,
      runsFor: runsFor ?? this.runsFor,
      ballsFor: ballsFor ?? this.ballsFor,
      runsAgainst: runsAgainst ?? this.runsAgainst,
      ballsAgainst: ballsAgainst ?? this.ballsAgainst,
      nrr: nrr ?? this.nrr,
      position: position ?? this.position,
      qualified: qualified ?? this.qualified,
      adminTiebreak: adminTiebreak ?? this.adminTiebreak,
      form: form ?? this.form,
      teamName: teamName ?? this.teamName,
      shortName: shortName ?? this.shortName,
      logoUrl: logoUrl ?? this.logoUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StandingWithTeam {
  final StandingModel standing;
  final TeamModel? team;

  const StandingWithTeam({
    required this.standing,
    this.team,
  });

  String get teamName {
    if (team != null && team!.name.isNotEmpty && !team!.name.startsWith('Team ')) {
      return team!.name;
    }
    if (standing.teamName != null && standing.teamName!.isNotEmpty) {
      return standing.teamName!;
    }
    if (team?.name != null && team!.name.isNotEmpty) {
      return team!.name;
    }
    final rawId = standing.teamId;
    return 'Team ${rawId.length > 6 ? rawId.substring(0, 6) : rawId}';
  }

  String get shortName {
    if (team != null &&
        team!.shortName.isNotEmpty &&
        team!.shortName != team!.id.toUpperCase() &&
        team!.shortName.length <= 6) {
      return team!.shortName;
    }
    if (standing.shortName != null &&
        standing.shortName!.isNotEmpty &&
        standing.shortName!.length <= 6) {
      return standing.shortName!;
    }
    final name = (team != null && team!.name.isNotEmpty) ? team!.name : standing.teamName;
    if (name != null && name.isNotEmpty && !name.startsWith('Team ')) {
      return _deriveShortName(name);
    }
    if (standing.teamId.length > 4) {
      return standing.teamId.substring(0, 3).toUpperCase();
    }
    return standing.teamId.toUpperCase();
  }

  String get logoUrl {
    if (team != null && team!.formattedLogoUrl.isNotEmpty) {
      return team!.formattedLogoUrl;
    }
    if (standing.logoUrl != null && standing.logoUrl!.isNotEmpty) {
      return standing.logoUrl!;
    }
    return '';
  }

  static String _deriveShortName(String name) {
    final clean = name.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 3) {
      return '${words[0][0]}${words[1][0]}${words[2][0]}'.toUpperCase();
    } else if (words.length == 2) {
      if (words[0].toLowerCase() == 'team' && words[1].length >= 3) {
        return words[1].substring(0, 3).toUpperCase();
      }
      return '${words[0].substring(0, 1)}${words[1].substring(0, min(2, words[1].length))}'.toUpperCase();
    } else if (words.length == 1) {
      return words[0].length >= 3 ? words[0].substring(0, 3).toUpperCase() : words[0].toUpperCase();
    }
    return 'TBD';
  }

  static int min(int a, int b) => a < b ? a : b;
}

class TeamStanding {
  final String teamId;
  final String teamName;
  final String shortName;
  final String logoUrl;
  final int played;
  final int won;
  final int lost;
  final int tied;
  final int noResult;
  final int points;
  final double netRunRate;

  const TeamStanding({
    required this.teamId,
    required this.teamName,
    required this.shortName,
    this.logoUrl = '',
    this.played = 0,
    this.won = 0,
    this.lost = 0,
    this.tied = 0,
    this.noResult = 0,
    this.points = 0,
    this.netRunRate = 0.0,
  });
}
