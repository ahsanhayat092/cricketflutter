enum ExtraType {
  none,
  wide,
  noBall,
  bye,
  legBye,
  penalty,
}

enum WicketType {
  bowled,
  caught,
  runOutStriker,
  runOutNonStriker,
  stumped,
  lbw,
  hitWicket,
  retiredHurt,
}

class BallDeliveryInput {
  final int runsOffBat;
  final ExtraType extraType;
  final int extraRuns;
  final bool isWicket;
  final WicketType? wicketType;
  final String? outBatsmanId;
  final String? newBatsmanId;
  final String? dismissalDescription;

  const BallDeliveryInput({
    this.runsOffBat = 0,
    this.extraType = ExtraType.none,
    this.extraRuns = 0,
    this.isWicket = false,
    this.wicketType,
    this.outBatsmanId,
    this.newBatsmanId,
    this.dismissalDescription,
  });

  bool get isWide => extraType == ExtraType.wide;
  bool get isNoBall => extraType == ExtraType.noBall;
  bool get isBye => extraType == ExtraType.bye;
  bool get isLegBye => extraType == ExtraType.legBye;
  bool get isPenalty => extraType == ExtraType.penalty;

  /// In tape-ball cricket, wide and no-ball are illegal deliveries and don't increment the legal ball count.
  bool get isLegalBall => !isWide && !isNoBall;

  /// Total runs produced by this delivery
  int get totalRuns => runsOffBat + extraRuns;

  /// Display symbol for the delivery reel (e.g. "4", "6", "W", "•", "Wd", "Nb+4")
  String get displaySymbol {
    if (isWicket) {
      if (runsOffBat > 0) return 'W+$runsOffBat';
      if (extraRuns > 0) return 'W+${extraType.name.toUpperCase()}';
      return 'W';
    }
    if (isWide) {
      final extraTotal = 1 + runsOffBat; // wide standard 1 run + any extra byes/runs
      return extraTotal > 1 ? 'Wd+$extraTotal' : 'Wd';
    }
    if (isNoBall) {
      return runsOffBat > 0 ? 'Nb+$runsOffBat' : 'Nb';
    }
    if (isBye) {
      return extraRuns > 0 ? 'B+$extraRuns' : 'B';
    }
    if (isLegBye) {
      return extraRuns > 0 ? 'Lb+$extraRuns' : 'Lb';
    }
    if (runsOffBat == 0) return '•';
    return '$runsOffBat';
  }
}
