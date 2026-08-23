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

    default:
      return dismissalType;
  }
}
