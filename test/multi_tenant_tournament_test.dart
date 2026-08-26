import 'package:flutter_test/flutter_test.dart';
import 'package:wpl_cricket_app/features/scoring/models/tournament_model.dart';
import 'package:wpl_cricket_app/features/auth/models/tournament_member_model.dart';

void main() {
  group('Multi-Tenant TournamentModel Tests', () {
    test('TournamentModel defaults and backward compatibility with main', () {
      const defaultTournament = TournamentModel(
        name: 'WASA Premier League 2026',
        shortName: 'WPL 2026',
      );

      expect(defaultTournament.id, 'main');
      expect(defaultTournament.slug, 'wasa-2026');
      expect(defaultTournament.formatType, 'TAPE_BALL_INDOOR');
      expect(defaultTournament.oversPerSide, 4);
      expect(defaultTournament.scorerPin, '1234');
      expect(defaultTournament.isPinValid('1234'), isTrue);
      expect(defaultTournament.isPinValid('0000'), isFalse);
      expect(defaultTournament.shareUrl, 'https://wasacricket.vercel.app/t/wasa-2026');
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
      expect(tournament.shareUrl, 'https://wasacricket.vercel.app/t/lahore-cup');

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
}
