import 'package:shared_preferences/shared_preferences.dart';
import '../../scoring/models/tournament_model.dart';

enum PinVerificationStatus {
  success,
  invalidPin,
  lockedOut,
}

class PinVerificationResult {
  final PinVerificationStatus status;
  final String? errorMessage;
  final int remainingAttempts;
  final Duration remainingLockout;
  final TournamentModel? tournament;

  const PinVerificationResult({
    required this.status,
    this.errorMessage,
    this.remainingAttempts = 5,
    this.remainingLockout = Duration.zero,
    this.tournament,
  });

  bool get isSuccess => status == PinVerificationStatus.success;
  bool get isLockedOut => status == PinVerificationStatus.lockedOut;
  bool get isInvalidPin => status == PinVerificationStatus.invalidPin;

  factory PinVerificationResult.success(TournamentModel tournament) =>
      PinVerificationResult(
        status: PinVerificationStatus.success,
        tournament: tournament,
      );

  factory PinVerificationResult.invalidPin({required int remainingAttempts}) =>
      PinVerificationResult(
        status: PinVerificationStatus.invalidPin,
        remainingAttempts: remainingAttempts,
        errorMessage: 'Incorrect PIN. $remainingAttempts attempt${remainingAttempts == 1 ? '' : 's'} remaining.',
      );

  factory PinVerificationResult.lockedOut({required Duration remainingLockout}) =>
      PinVerificationResult(
        status: PinVerificationStatus.lockedOut,
        remainingLockout: remainingLockout,
        remainingAttempts: 0,
        errorMessage:
            'Too many failed attempts. Entry locked for ${_formatDuration(remainingLockout)}.',
      );

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}

class ScorerSecurityService {
  static const int maxFailedAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 5);

  static const String _keyUnlockedIds = 'scorer_unlocked_tournaments';
  static const String _legacyKeyUnlockedIds = 'unlocked_tournament_ids';
  static String _keyFailedAttempts(String tournamentId) => 'scorer_failed_attempts_$tournamentId';
  static String _keyLockoutExpiry(String tournamentId) => 'scorer_lockout_expiry_$tournamentId';

  final SharedPreferences? _prefsInstance;

  ScorerSecurityService({SharedPreferences? prefs}) : _prefsInstance = prefs;

  Future<SharedPreferences> _getPrefs() async {
    if (_prefsInstance != null) return _prefsInstance;
    return await SharedPreferences.getInstance();
  }

  // ==========================================
  // UNLOCKED TOURNAMENTS
  // ==========================================

  /// Get set of tournament IDs explicitly unlocked on this device
  Future<Set<String>> getUnlockedTournamentIds() async {
    final prefs = await _getPrefs();
    final list = prefs.getStringList(_keyUnlockedIds) ??
        prefs.getStringList(_legacyKeyUnlockedIds) ??
        [];
    return list.toSet();
  }

  /// Check if a tournament is unlocked
  Future<bool> isTournamentUnlocked(String tournamentId) async {
    final set = await getUnlockedTournamentIds();
    return set.contains(tournamentId);
  }

  /// Store tournament as unlocked without overwriting previously unlocked ones
  Future<void> unlockTournament(String tournamentId) async {
    final prefs = await _getPrefs();
    final set = await getUnlockedTournamentIds();
    set.add(tournamentId);
    await prefs.setStringList(_keyUnlockedIds, set.toList());
  }

  /// Lock a tournament (remove from unlocked list)
  Future<void> lockTournament(String tournamentId) async {
    final prefs = await _getPrefs();
    final set = await getUnlockedTournamentIds();
    set.remove(tournamentId);
    await prefs.setStringList(_keyUnlockedIds, set.toList());
  }

  /// Lock all tournaments (Scorer Logout)
  Future<void> clearAllUnlocked() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyUnlockedIds);
    await prefs.remove(_legacyKeyUnlockedIds);
  }

  // ==========================================
  // RATE LIMITING & LOCKOUT PROTECTION
  // ==========================================

  /// Check if entry is currently locked out for a tournament
  Future<bool> isTournamentLockedOut(String tournamentId) async {
    final prefs = await _getPrefs();
    final expiryMs = prefs.getInt(_keyLockoutExpiry(tournamentId));
    if (expiryMs == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= expiryMs) {
      // Lockout has expired: auto-reset
      await resetFailedAttempts(tournamentId);
      return false;
    }
    return true;
  }

  /// Get remaining lockout duration for a tournament
  Future<Duration> getRemainingLockout(String tournamentId) async {
    final prefs = await _getPrefs();
    final expiryMs = prefs.getInt(_keyLockoutExpiry(tournamentId));
    if (expiryMs == null) return Duration.zero;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= expiryMs) {
      await resetFailedAttempts(tournamentId);
      return Duration.zero;
    }
    return Duration(milliseconds: expiryMs - now);
  }

  /// Get number of failed attempts for a tournament
  Future<int> getFailedAttempts(String tournamentId) async {
    final isLocked = await isTournamentLockedOut(tournamentId);
    if (isLocked) return maxFailedAttempts;

    final prefs = await _getPrefs();
    return prefs.getInt(_keyFailedAttempts(tournamentId)) ?? 0;
  }

  /// Reset failed attempts and lockout for a tournament
  Future<void> resetFailedAttempts(String tournamentId) async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyFailedAttempts(tournamentId));
    await prefs.remove(_keyLockoutExpiry(tournamentId));
  }

  /// Verify entered PIN strictly against selected tournament (with rate limiting & lockout)
  Future<PinVerificationResult> verifyTournamentPin({
    required TournamentModel tournament,
    required String enteredPin,
  }) async {
    final tournamentId = tournament.id;

    // 1. Check if currently locked out
    final isLocked = await isTournamentLockedOut(tournamentId);
    if (isLocked) {
      final remaining = await getRemainingLockout(tournamentId);
      return PinVerificationResult.lockedOut(remainingLockout: remaining);
    }

    final cleanEntered = enteredPin.trim();
    final cleanExpected = tournament.scorerPin.trim();

    // 2. PIN Match check (Strict: No hardcoded backdoors)
    if (cleanEntered.isNotEmpty && cleanEntered == cleanExpected) {
      // Success: Reset failed attempts & unlock tournament
      await resetFailedAttempts(tournamentId);
      await unlockTournament(tournamentId);
      return PinVerificationResult.success(tournament);
    }

    // 3. Invalid PIN: Record failed attempt
    final prefs = await _getPrefs();
    final currentAttempts = (prefs.getInt(_keyFailedAttempts(tournamentId)) ?? 0) + 1;
    await prefs.setInt(_keyFailedAttempts(tournamentId), currentAttempts);

    if (currentAttempts >= maxFailedAttempts) {
      // Trigger 5-minute lockout
      final expiryTime = DateTime.now().add(lockoutDuration).millisecondsSinceEpoch;
      await prefs.setInt(_keyLockoutExpiry(tournamentId), expiryTime);
      return PinVerificationResult.lockedOut(remainingLockout: lockoutDuration);
    } else {
      final remaining = maxFailedAttempts - currentAttempts;
      return PinVerificationResult.invalidPin(remainingAttempts: remaining);
    }
  }
}
