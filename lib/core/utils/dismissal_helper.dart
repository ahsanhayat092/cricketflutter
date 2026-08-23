/// Context of the delivery being bowled when a dismissal occurs.
enum BallContext { normal, noBall, wide, bye, legBye, freeHit }

/// Returns the strictly allowed cricket dismissals based on delivery context.
/// - No-Ball / Free Hit: Only Run Out allowed
/// - Wide: Only Stumped & Run Out allowed
/// - Bye / Leg-Bye: Only Run Out allowed
/// - Normal: All standard cricket dismissals allowed
List<String> getAvailableDismissals(BallContext context) {
  switch (context) {
    case BallContext.noBall:
    case BallContext.freeHit:
      return ['Run Out']; // Only Run Out allowed on No-Ball or Free Hit

    case BallContext.wide:
      return ['Stumped', 'Run Out']; // Stumped & Run Out on Wide

    case BallContext.bye:
    case BallContext.legBye:
      return ['Run Out']; // Run Out on Byes / Leg-Byes

    case BallContext.normal:
    default:
      return ['Caught', 'Bowled', 'LBW', 'Run Out', 'Stumped', 'Hit Wicket', 'Retired Hurt'];
  }
}

/// Formats standard cricket dismissal descriptions for scorecards and live commentary.
String formatDismissalText({
  required String dismissalType,
  required String bowlerName,
  String? catcherName,
  bool isCaughtAndBowled = false,
}) {
  switch (dismissalType.toLowerCase().trim()) {
    case 'caught':
      if (isCaughtAndBowled || catcherName == bowlerName) {
        return 'c & b $bowlerName';
      } else if (catcherName != null && catcherName.isNotEmpty) {
        return 'c $catcherName b $bowlerName';
      }
      return 'c b $bowlerName';

    case 'bowled':
      return 'b $bowlerName';

    case 'lbw':
      return 'lbw b $bowlerName';

    case 'stumped':
      if (catcherName != null && catcherName.isNotEmpty) {
        return 'st $catcherName b $bowlerName';
      }
      return 'st b $bowlerName';

    case 'run out':
    case 'runoutstriker':
    case 'runoutnonstriker':
      if (catcherName != null && catcherName.isNotEmpty) {
        return 'run out ($catcherName)';
      }
      return 'run out';

    case 'hit wicket':
    case 'hitwicket':
      return 'hit wicket b $bowlerName';

    case 'retired hurt':
    case 'retiredhurt':
      return 'retired hurt';

    default:
      return dismissalType;
  }
}
