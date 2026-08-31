import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wpl_cricket_app/features/auth/models/app_user.dart';
import 'package:wpl_cricket_app/features/auth/models/tournament_member_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/tournament_model.dart';
import 'package:wpl_cricket_app/features/auth/services/scorer_security_service.dart';
import 'package:wpl_cricket_app/features/match_management/providers/tournament_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tourA = TournamentModel(
    id: 'tour_a',
    name: 'Tournament Alpha',
    shortName: 'T-A',
    scorerPin: '1111',
    ownerId: 'owner_1',
    ownerEmail: 'owner1@example.com',
  );

  final tourB = TournamentModel(
    id: 'tour_b',
    name: 'Tournament Beta',
    shortName: 'T-B',
    scorerPin: '2222',
    ownerId: 'owner_2',
    ownerEmail: 'owner2@example.com',
  );

  final tourC = TournamentModel(
    id: 'tour_c',
    name: 'Tournament Gamma',
    shortName: 'T-C',
    scorerPin: '3333',
    ownerId: 'owner_3',
    ownerEmail: 'owner3@example.com',
  );

  final allTournaments = [tourA, tourB, tourC];

  group('Scorer & Admin RBAC Resolution Tests', () {
    test('Platform Admin (ahsanhayat092@gmail.com) has access to all tournaments', () {
      const platformAdmin = AppUser(
        uid: 'admin_uid',
        email: 'ahsanhayat092@gmail.com',
        role: 'admin',
      );

      expect(platformAdmin.isPlatformAdmin, isTrue);
      expect(platformAdmin.isAdmin, isTrue);
      expect(platformAdmin.canScore, isTrue);

      final allowed = getUserScorerTournaments(
        allTournaments: allTournaments,
        user: platformAdmin,
        memberships: [],
        pinUnlockedTournamentIds: {},
      );

      expect(allowed.length, equals(3));
      expect(allowed.map((t) => t.id).toSet(), equals({'tour_a', 'tour_b', 'tour_c'}));
    });

    test('Tournament Owner can only access tournaments they own or are member of', () {
      const owner1 = AppUser(
        uid: 'owner_1',
        email: 'owner1@example.com',
        role: 'scorer',
      );

      final allowed = getUserScorerTournaments(
        allTournaments: allTournaments,
        user: owner1,
        memberships: [],
        pinUnlockedTournamentIds: {},
      );

      expect(allowed.length, equals(1));
      expect(allowed.first.id, equals('tour_a'));
    });

    test('Official Scorer with membership can only access assigned tournaments', () {
      const scorer = AppUser(
        uid: 'scorer_uid',
        email: 'scorer@example.com',
        role: 'scorer',
      );

      final memberships = [
        const TournamentMemberModel(
          id: 'tour_b_scorer@example.com',
          tournamentId: 'tour_b',
          userId: 'scorer_uid',
          userEmail: 'scorer@example.com',
          userName: 'Match Scorer',
          role: 'SCORER',
        ),
      ];

      final allowed = getUserScorerTournaments(
        allTournaments: allTournaments,
        user: scorer,
        memberships: memberships,
        pinUnlockedTournamentIds: {},
      );

      expect(allowed.length, equals(1));
      expect(allowed.first.id, equals('tour_b'));
    });

    test('PIN-Authenticated Scorer only gets access to PIN-unlocked tournament(s)', () {
      const publicScorer = AppUser(
        uid: 'guest',
        email: '',
        role: 'public',
      );

      final allowed = getUserScorerTournaments(
        allTournaments: allTournaments,
        user: publicScorer,
        memberships: [],
        pinUnlockedTournamentIds: {'tour_c'},
      );

      expect(allowed.length, equals(1));
      expect(allowed.first.id, equals('tour_c'));
    });

    test('Unlocking multiple tournaments via PIN accumulates without overwriting', () {
      const publicScorer = AppUser(
        uid: 'guest',
        email: '',
        role: 'public',
      );

      final allowed = getUserScorerTournaments(
        allTournaments: allTournaments,
        user: publicScorer,
        memberships: [],
        pinUnlockedTournamentIds: {'tour_a', 'tour_b'},
      );

      expect(allowed.length, equals(2));
      expect(allowed.map((t) => t.id).toSet(), equals({'tour_a', 'tour_b'}));
    });
  });

  group('ScorerSecurityService PIN Verification and Lockout Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Correct PIN unlocks tournament and stores it in secure storage', () async {
      final prefs = await SharedPreferences.getInstance();
      final securityService = ScorerSecurityService(prefs: prefs);

      final result = await securityService.verifyTournamentPin(
        tournament: tourA,
        enteredPin: '1111',
      );

      expect(result.isSuccess, isTrue);
      final unlocked = await securityService.getUnlockedTournamentIds();
      expect(unlocked.contains('tour_a'), isTrue);
    });

    test('Entering PIN for Tournament B preserves Tournament A in unlocked list', () async {
      final prefs = await SharedPreferences.getInstance();
      final securityService = ScorerSecurityService(prefs: prefs);

      await securityService.verifyTournamentPin(
        tournament: tourA,
        enteredPin: '1111',
      );

      await securityService.verifyTournamentPin(
        tournament: tourB,
        enteredPin: '2222',
      );

      final unlocked = await securityService.getUnlockedTournamentIds();
      expect(unlocked, equals({'tour_a', 'tour_b'}));
    });

    test('Incorrect PIN fails and locks out after 5 failed attempts', () async {
      final prefs = await SharedPreferences.getInstance();
      final securityService = ScorerSecurityService(prefs: prefs);

      for (int i = 1; i <= 4; i++) {
        final result = await securityService.verifyTournamentPin(
          tournament: tourA,
          enteredPin: '9999',
        );
        expect(result.isInvalidPin, isTrue);
        expect(result.remainingAttempts, equals(5 - i));
      }

      final fifthResult = await securityService.verifyTournamentPin(
        tournament: tourA,
        enteredPin: '9999',
      );
      expect(fifthResult.isLockedOut, isTrue);
      expect(fifthResult.remainingLockout.inSeconds, greaterThan(0));

      final isLocked = await securityService.isTournamentLockedOut('tour_a');
      expect(isLocked, isTrue);
    });
  });
}
