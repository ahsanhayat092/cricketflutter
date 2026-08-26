import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wpl_cricket_app/features/auth/services/scorer_security_service.dart';
import 'package:wpl_cricket_app/features/scoring/models/tournament_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScorerSecurityService Tests', () {
    late ScorerSecurityService securityService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      securityService = ScorerSecurityService();
    });

    const tournamentA = TournamentModel(
      id: 'tour_a',
      name: 'Tournament Alpha',
      shortName: 'ALPHA',
      scorerPin: '8492',
    );

    const tournamentB = TournamentModel(
      id: 'tour_b',
      name: 'Tournament Beta',
      shortName: 'BETA',
      scorerPin: '3157',
    );

    test('Strict PIN verification without backdoors', () async {
      // 1. Incorrect PIN
      final resFail = await securityService.verifyTournamentPin(
        tournament: tournamentA,
        enteredPin: '1234', // Default backdoors fail if tournament has distinct PIN
      );
      expect(resFail.isSuccess, isFalse);
      expect(resFail.isInvalidPin, isTrue);
      expect(resFail.remainingAttempts, 4);

      // 2. Correct PIN
      final resSuccess = await securityService.verifyTournamentPin(
        tournament: tournamentA,
        enteredPin: '8492',
      );
      expect(resSuccess.isSuccess, isTrue);
      expect(resSuccess.isInvalidPin, isFalse);
    });

    test('Explicit Tournament Scoping: Unlocking Tournament A keeps Tournament B locked', () async {
      // Unlock Tournament A
      final resA = await securityService.verifyTournamentPin(
        tournament: tournamentA,
        enteredPin: '8492',
      );
      expect(resA.isSuccess, isTrue);

      final unlockedIds = await securityService.getUnlockedTournamentIds();
      expect(unlockedIds.contains('tour_a'), isTrue);
      expect(unlockedIds.contains('tour_b'), isFalse);
      expect(await securityService.isTournamentUnlocked('tour_a'), isTrue);
      expect(await securityService.isTournamentUnlocked('tour_b'), isFalse);
    });

    test('Anti-Brute Force: 5 consecutive failed attempts trigger 5-minute lockout', () async {
      // 4 failed attempts
      for (int i = 1; i <= 4; i++) {
        final res = await securityService.verifyTournamentPin(
          tournament: tournamentA,
          enteredPin: '000$i',
        );
        expect(res.isInvalidPin, isTrue);
        expect(res.remainingAttempts, 5 - i);
      }

      expect(await securityService.isTournamentLockedOut('tour_a'), isFalse);

      // 5th failed attempt -> Lockout triggered
      final res5 = await securityService.verifyTournamentPin(
        tournament: tournamentA,
        enteredPin: '9999',
      );
      expect(res5.isLockedOut, isTrue);
      expect(res5.remainingLockout.inMinutes, greaterThanOrEqualTo(4));

      expect(await securityService.isTournamentLockedOut('tour_a'), isTrue);

      // Subsequent attempt rejected immediately due to lockout
      final resBlocked = await securityService.verifyTournamentPin(
        tournament: tournamentA,
        enteredPin: '8492', // Even correct PIN blocked during lockout
      );
      expect(resBlocked.isLockedOut, isTrue);
    });

    test('Successful verification resets failed attempts counter', () async {
      // 3 failed attempts
      await securityService.verifyTournamentPin(tournament: tournamentA, enteredPin: '1111');
      await securityService.verifyTournamentPin(tournament: tournamentA, enteredPin: '2222');
      await securityService.verifyTournamentPin(tournament: tournamentA, enteredPin: '3333');
      expect(await securityService.getFailedAttempts('tour_a'), 3);

      // Correct PIN entered
      final res = await securityService.verifyTournamentPin(tournament: tournamentA, enteredPin: '8492');
      expect(res.isSuccess, isTrue);
      expect(await securityService.getFailedAttempts('tour_a'), 0);
    });

    test('Locking / clearing tournament removes it from unlocked IDs', () async {
      await securityService.unlockTournament('tour_a');
      await securityService.unlockTournament('tour_b');

      var unlocked = await securityService.getUnlockedTournamentIds();
      expect(unlocked.length, 2);

      await securityService.lockTournament('tour_a');
      unlocked = await securityService.getUnlockedTournamentIds();
      expect(unlocked.contains('tour_a'), isFalse);
      expect(unlocked.contains('tour_b'), isTrue);

      await securityService.clearAllUnlocked();
      unlocked = await securityService.getUnlockedTournamentIds();
      expect(unlocked.isEmpty, isTrue);
    });
  });
}
