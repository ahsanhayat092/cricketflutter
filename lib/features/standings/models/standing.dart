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

  String get teamName => team?.name ?? 'Team ${standing.teamId}';
  String get shortName => team?.shortName ?? standing.teamId.toUpperCase();
  String get logoUrl => team?.formattedLogoUrl ?? '';
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
