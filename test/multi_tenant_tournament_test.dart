import 'package:flutter_test/flutter_test.dart';
import 'package:wpl_cricket_app/features/scoring/models/tournament_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/team_model.dart';
import 'package:wpl_cricket_app/features/scoring/data/firebase_scoring_service.dart';
import 'package:wpl_cricket_app/features/auth/models/tournament_member_model.dart';

void main() {
  group('Multi-Tenant TournamentModel Tests', () {
    test('TournamentModel defaults and backward compatibility with main', () {
      const defaultTournament = TournamentModel(
        name: 'Cricket Tournament',
        shortName: 'CRIC',
      );

      expect(defaultTournament.id, 'main');
      expect(defaultTournament.slug, 'cricket-tournament');
      expect(defaultTournament.formatType, 'TAPE_BALL_INDOOR');
      expect(defaultTournament.oversPerSide, 4);
      expect(defaultTournament.scorerPin, '1234');
      expect(defaultTournament.isPinValid('1234'), isTrue);
      expect(defaultTournament.isPinValid('0000'), isFalse);
      expect(defaultTournament.shareUrl, 'https://pitchpe.vercel.app/t/cricket-tournament');
    });

    test('TournamentModel serialization and deserialization from Firestore Map', () {
      final map = {
        'name': 'Lahore Tapeball Championship',
        'shortName': 'LTC 2026',
        'slug': 'lahore-cup',
        'formatType': 'T10',
        'oversPerSide': 10,
        'maxOverPerBowler': 2,
        'playersPerTeam': 11,
        'maxWickets': 10,
        'allowLastManStanding': false,
        'scorerPin': '5678',
        'ownerId': 'user_owner_123',
        'branding': {
          'primaryColor': '#1E293B',
          'accentColor': '#10B981',
        },
        'venueName': 'Gaddafi Stadium Ground 2',
        'status': 'LIVE',
      };

      final tournament = TournamentModel.fromMap(map, id: 'tour_ltc_01');

      expect(tournament.id, 'tour_ltc_01');
      expect(tournament.name, 'Lahore Tapeball Championship');
      expect(tournament.shortName, 'LTC 2026');
      expect(tournament.slug, 'lahore-cup');
      expect(tournament.formatType, 'T10');
      expect(tournament.oversPerSide, 10);
      expect(tournament.isPinValid('5678'), isTrue);
      expect(tournament.isPinValid(' 5678 '), isTrue);
      expect(tournament.isPinValid('1234'), isFalse);
      expect(tournament.shareUrl, 'https://pitchpe.vercel.app/t/lahore-cup');

      final serialized = tournament.toMap();
      expect(serialized['name'], 'Lahore Tapeball Championship');
      expect(serialized['scorerPin'], '5678');
      expect(serialized['slug'], 'lahore-cup');
    });
  });

  group('TournamentMemberModel RBAC & Permissions Tests', () {
    test('TournamentMemberModel roles and permission helpers', () {
      const ownerMember = TournamentMemberModel(
        id: 'main_owner@wasa.pk',
        tournamentId: 'main',
        userId: 'uid_1',
        userEmail: 'owner@wasa.pk',
        userName: 'Ahsan Hayat',
        role: 'OWNER',
      );

      expect(ownerMember.isOwner, isTrue);
      expect(ownerMember.isAdmin, isFalse);
      expect(ownerMember.isScorer, isFalse);
      expect(ownerMember.canManage, isTrue);
      expect(ownerMember.canScore, isTrue);

      const adminMember = TournamentMemberModel(
        id: 'main_admin@wasa.pk',
        tournamentId: 'main',
        userId: 'uid_2',
        userEmail: 'admin@wasa.pk',
        userName: 'Admin User',
        role: 'ADMIN',
      );

      expect(adminMember.isAdmin, isTrue);
      expect(adminMember.canManage, isTrue);
      expect(adminMember.canScore, isTrue);

      const scorerMember = TournamentMemberModel(
        id: 'main_scorer@wasa.pk',
        tournamentId: 'main',
        userId: 'uid_3',
        userEmail: 'scorer@wasa.pk',
        userName: 'Ground Scorer',
        role: 'SCORER',
      );

      expect(scorerMember.isScorer, isTrue);
      expect(scorerMember.canManage, isFalse);
      expect(scorerMember.canScore, isTrue);
    });

    test('TournamentRoleX enum serialization and display names', () {
      expect(TournamentRole.owner.toFirestoreString(), 'OWNER');
      expect(TournamentRole.admin.toFirestoreString(), 'ADMIN');
      expect(TournamentRole.scorer.toFirestoreString(), 'SCORER');

      expect(TournamentRoleX.fromFirestoreString('OWNER'), TournamentRole.owner);
      expect(TournamentRoleX.fromFirestoreString('ADMIN'), TournamentRole.admin);
      expect(TournamentRoleX.fromFirestoreString('SCORER'), TournamentRole.scorer);
      expect(TournamentRoleX.fromFirestoreString(null), TournamentRole.scorer);
    });
  });

  group('Team Deduplication Tests', () {
    test('deduplicateTeams eliminates duplicates by both ID and normalized Name', () {
      final directTeams = [
        const TeamModel(
          id: 'direct_team_1',
          tournamentId: 't1',
          name: 'Avengers XI',
          shortName: 'AVG',
        ),
        const TeamModel(
          id: 'direct_team_2',
          tournamentId: 't1',
          name: 'Stallions Cricket Club',
          shortName: 'SCC',
        ),
      ];

      final membershipTeams = [
        // Duplicate by normalized name with different ID (membership record fallback)
        const TeamModel(
          id: 'membership_team_mem123',
          tournamentId: 't1',
          name: '  avengers xi  ',
          shortName: 'AVG',
        ),
        // Duplicate by exact ID
        const TeamModel(
          id: 'direct_team_2',
          tournamentId: 't1',
          name: 'Stallions Cricket Club',
          shortName: 'SCC',
        ),
        // Unique new team
        const TeamModel(
          id: 'membership_team_3',
          tournamentId: 't1',
          name: 'Lions CC',
          shortName: 'LCC',
        ),
      ];

      final deduplicated = FirebaseScoringService.deduplicateTeams(directTeams, membershipTeams);

      expect(deduplicated.length, 3);
      expect(deduplicated.map((t) => t.id).toList(), [
        'direct_team_1',
        'direct_team_2',
        'membership_team_3',
      ]);
      expect(deduplicated.map((t) => t.name).toList(), [
        'Avengers XI',
        'Stallions Cricket Club',
        'Lions CC',
      ]);
    });
  });
}
