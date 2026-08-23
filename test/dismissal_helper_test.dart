import 'package:flutter_test/flutter_test.dart';
import 'package:wpl_cricket_app/core/utils/dismissal_helper.dart';

void main() {
  group('Dismissal Helper Tests (formatDismissalText)', () {
    test('Formats Bowled correctly', () {
      final text = formatDismissalText(
        dismissalType: 'bowled',
        bowlerName: 'Shaheen Afridi',
      );
      expect(text, equals('b Shaheen Afridi'));
    });

    test('Formats Caught by Fielder correctly', () {
      final text = formatDismissalText(
        dismissalType: 'caught',
        bowlerName: 'Shaheen Afridi',
        catcherName: 'Babar Azam',
      );
      expect(text, equals('c Babar Azam b Shaheen Afridi'));
    });

    test('Formats Caught & Bowled correctly with flag', () {
      final text = formatDismissalText(
        dismissalType: 'caught',
        bowlerName: 'Shaheen Afridi',
        isCaughtAndBowled: true,
      );
      expect(text, equals('c & b Shaheen Afridi'));
    });

    test('Formats Caught & Bowled correctly when catcher matches bowler', () {
      final text = formatDismissalText(
        dismissalType: 'caught',
        bowlerName: 'Shaheen Afridi',
        catcherName: 'Shaheen Afridi',
      );
      expect(text, equals('c & b Shaheen Afridi'));
    });

    test('Formats LBW correctly', () {
      final text = formatDismissalText(
        dismissalType: 'lbw',
        bowlerName: 'Haris Rauf',
      );
      expect(text, equals('lbw b Haris Rauf'));
    });

    test('Formats Stumped with Wicketkeeper correctly', () {
      final text = formatDismissalText(
        dismissalType: 'stumped',
        bowlerName: 'Shadab Khan',
        catcherName: 'Mohammad Rizwan',
      );
      expect(text, equals('st Mohammad Rizwan b Shadab Khan'));
    });

    test('Formats Stumped without keeper correctly', () {
      final text = formatDismissalText(
        dismissalType: 'stumped',
        bowlerName: 'Shadab Khan',
      );
      expect(text, equals('st b Shadab Khan'));
    });

    test('Formats Run Out with Fielder correctly', () {
      final text = formatDismissalText(
        dismissalType: 'run out',
        bowlerName: 'Naseem Shah',
        catcherName: 'Fakhar Zaman',
      );
      expect(text, equals('run out (Fakhar Zaman)'));
    });

    test('Formats Run Out without Fielder correctly', () {
      final text = formatDismissalText(
        dismissalType: 'run out',
        bowlerName: 'Naseem Shah',
      );
      expect(text, equals('run out'));
    });

    test('Formats Hit Wicket correctly', () {
      final text = formatDismissalText(
        dismissalType: 'hit wicket',
        bowlerName: 'Shaheen Afridi',
      );
      expect(text, equals('hit wicket b Shaheen Afridi'));
    });

    test('Formats Retired Hurt correctly', () {
      final text = formatDismissalText(
        dismissalType: 'retired hurt',
        bowlerName: 'Shaheen Afridi',
      );
      expect(text, equals('retired hurt'));
    });
  });

  group('BallContext & Dismissals Enforcement Tests', () {
    test('On No-Ball: only Run Out is allowed', () {
      final dismissals = getAvailableDismissals(BallContext.noBall);
      expect(dismissals, equals(['Run Out']));
    });

    test('On Wide: only Stumped and Run Out are allowed', () {
      final dismissals = getAvailableDismissals(BallContext.wide);
      expect(dismissals, equals(['Stumped', 'Run Out']));
    });

    test('On Bye: only Run Out is allowed', () {
      final dismissals = getAvailableDismissals(BallContext.bye);
      expect(dismissals, equals(['Run Out']));
    });

    test('On Leg-Bye: only Run Out is allowed', () {
      final dismissals = getAvailableDismissals(BallContext.legBye);
      expect(dismissals, equals(['Run Out']));
    });

    test('On Normal Delivery: all standard dismissals are allowed', () {
      final dismissals = getAvailableDismissals(BallContext.normal);
      expect(
        dismissals,
        equals(['Caught', 'Bowled', 'LBW', 'Run Out', 'Stumped', 'Hit Wicket', 'Retired Hurt']),
      );
    });
  });
}
