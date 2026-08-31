import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/match_model.dart';
import '../models/innings_model.dart';
import '../models/batting_score.dart';
import '../models/bowling_score.dart';
import '../models/ball_event.dart';
import '../engine/scoring_snapshot.dart';

/// Supported types of sync actions queued when offline
enum SyncActionType {
  recordDelivery,
  startMatch,
  setOpeners,
  undoDelivery,
  finalizeMatch,
  updateLineup,
  swapPlayer,
}

/// Represents a single mutation to be synchronized with Firestore
class SyncAction {
  final String id;
  final String matchId;
  final SyncActionType type;
  final Map<String, dynamic> payload;
  final String createdAt;
  int retryCount;

  SyncAction({
    required this.id,
    required this.matchId,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matchId': matchId,
      'type': type.name,
      'payload': payload,
      'createdAt': createdAt,
      'retryCount': retryCount,
    };
  }

  factory SyncAction.fromMap(Map<String, dynamic> map) {
    return SyncAction(
      id: map['id'] ?? '',
      matchId: map['matchId'] ?? '',
      type: SyncActionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SyncActionType.recordDelivery,
      ),
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      retryCount: map['retryCount'] ?? 0,
    );
  }
}

/// Persistent local cache and offline queue manager using SharedPreferences
class OfflineScoringStorage {
  SharedPreferences? _prefs;

  static const String _keyPrefixMatchState = 'offline_match_state_';
  static const String _keySyncQueue = 'offline_scoring_sync_queue';
  static const String _keyLastSyncTimestamp = 'offline_last_sync_timestamp';

  OfflineScoringStorage({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ---------------------------------------------------------------------------
  // 1. MATCH STATE LOCAL SNAPSHOT PERSISTENCE
  // ---------------------------------------------------------------------------

  /// Saves complete scoring state snapshot for a match locally
  Future<void> saveMatchSnapshot({
    required String matchId,
    required MatchModel match,
    required InningsModel innings,
    required int? firstInningsTotalRuns,
    required Map<String, BattingScore> battingScores,
    required Map<String, BowlingScore> bowlingScores,
    required String? strikerId,
    required String? nonStrikerId,
    required String? currentBowlerId,
    required String? previousBowlerId,
    required List<ScoringSnapshot> undoStack,
    required Map<String, String> teamNames,
    required Map<String, String> playerNames,
  }) async {
    try {
      final prefs = await _instance;
      final Map<String, dynamic> stateMap = {
        'match': match.toMap(),
        'innings': innings.toMap(),
        'firstInningsTotalRuns': firstInningsTotalRuns,
        'battingScores': battingScores.map((k, v) => MapEntry(k, v.toMap())),
        'bowlingScores': bowlingScores.map((k, v) => MapEntry(k, v.toMap())),
        'strikerId': strikerId,
        'nonStrikerId': nonStrikerId,
        'currentBowlerId': currentBowlerId,
        'previousBowlerId': previousBowlerId,
        'undoStack': undoStack.map((s) => _serializeSnapshot(s)).toList(),
        'teamNames': teamNames,
        'playerNames': playerNames,
        'savedAt': DateTime.now().toIso8601String(),
      };

      final jsonStr = jsonEncode(stateMap);
      await prefs.setString('$_keyPrefixMatchState$matchId', jsonStr);
      debugPrint('[OfflineScoringStorage] Saved local snapshot for match: $matchId');
    } catch (e, stack) {
      debugPrint('[OfflineScoringStorage] Error saving local snapshot: $e\n$stack');
    }
  }

  /// Restores complete scoring state snapshot for a match from local storage
  Future<Map<String, dynamic>?> getMatchSnapshot(String matchId) async {
    try {
      final prefs = await _instance;
      final jsonStr = prefs.getString('$_keyPrefixMatchState$matchId');
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return map;
    } catch (e, stack) {
      debugPrint('[OfflineScoringStorage] Error reading match snapshot: $e\n$stack');
      return null;
    }
  }

  /// Clears local match snapshot
  Future<void> clearMatchSnapshot(String matchId) async {
    final prefs = await _instance;
    await prefs.remove('$_keyPrefixMatchState$matchId');
  }

  // ---------------------------------------------------------------------------
  // 2. OFFLINE SYNC ACTION QUEUE (FIFO)
  // ---------------------------------------------------------------------------

  /// Returns all queued sync actions in FIFO order
  Future<List<SyncAction>> getPendingSyncQueue() async {
    try {
      final prefs = await _instance;
      final rawList = prefs.getStringList(_keySyncQueue) ?? [];
      return rawList
          .map((item) => SyncAction.fromMap(jsonDecode(item) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[OfflineScoringStorage] Error parsing sync queue: $e');
      return [];
    }
  }

  /// Gets the count of pending sync actions
  Future<int> getPendingCount({String? matchId}) async {
    final queue = await getPendingSyncQueue();
    if (matchId == null) return queue.length;
    return queue.where((a) => a.matchId == matchId).length;
  }

  /// Enqueues a new sync mutation
  Future<void> enqueueSyncAction(SyncAction action) async {
    try {
      final prefs = await _instance;
      final queue = await getPendingSyncQueue();
      // Deduplicate: If an action with the exact same ID already exists, update it
      final existingIndex = queue.indexWhere((a) => a.id == action.id);
      if (existingIndex >= 0) {
        queue[existingIndex] = action;
      } else {
        queue.add(action);
      }

      final rawList = queue.map((a) => jsonEncode(a.toMap())).toList();
      await prefs.setStringList(_keySyncQueue, rawList);
      debugPrint('[OfflineScoringStorage] Enqueued sync action: ${action.type.name} (Total: ${queue.length})');
    } catch (e, stack) {
      debugPrint('[OfflineScoringStorage] Error enqueuing action: $e\n$stack');
    }
  }

  /// Removes an acknowledged sync action from the queue
  Future<void> removeSyncAction(String actionId) async {
    try {
      final prefs = await _instance;
      final queue = await getPendingSyncQueue();
      queue.removeWhere((a) => a.id == actionId);
      final rawList = queue.map((a) => jsonEncode(a.toMap())).toList();
      await prefs.setStringList(_keySyncQueue, rawList);
      await prefs.setString(_keyLastSyncTimestamp, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[OfflineScoringStorage] Error removing sync action: $e');
    }
  }

  /// Updates retry count or payload of an action in the queue
  Future<void> updateSyncAction(SyncAction action) async {
    try {
      final prefs = await _instance;
      final queue = await getPendingSyncQueue();
      final idx = queue.indexWhere((a) => a.id == action.id);
      if (idx >= 0) {
        queue[idx] = action;
        final rawList = queue.map((a) => jsonEncode(a.toMap())).toList();
        await prefs.setStringList(_keySyncQueue, rawList);
      }
    } catch (e) {
      debugPrint('[OfflineScoringStorage] Error updating sync action: $e');
    }
  }

  /// Clears all pending sync actions
  Future<void> clearAllSyncActions({String? matchId}) async {
    final prefs = await _instance;
    if (matchId == null) {
      await prefs.remove(_keySyncQueue);
    } else {
      final queue = await getPendingSyncQueue();
      queue.removeWhere((a) => a.matchId == matchId);
      final rawList = queue.map((a) => jsonEncode(a.toMap())).toList();
      await prefs.setStringList(_keySyncQueue, rawList);
    }
  }

  /// Returns last successful sync timestamp
  Future<DateTime?> getLastSyncTimestamp() async {
    final prefs = await _instance;
    final str = prefs.getString(_keyLastSyncTimestamp);
    if (str == null || str.isEmpty) return null;
    return DateTime.tryParse(str);
  }

  // ---------------------------------------------------------------------------
  // HELPER SERIALIZERS FOR UNDO SNAPSHOT
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _serializeSnapshot(ScoringSnapshot s) {
    return {
      'match': s.match.toMap(),
      'innings': s.innings.toMap(),
      'battingScores': s.battingScores.map((k, v) => MapEntry(k, v.toMap())),
      'bowlingScores': s.bowlingScores.map((k, v) => MapEntry(k, v.toMap())),
      'currentStrikerId': s.currentStrikerId,
      'currentNonStrikerId': s.currentNonStrikerId,
      'currentBowlerId': s.currentBowlerId,
      'previousBowlerId': s.previousBowlerId,
      'deliveryInput': {
        'runsOffBat': s.deliveryInput.runsOffBat,
        'extraRuns': s.deliveryInput.extraRuns,
        'extraType': s.deliveryInput.extraType.name,
        'isWicket': s.deliveryInput.isWicket,
        'wicketType': s.deliveryInput.wicketType?.name,
        'outBatsmanId': s.deliveryInput.outBatsmanId,
        'newBatsmanId': s.deliveryInput.newBatsmanId,
        'dismissalDescription': s.deliveryInput.dismissalDescription,
      },
      'displayBall': s.displayBall,
    };
  }

  static ScoringSnapshot deserializeSnapshot(Map<String, dynamic> map) {
    final inputMap = Map<String, dynamic>.from(map['deliveryInput'] ?? {});
    final extraTypeStr = inputMap['extraType'] as String?;
    final wicketTypeStr = inputMap['wicketType'] as String?;

    final deliveryInput = BallDeliveryInput(
      runsOffBat: (inputMap['runsOffBat'] as num?)?.toInt() ?? 0,
      extraRuns: (inputMap['extraRuns'] as num?)?.toInt() ?? 0,
      extraType: extraTypeStr != null
          ? ExtraType.values.firstWhere((e) => e.name == extraTypeStr, orElse: () => ExtraType.none)
          : ExtraType.none,
      isWicket: inputMap['isWicket'] ?? false,
      wicketType: wicketTypeStr != null
          ? WicketType.values.firstWhere((e) => e.name == wicketTypeStr, orElse: () => WicketType.bowled)
          : null,
      outBatsmanId: inputMap['outBatsmanId'],
      newBatsmanId: inputMap['newBatsmanId'],
      dismissalDescription: inputMap['dismissalDescription'],
    );

    final rawBatting = Map<String, dynamic>.from(map['battingScores'] ?? {});
    final Map<String, BattingScore> battingMap = rawBatting.map(
      (k, v) => MapEntry(k, BattingScore.fromMap(k, Map<String, dynamic>.from(v))),
    );

    final rawBowling = Map<String, dynamic>.from(map['bowlingScores'] ?? {});
    final Map<String, BowlingScore> bowlingMap = rawBowling.map(
      (k, v) => MapEntry(k, BowlingScore.fromMap(k, Map<String, dynamic>.from(v))),
    );

    final matchMap = Map<String, dynamic>.from(map['match'] ?? {});
    final innMap = Map<String, dynamic>.from(map['innings'] ?? {});

    return ScoringSnapshot(
      match: MatchModel.fromMap(matchMap['id'] ?? '', matchMap),
      innings: InningsModel.fromMap(innMap['id'] ?? '', innMap),
      battingScores: battingMap,
      bowlingScores: bowlingMap,
      currentStrikerId: map['currentStrikerId'],
      currentNonStrikerId: map['currentNonStrikerId'],
      currentBowlerId: map['currentBowlerId'],
      previousBowlerId: map['previousBowlerId'],
      deliveryInput: deliveryInput,
      displayBall: map['displayBall'] ?? '',
    );
  }
}
