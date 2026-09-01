import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'offline_scoring_storage.dart';
import 'scoring_sync_service.dart';
import '../models/match_model.dart';
import '../models/innings_model.dart';
import '../models/batting_score.dart';
import '../models/bowling_score.dart';

enum SyncStatus {
  synced,
  syncing,
  offline,
  error,
}

class OfflineSyncManager extends ChangeNotifier {
  final OfflineScoringStorage _storage;
  final ScoringSyncService _syncService;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  SyncStatus _status = SyncStatus.synced;
  String? _lastError;
  String? _lastErrorStackTrace;
  String? _lastFailedActionInfo;
  DateTime? _lastErrorTime;
  int _pendingCount = 0;
  DateTime? _lastSyncTime;
  bool _isDisposed = false;
  Timer? _retryTimer;

  OfflineSyncManager({
    required OfflineScoringStorage storage,
    required ScoringSyncService syncService,
    Connectivity? connectivity,
  })  : _storage = storage,
        _syncService = syncService,
        _connectivity = connectivity ?? Connectivity() {
    _initConnectivityListener();
    _refreshPendingCount();
  }

  SyncStatus get status => _status;
  String? get lastError => _lastError;
  String? get lastErrorStackTrace => _lastErrorStackTrace;
  String? get lastFailedActionInfo => _lastFailedActionInfo;
  DateTime? get lastErrorTime => _lastErrorTime;
  int get pendingCount => _pendingCount;
  DateTime? get lastSyncTime => _lastSyncTime;

  Future<void> _refreshPendingCount() async {
    _pendingCount = await _storage.getPendingCount();
    _lastSyncTime = await _storage.getLastSyncTimestamp();
    notifyListeners();
  }

  void _initConnectivityListener() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) async {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      debugPrint('[OfflineSyncManager] Connectivity changed: $results (Online: $isConnected)');

      if (isConnected) {
        final count = await _storage.getPendingCount();
        _pendingCount = count;
        if (count > 0) {
          syncPendingQueue();
        } else {
          _updateStatus(SyncStatus.synced);
        }
      } else {
        _updateStatus(SyncStatus.offline);
      }
    });

    // Initial check
    checkConnectivityAndSync();
  }

  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true; // Fallback to optimistic
    }
  }

  Future<void> checkConnectivityAndSync() async {
    final online = await isOnline();
    final count = await _storage.getPendingCount();
    _pendingCount = count;

    if (!online) {
      _updateStatus(SyncStatus.offline);
      return;
    }

    if (count > 0) {
      await syncPendingQueue();
    } else {
      _updateStatus(SyncStatus.synced);
    }
  }

  void _updateStatus(SyncStatus newStatus, [String? error]) {
    if (_isDisposed) return;
    _status = newStatus;
    _lastError = error;
    notifyListeners();
  }

  /// Notifies that a new sync action was enqueued locally
  Future<void> onActionEnqueued() async {
    await _refreshPendingCount();
    final online = await isOnline();
    if (online) {
      syncPendingQueue();
    } else {
      _updateStatus(SyncStatus.offline);
    }
  }

  /// Flushes all pending offline scoring mutations to Firestore
  Future<void> syncPendingQueue() async {
    if (_status == SyncStatus.syncing) return;

    final online = await isOnline();
    if (!online) {
      _updateStatus(SyncStatus.offline);
      return;
    }

    final queue = await _storage.getPendingSyncQueue();
    _pendingCount = queue.length;
    if (queue.isEmpty) {
      _updateStatus(SyncStatus.synced);
      return;
    }

    _updateStatus(SyncStatus.syncing);
    debugPrint('[OfflineSyncManager] Starting sync of ${queue.length} pending actions...');

    final Set<String> affectedTournaments = {};

    for (final action in queue) {
      try {
        await _processAction(action);
        await _storage.removeSyncAction(action.id);
        _pendingCount = await _storage.getPendingCount();
        _lastSyncTime = DateTime.now();
        notifyListeners();

        debugPrint('[OfflineSyncManager] Successfully synced action: ${action.id} (${action.type.name})');

        final tourId = action.payload['tournamentId'] as String?;
        if (tourId != null && tourId.isNotEmpty) {
          affectedTournaments.add(tourId);
        }
      } catch (e, stack) {
        debugPrint('[OfflineSyncManager] Failed to sync action ${action.id}: $e\n$stack');
        action.retryCount += 1;
        await _storage.updateSyncAction(action);

        _lastError = e.toString();
        _lastErrorStackTrace = stack.toString();
        _lastFailedActionInfo = 'Action: ${action.type.name} (ID: ${action.id}, Match: ${action.matchId}, Retries: ${action.retryCount})';
        _lastErrorTime = DateTime.now();
        _updateStatus(SyncStatus.error, e.toString());
        _scheduleRetry();
        return;
      }
    }

    // Auto-recalculate standings for affected tournaments
    for (final tourId in affectedTournaments) {
      try {
        await _syncService.recalculateTournamentStandings(tournamentId: tourId);
      } catch (_) {}
    }

    _pendingCount = 0;
    _lastError = null;
    _lastErrorStackTrace = null;
    _lastFailedActionInfo = null;
    _updateStatus(SyncStatus.synced);
    debugPrint('[OfflineSyncManager] All pending actions successfully synced.');
  }

  /// Clears all pending mutations from local offline queue
  Future<void> clearPendingQueue({String? matchId}) async {
    await _storage.clearAllSyncActions(matchId: matchId);
    await _refreshPendingCount();
    _lastError = null;
    _lastErrorStackTrace = null;
    _lastFailedActionInfo = null;
    _updateStatus(SyncStatus.synced);
    notifyListeners();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 15), () async {
      if (!_isDisposed) {
        final count = await _storage.getPendingCount();
        if (count > 0) {
          syncPendingQueue();
        }
      }
    });
  }

  Future<void> _processAction(SyncAction action) async {
    switch (action.type) {
      case SyncActionType.recordDelivery:
      case SyncActionType.setOpeners:
      case SyncActionType.undoDelivery:
        final matchMap = Map<String, dynamic>.from(action.payload['match'] ?? {});
        final innMap = Map<String, dynamic>.from(action.payload['innings'] ?? {});
        final rawBatting = Map<String, dynamic>.from(action.payload['battingScores'] ?? {});
        final rawBowling = Map<String, dynamic>.from(action.payload['bowlingScores'] ?? {});

        final effectiveMatchId = (matchMap['id'] as String?)?.trim().isNotEmpty == true
            ? (matchMap['id'] as String).trim()
            : action.matchId.trim();
        final effectiveInningsId = (innMap['id'] as String?)?.trim().isNotEmpty == true
            ? (innMap['id'] as String).trim()
            : 'inn_${effectiveMatchId}_${innMap['inningsNumber'] ?? 1}';

        final tourId = (action.payload['tournamentId'] as String?) ??
            (matchMap['tournamentId'] as String?) ??
            (innMap['tournamentId'] as String?) ??
            'main';

        final match = MatchModel.fromMap(effectiveMatchId, matchMap).copyWith(
          tournamentId: tourId,
        );
        final innings = InningsModel.fromMap(effectiveInningsId, innMap).copyWith(
          tournamentId: tourId,
          matchId: effectiveMatchId,
        );
        final Map<String, BattingScore> battingScores = {};
        rawBatting.forEach((k, v) {
          if (k.toString().trim().isNotEmpty && v is Map) {
            final scoreId = (v['id'] as String?)?.trim().isNotEmpty == true
                ? (v['id'] as String).trim()
                : '${effectiveInningsId}_$k';
            final bScore = BattingScore.fromMap(scoreId, Map<String, dynamic>.from(v));
            battingScores[k.toString().trim()] = bScore.copyWith(
              tournamentId: tourId,
              matchId: effectiveMatchId,
            );
          }
        });
        final Map<String, BowlingScore> bowlingScores = {};
        rawBowling.forEach((k, v) {
          if (k.toString().trim().isNotEmpty && v is Map) {
            final scoreId = (v['id'] as String?)?.trim().isNotEmpty == true
                ? (v['id'] as String).trim()
                : '${effectiveInningsId}_$k';
            final boScore = BowlingScore.fromMap(scoreId, Map<String, dynamic>.from(v));
            bowlingScores[k.toString().trim()] = boScore.copyWith(
              tournamentId: tourId,
              matchId: effectiveMatchId,
            );
          }
        });

        await _syncService.recordDeliveryAtomic(
          match: match,
          innings: innings,
          battingScores: battingScores,
          bowlingScores: bowlingScores,
        );
        break;

      case SyncActionType.startMatch:
        await _syncService.startMatch(
          matchId: action.matchId,
          teamAId: action.payload['teamAId'],
          teamBId: action.payload['teamBId'],
          teamAPlayingVI: List<String>.from(action.payload['teamAPlayingVI'] ?? []),
          teamAReserveId: action.payload['teamAReserveId'],
          teamBPlayingVI: List<String>.from(action.payload['teamBPlayingVI'] ?? []),
          teamBReserveId: action.payload['teamBReserveId'],
          tossWinnerId: action.payload['tossWinnerId'] ?? '',
          tossDecision: action.payload['tossDecision'] ?? 'BAT',
          battingTeamId: action.payload['battingTeamId'] ?? '',
          bowlingTeamId: action.payload['bowlingTeamId'] ?? '',
          strikerId: action.payload['strikerId'] ?? '',
          nonStrikerId: action.payload['nonStrikerId'] ?? '',
          bowlerId: action.payload['bowlerId'] ?? '',
        );
        break;

      case SyncActionType.finalizeMatch:
        await _syncService.finalizeMatch(
          matchId: action.matchId,
          winningTeamId: action.payload['winningTeamId'] ?? '',
          resultText: action.payload['resultText'] ?? '',
          playerOfMatchId: action.payload['playerOfMatchId'],
          tournamentId: action.payload['tournamentId'] ?? 'main',
        );
        break;

      case SyncActionType.updateLineup:
        await _syncService.updateMatchLineup(
          matchId: action.matchId,
          teamAPlayingVI: List<String>.from(action.payload['teamAPlayingVI'] ?? []),
          teamAReserveId: action.payload['teamAReserveId'],
          teamBPlayingVI: List<String>.from(action.payload['teamBPlayingVI'] ?? []),
          teamBReserveId: action.payload['teamBReserveId'],
        );
        break;

      case SyncActionType.swapPlayer:
        await _syncService.swapScorecardPlayer(
          matchId: action.matchId,
          inningsId: action.payload['inningsId'] ?? '',
          inningsNumber: action.payload['inningsNumber'] ?? 1,
          oldPlayerId: action.payload['oldPlayerId'] ?? '',
          newPlayerId: action.payload['newPlayerId'] ?? '',
          newPlayerName: action.payload['newPlayerName'] ?? '',
          isBatting: action.payload['isBatting'] ?? true,
        );
        break;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _connectivitySub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
