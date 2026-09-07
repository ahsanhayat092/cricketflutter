import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/match_model.dart';
import '../models/innings_model.dart';
import '../models/batting_score.dart';
import '../models/bowling_score.dart';
import '../models/ball_event.dart';
import '../engine/scoring_snapshot.dart';
import '../engine/cricket_scoring_engine.dart';
import '../data/firebase_scoring_service.dart';
import '../data/scoring_sync_service.dart';
import '../data/offline_scoring_storage.dart';
import '../data/offline_sync_manager.dart';
import '../../match_management/providers/tournament_providers.dart';
import 'offline_sync_providers.dart';

typedef CricketScoringState = ScoringState;

class ScoringState {
  final MatchModel match;
  final InningsModel innings;
  final int? firstInningsTotalRuns;
  final Map<String, BattingScore> battingScores;
  final Map<String, BowlingScore> bowlingScores;
  final String? strikerId;
  final String? nonStrikerId;
  final String? currentBowlerId;
  final String? previousBowlerId;
  final List<ScoringSnapshot> undoStack;
  final bool isNeedBowlerSelection;
  final String? latestCelebration;
  final String? latestCelebrationText;
  final int celebrationCounter;
  final bool isSyncing;
  final String? lastSyncError;
  final Map<String, String> teamNames;
  final Map<String, String> playerNames;
  final bool isLoading;

  const ScoringState({
    required this.match,
    required this.innings,
    this.firstInningsTotalRuns,
    required this.battingScores,
    required this.bowlingScores,
    this.strikerId,
    this.nonStrikerId,
    this.currentBowlerId,
    this.previousBowlerId,
    this.undoStack = const [],
    this.isNeedBowlerSelection = false,
    this.latestCelebration,
    this.latestCelebrationText,
    this.celebrationCounter = 0,
    this.isSyncing = false,
    this.lastSyncError,
    this.teamNames = const {},
    this.playerNames = const {},
    this.isLoading = true,
  });

  bool get canUndo => undoStack.isNotEmpty;
  bool get isLocked => innings.completed || match.isCompleted;

  ScoringState copyWith({
    MatchModel? match,
    InningsModel? innings,
    int? firstInningsTotalRuns,
    Map<String, BattingScore>? battingScores,
    Map<String, BowlingScore>? bowlingScores,
    String? strikerId,
    String? nonStrikerId,
    String? currentBowlerId,
    bool clearCurrentBowler = false,
    String? previousBowlerId,
    List<ScoringSnapshot>? undoStack,
    bool? isNeedBowlerSelection,
    String? latestCelebration,
    String? latestCelebrationText,
    int? celebrationCounter,
    bool? isSyncing,
    String? lastSyncError,
    Map<String, String>? teamNames,
    Map<String, String>? playerNames,
    bool? isLoading,
  }) {
    return ScoringState(
      match: match ?? this.match,
      innings: innings ?? this.innings,
      firstInningsTotalRuns: firstInningsTotalRuns ?? this.firstInningsTotalRuns,
      battingScores: battingScores ?? this.battingScores,
      bowlingScores: bowlingScores ?? this.bowlingScores,
      strikerId: strikerId ?? this.strikerId,
      nonStrikerId: nonStrikerId ?? this.nonStrikerId,
      currentBowlerId: clearCurrentBowler ? null : (currentBowlerId ?? this.currentBowlerId),
      previousBowlerId: previousBowlerId ?? this.previousBowlerId,
      undoStack: undoStack ?? this.undoStack,
      isNeedBowlerSelection: isNeedBowlerSelection ?? this.isNeedBowlerSelection,
      latestCelebration: latestCelebration ?? this.latestCelebration,
      latestCelebrationText: latestCelebrationText ?? this.latestCelebrationText,
      celebrationCounter: celebrationCounter ?? this.celebrationCounter,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncError: lastSyncError,
      teamNames: teamNames ?? this.teamNames,
      playerNames: playerNames ?? this.playerNames,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final liveScoringControllerProvider =
    StateNotifierProvider.family<ScoringController, ScoringState, String>((ref, matchId) {
  final service = ref.read(scoringServiceProvider);
  final syncService = ref.read(scoringSyncServiceProvider);
  final storage = ref.read(offlineScoringStorageProvider);
  final syncManager = ref.read(offlineSyncManagerProvider);

  return ScoringController(
    service,
    syncService,
    matchId,
    storage: storage,
    syncManager: syncManager,
  );
});

class ScoringController extends StateNotifier<ScoringState> {
  final FirebaseScoringService _service;
  final ScoringSyncService _syncService;
  final String matchId;
  final OfflineScoringStorage? _storage;
  final OfflineSyncManager? _syncManager;

  ScoringController(
    this._service,
    this._syncService,
    this.matchId, {
    OfflineScoringStorage? storage,
    OfflineSyncManager? syncManager,
  })  : _storage = storage,
        _syncManager = syncManager,
        super(ScoringState(
          match: MatchModel(
            id: matchId,
            matchNumber: 1,
            stage: 'LEAGUE',
            teamAId: '',
            teamBId: '',
            date: '',
          ),
          innings: InningsModel(
            id: 'inn_${matchId}_1',
            matchId: matchId,
            inningsNumber: 1,
            battingTeamId: '',
            bowlingTeamId: '',
          ),
          firstInningsTotalRuns: null,
          battingScores: const {},
          bowlingScores: const {},
          strikerId: null,
          nonStrikerId: null,
          currentBowlerId: null,
          previousBowlerId: null,
          isLoading: true,
        )) {
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    // 1. First, check local offline snapshot for instant offline launch
    if (_storage != null) {
      try {
        final localSnapshot = await _storage.getMatchSnapshot(matchId);
        if (localSnapshot != null) {
          final matchMap = Map<String, dynamic>.from(localSnapshot['match'] ?? {});
          final innMap = Map<String, dynamic>.from(localSnapshot['innings'] ?? {});
          final rawBatting = Map<String, dynamic>.from(localSnapshot['battingScores'] ?? {});
          final rawBowling = Map<String, dynamic>.from(localSnapshot['bowlingScores'] ?? {});
          final rawUndo = List<dynamic>.from(localSnapshot['undoStack'] ?? []);
          final teamNames = Map<String, String>.from(localSnapshot['teamNames'] ?? {});
          final playerNames = Map<String, String>.from(localSnapshot['playerNames'] ?? {});

          final Map<String, BattingScore> battingMap = rawBatting.map(
            (k, v) => MapEntry(k, BattingScore.fromMap(k, Map<String, dynamic>.from(v))),
          );
          final Map<String, BowlingScore> bowlingMap = rawBowling.map(
            (k, v) => MapEntry(k, BowlingScore.fromMap(k, Map<String, dynamic>.from(v))),
          );
          final undoList = rawUndo
              .map((u) => OfflineScoringStorage.deserializeSnapshot(Map<String, dynamic>.from(u)))
              .toList();

          state = state.copyWith(
            match: MatchModel.fromMap(matchMap['id'] ?? matchId, matchMap),
            innings: InningsModel.fromMap(innMap['id'] ?? '', innMap),
            firstInningsTotalRuns: localSnapshot['firstInningsTotalRuns'],
            battingScores: battingMap,
            bowlingScores: bowlingMap,
            strikerId: localSnapshot['strikerId'],
            nonStrikerId: localSnapshot['nonStrikerId'],
            currentBowlerId: localSnapshot['currentBowlerId'],
            previousBowlerId: localSnapshot['previousBowlerId'],
            undoStack: undoList,
            teamNames: teamNames,
            playerNames: playerNames,
            isLoading: false,
          );
          debugPrint('[ScoringController] Restored match $matchId from local offline snapshot.');
        }
      } catch (e) {
        debugPrint('[ScoringController] Error reading local snapshot: $e');
      }
    }

    // 2. Background refresh from Firestore (if online)
    await _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    try {
      final match = await _service.getMatch(matchId);
      if (match != null) {
        final Map<String, String> teamNames = Map.from(state.teamNames);
        try {
          final teams = await _service.getTeams(tournamentId: match.tournamentId);
          for (final t in teams) {
            teamNames[t.id] = t.name;
          }
          final teamAId = match.teamAId;
          if (teamAId != null && teamAId.isNotEmpty && !teamNames.containsKey(teamAId)) {
            final tA = await _service.getTeam(teamAId);
            if (tA != null) teamNames[tA.id] = tA.name;
          }
          final teamBId = match.teamBId;
          if (teamBId != null && teamBId.isNotEmpty && !teamNames.containsKey(teamBId)) {
            final tB = await _service.getTeam(teamBId);
            if (tB != null) teamNames[tB.id] = tB.name;
          }
        } catch (e) {
          debugPrint('[ScoringController] Error fetching team names: $e');
        }

        final Map<String, String> playerNames = Map.from(state.playerNames);
        try {
          final players = await _service.getPlayers();
          for (final p in players) {
            playerNames[p.id] = p.name;
          }
        } catch (e) {
          debugPrint('[ScoringController] Error fetching players: $e');
        }

        final inningsList = await _service.getInningsForMatch(matchId);
        if (inningsList.isNotEmpty) {
          final currentInnings = inningsList.last;
          final batting = await _service.getBattingScores(currentInnings.id);
          final bowling = await _service.getBowlingScores(currentInnings.id);

          final battingMap = {for (var b in batting) b.playerId: b};
          final bowlingMap = {for (var bo in bowling) bo.playerId: bo};

          // Accurate restoration of striker, nonStriker, and currentBowler
          final striker = currentInnings.strikerId ?? (batting.isNotEmpty ? batting.first.playerId : null);
          final nonStriker = currentInnings.nonStrikerId ?? (batting.length > 1 ? batting[1].playerId : null);
          
          // Determine active bowler:
          // 1. If at over end (balls > 0 && balls % 6 == 0), no bowler active (ready for new over selection)
          // 2. If currentInnings has explicit currentBowlerId, use it
          // 3. If local state already has a valid bowler from snapshot, preserve it
          // 4. If mid-over (balls % 6 != 0), find the bowler with incomplete over (b.balls % 6 != 0)
          // 5. If innings at 0.0 overs (start of innings), use 1st bowler in bowling list
          final isOverEnded = currentInnings.balls > 0 && (currentInnings.balls % 6 == 0);
          String? bowler;
          if (isOverEnded) {
            bowler = null;
          } else if (currentInnings.currentBowlerId != null && currentInnings.currentBowlerId!.isNotEmpty) {
            bowler = currentInnings.currentBowlerId;
          } else if (state.currentBowlerId != null && state.currentBowlerId!.isNotEmpty) {
            bowler = state.currentBowlerId;
          } else {
            final midOverBowlers = bowling.where((b) => b.balls % 6 != 0).toList();
            if (midOverBowlers.isNotEmpty) {
              bowler = midOverBowlers.first.playerId;
            } else if (currentInnings.balls == 0 && bowling.isNotEmpty) {
              bowler = bowling.first.playerId;
            }
          }

          final previousBowler = currentInnings.previousBowlerId ?? state.previousBowlerId;
          final firstInningsRuns = inningsList.length > 1 ? inningsList.first.runs : null;

          state = state.copyWith(
            match: match,
            innings: currentInnings,
            firstInningsTotalRuns: firstInningsRuns,
            battingScores: battingMap.isNotEmpty ? battingMap : state.battingScores,
            bowlingScores: bowlingMap.isNotEmpty ? bowlingMap : state.bowlingScores,
            strikerId: striker ?? state.strikerId,
            nonStrikerId: nonStriker ?? state.nonStrikerId,
            currentBowlerId: bowler ?? state.currentBowlerId,
            clearCurrentBowler: isOverEnded,
            previousBowlerId: previousBowler,
            isNeedBowlerSelection: isOverEnded && !currentInnings.completed,
            teamNames: teamNames,
            playerNames: playerNames,
            isLoading: false,
          );
        } else {
          // Determine batting/bowling teams from match toss if innings not created yet
          final teamAId = match.teamAId ?? '';
          final teamBId = match.teamBId ?? '';
          final isTeamAWon = match.tossWinnerId == teamAId;
          final isBatFirst = match.tossDecision?.toUpperCase() == 'BAT';
          final batTeam = (isTeamAWon && isBatFirst) || (!isTeamAWon && !isBatFirst)
              ? teamAId
              : teamBId;
          final bowlTeam = batTeam == teamAId ? teamBId : teamAId;

          final battingSquad = batTeam == teamAId ? match.teamAPlayingVI : match.teamBPlayingVI;

          final s1 = battingSquad.isNotEmpty ? battingSquad[0] : null;
          final s2 = battingSquad.length > 1 ? battingSquad[1] : null;

          final initialInnings = InningsModel(
            id: 'inn_${matchId}_1',
            matchId: matchId,
            inningsNumber: 1,
            battingTeamId: batTeam,
            bowlingTeamId: bowlTeam,
          );

          state = state.copyWith(
            match: match,
            innings: initialInnings,
            strikerId: s1 ?? state.strikerId,
            nonStrikerId: s2 ?? state.nonStrikerId,
            isNeedBowlerSelection: false,
            teamNames: teamNames,
            playerNames: playerNames,
            isLoading: false,
          );
        }

        // Cache latest state locally
        _saveCurrentSnapshotLocally();
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint('[ScoringController] Load from Firestore note: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _saveCurrentSnapshotLocally() async {
    if (_storage == null) return;
    await _storage.saveMatchSnapshot(
      matchId: matchId,
      match: state.match,
      innings: state.innings,
      firstInningsTotalRuns: state.firstInningsTotalRuns,
      battingScores: state.battingScores,
      bowlingScores: state.bowlingScores,
      strikerId: state.strikerId,
      nonStrikerId: state.nonStrikerId,
      currentBowlerId: state.currentBowlerId,
      previousBowlerId: state.previousBowlerId,
      undoStack: state.undoStack,
      teamNames: state.teamNames,
      playerNames: state.playerNames,
    );
  }

  void setPlayerNames(Map<String, String> names) {
    state = state.copyWith(playerNames: {...state.playerNames, ...names});
    _saveCurrentSnapshotLocally();
  }

  /// Change/Select current bowler
  void setCurrentBowler(String bowlerId) {
    if (state.currentBowlerId == bowlerId) {
      if (state.isNeedBowlerSelection) {
        state = state.copyWith(isNeedBowlerSelection: false);
      }
      return;
    }

    // Over Guard: Bowler cannot be changed mid-over UNLESS:
    // 1. currentBowlerId is null (e.g. restoring mid-over or bowler was cleared)
    // 2. The current bowler has exceeded their quota (fixing quota violation)
    // 3. isNeedBowlerSelection is true
    final isMidOver = state.innings.balls > 0 && (state.innings.balls % 6 != 0);
    final currentBowlerScore = state.currentBowlerId != null ? state.bowlingScores[state.currentBowlerId!] : null;
    final isCurrentBowlerExhausted = currentBowlerScore != null &&
        CricketScoringEngine.isBowlerQuotaExhausted(
          bowlerId: state.currentBowlerId!,
          stage: state.match.isFinal ? MatchStage.finalMatch : MatchStage.league,
          bowlingScores: state.bowlingScores.values.toList(),
          maxOverPerBowler: state.match.rules.maxOverPerBowler,
        );

    if (isMidOver &&
        state.currentBowlerId != null &&
        !state.isNeedBowlerSelection &&
        !isCurrentBowlerExhausted) {
      debugPrint('[ScoringController] Cannot change bowler mid-over. Balls: ${state.innings.balls}');
      return;
    }

    var bowlingMap = Map<String, BowlingScore>.from(state.bowlingScores);
    if (!bowlingMap.containsKey(bowlerId)) {
      bowlingMap[bowlerId] = BowlingScore(
        id: '${state.innings.id}_$bowlerId',
        inningsId: state.innings.id,
        playerId: bowlerId,
      );
    }

    final updatedInnings = state.innings.copyWith(currentBowlerId: bowlerId);

    state = state.copyWith(
      innings: updatedInnings,
      currentBowlerId: bowlerId,
      clearCurrentBowler: false,
      bowlingScores: bowlingMap,
      isNeedBowlerSelection: false,
    );
    _saveCurrentSnapshotLocally();
  }

  /// Set or change opening batsmen and bowler before any delivery is bowled
  Future<void> setOpeners({
    required String strikerId,
    required String nonStrikerId,
    String? bowlerId,
  }) async {
    final s1Batting = BattingScore(
      id: '${state.innings.id}_$strikerId',
      inningsId: state.innings.id,
      playerId: strikerId,
      battingOrder: 1,
    );
    final s2Batting = BattingScore(
      id: '${state.innings.id}_$nonStrikerId',
      inningsId: state.innings.id,
      playerId: nonStrikerId,
      battingOrder: 2,
    );

    var battingMap = Map<String, BattingScore>.from(state.battingScores);
    battingMap[strikerId] = s1Batting;
    battingMap[nonStrikerId] = s2Batting;

    var bowlingMap = Map<String, BowlingScore>.from(state.bowlingScores);
    if (bowlerId != null && bowlerId.isNotEmpty) {
      bowlingMap[bowlerId] = BowlingScore(
        id: '${state.innings.id}_$bowlerId',
        inningsId: state.innings.id,
        playerId: bowlerId,
      );
    }

    state = state.copyWith(
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      currentBowlerId: bowlerId ?? state.currentBowlerId,
      clearCurrentBowler: bowlerId == null,
      battingScores: battingMap,
      bowlingScores: bowlingMap,
      isNeedBowlerSelection: bowlerId == null,
      isSyncing: true,
    );

    // Save locally first
    await _saveCurrentSnapshotLocally();

    // Enqueue sync action
    if (_storage != null) {
      final action = SyncAction(
        id: 'openers_${matchId}_${state.innings.id}',
        matchId: matchId,
        type: SyncActionType.setOpeners,
        payload: {
          'tournamentId': state.match.tournamentId,
          'match': state.match.toMap(),
          'innings': state.innings.toMap(),
          'battingScores': battingMap.map((k, v) => MapEntry(k, v.toMap())),
          'bowlingScores': bowlingMap.map((k, v) => MapEntry(k, v.toMap())),
        },
        createdAt: DateTime.now().toIso8601String(),
      );
      await _storage.enqueueSyncAction(action);
      _syncManager?.onActionEnqueued();
    } else {
      try {
        await _syncService.recordDeliveryAtomic(
          match: state.match,
          innings: state.innings,
          battingScores: battingMap,
          bowlingScores: bowlingMap,
        );
      } catch (e) {
        debugPrint('[ScoringController] Error saving openers: $e');
      }
    }
  }

  /// Swap Striker and Non-Striker
  void swapStriker() {
    final s = state.strikerId;
    final ns = state.nonStrikerId;
    state = state.copyWith(
      strikerId: ns,
      nonStrikerId: s,
    );
    _saveCurrentSnapshotLocally();
  }

  /// Process a ball delivery, push snapshot to undo stack, and sync atomically to Firestore
  Future<void> recordDelivery(BallDeliveryInput input) async {
    if (state.isLocked) return;

    final strikerId = state.strikerId;
    final nonStrikerId = state.nonStrikerId;
    final currentBowlerId = state.currentBowlerId;

    // Strict validation: bowler MUST be selected before scoring any ball
    if (strikerId == null || nonStrikerId == null || currentBowlerId == null) {
      state = state.copyWith(isNeedBowlerSelection: true);
      return;
    }

    // 1. Create Snapshot for Undo Stack
    final snapshot = ScoringSnapshot(
      match: state.match,
      innings: state.innings,
      battingScores: Map.from(state.battingScores),
      bowlingScores: Map.from(state.bowlingScores),
      currentStrikerId: state.strikerId,
      currentNonStrikerId: state.nonStrikerId,
      currentBowlerId: state.currentBowlerId,
      previousBowlerId: state.previousBowlerId,
      deliveryInput: input,
      displayBall: input.displaySymbol,
    );

    final newUndoStack = List<ScoringSnapshot>.from(state.undoStack)..add(snapshot);

    // 2. Run Pure Calculation Engine
    final result = CricketScoringEngine.processDelivery(
      match: state.match,
      innings: state.innings,
      firstInningsTotalRuns: state.firstInningsTotalRuns,
      battingScores: state.battingScores,
      bowlingScores: state.bowlingScores,
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      bowlerId: currentBowlerId,
      previousBowlerId: state.previousBowlerId,
      input: input,
      teamNames: state.teamNames,
      playerNames: state.playerNames,
    );

    // 3. Update Local State Immediately (clearing bowler if over finished)
    state = state.copyWith(
      match: result.match,
      innings: result.innings,
      battingScores: result.battingScores,
      bowlingScores: result.bowlingScores,
      strikerId: result.strikerId,
      nonStrikerId: result.nonStrikerId,
      currentBowlerId: result.currentBowlerId,
      clearCurrentBowler: result.isOverCompleted && !result.isInningsCompleted && !result.isMatchCompleted,
      previousBowlerId: result.previousBowlerId,
      undoStack: newUndoStack,
      isNeedBowlerSelection: result.isOverCompleted && !result.isInningsCompleted && !result.isMatchCompleted,
      latestCelebration: result.celebrationType,
      latestCelebrationText: result.celebrationText,
      celebrationCounter: result.celebrationType != null
          ? state.celebrationCounter + 1
          : state.celebrationCounter,
      isSyncing: true,
    );

    // 4. Save locally immediately (Zero latency offline protection)
    await _saveCurrentSnapshotLocally();

    // 5. Enqueue in Offline Sync Queue and trigger Background Sync
    if (_storage != null) {
      final action = SyncAction(
        id: 'delivery_${matchId}_${result.innings.id}_${DateTime.now().millisecondsSinceEpoch}_${result.innings.balls}',
        matchId: matchId,
        type: SyncActionType.recordDelivery,
        payload: {
          'tournamentId': result.match.tournamentId,
          'match': result.match.toMap(),
          'innings': result.innings.toMap(),
          'battingScores': result.battingScores.map((k, v) => MapEntry(k, v.toMap())),
          'bowlingScores': result.bowlingScores.map((k, v) => MapEntry(k, v.toMap())),
        },
        createdAt: DateTime.now().toIso8601String(),
      );
      await _storage.enqueueSyncAction(action);
      _syncManager?.onActionEnqueued();
    } else {
      try {
        await _syncService.recordDeliveryAtomic(
          match: result.match,
          innings: result.innings,
          battingScores: result.battingScores,
          bowlingScores: result.bowlingScores,
        );
        state = state.copyWith(isSyncing: false, lastSyncError: null);
      } catch (e, stack) {
        debugPrint('[ScoringController] Error syncing to Firestore: $e\n$stack');
        state = state.copyWith(isSyncing: false, lastSyncError: e.toString());
      }
    }
  }

  /// Instant One-Tap Undo: Reverts local state and syncs rollback to Firestore
  Future<void> undoLastDelivery() async {
    if (!state.canUndo) return;

    final newUndoStack = List<ScoringSnapshot>.from(state.undoStack);
    final lastSnapshot = newUndoStack.removeLast();

    state = state.copyWith(
      match: lastSnapshot.match,
      innings: lastSnapshot.innings,
      battingScores: lastSnapshot.battingScores,
      bowlingScores: lastSnapshot.bowlingScores,
      strikerId: lastSnapshot.currentStrikerId,
      nonStrikerId: lastSnapshot.currentNonStrikerId,
      currentBowlerId: lastSnapshot.currentBowlerId,
      clearCurrentBowler: lastSnapshot.currentBowlerId == null,
      previousBowlerId: lastSnapshot.previousBowlerId,
      undoStack: newUndoStack,
      isNeedBowlerSelection: false,
      isSyncing: true,
    );

    // Save locally first
    await _saveCurrentSnapshotLocally();

    // Enqueue rollback sync
    if (_storage != null) {
      final action = SyncAction(
        id: 'undo_${matchId}_${lastSnapshot.innings.id}_${DateTime.now().millisecondsSinceEpoch}_${lastSnapshot.innings.balls}',
        matchId: matchId,
        type: SyncActionType.undoDelivery,
        payload: {
          'tournamentId': lastSnapshot.match.tournamentId,
          'match': lastSnapshot.match.toMap(),
          'innings': lastSnapshot.innings.toMap(),
          'battingScores': lastSnapshot.battingScores.map((k, v) => MapEntry(k, v.toMap())),
          'bowlingScores': lastSnapshot.bowlingScores.map((k, v) => MapEntry(k, v.toMap())),
        },
        createdAt: DateTime.now().toIso8601String(),
      );
      await _storage.enqueueSyncAction(action);
      _syncManager?.onActionEnqueued();
    } else {
      try {
        await _syncService.recordDeliveryAtomic(
          match: lastSnapshot.match,
          innings: lastSnapshot.innings,
          battingScores: lastSnapshot.battingScores,
          bowlingScores: lastSnapshot.bowlingScores,
        );
        state = state.copyWith(isSyncing: false, lastSyncError: null);
      } catch (e, stack) {
        debugPrint('[ScoringController] Error syncing rollback to Firestore: $e\n$stack');
        state = state.copyWith(isSyncing: false, lastSyncError: e.toString());
      }
    }
  }

  /// Start 2nd Innings Transition
  Future<void> startSecondInnings({
    String? battingTeamId,
    String? bowlingTeamId,
    required String strikerId,
    required String nonStrikerId,
    String? bowlerId,
  }) async {
    final firstInningsRuns = state.innings.runs;
    final secondInningsId = 'inn_${matchId}_2';
    final batTeam = battingTeamId ?? state.innings.bowlingTeamId;
    final bowlTeam = bowlingTeamId ?? state.innings.battingTeamId;

    final inn2 = InningsModel(
      id: secondInningsId,
      matchId: matchId,
      inningsNumber: 2,
      battingTeamId: batTeam,
      bowlingTeamId: bowlTeam,
    );

    final s1 = BattingScore(
      id: '${secondInningsId}_$strikerId',
      inningsId: secondInningsId,
      playerId: strikerId,
      battingOrder: 1,
    );
    final s2 = BattingScore(
      id: '${secondInningsId}_$nonStrikerId',
      inningsId: secondInningsId,
      playerId: nonStrikerId,
      battingOrder: 2,
    );

    final battingMap = {
      strikerId: s1,
      nonStrikerId: s2,
    };

    final bowlingMap = <String, BowlingScore>{};
    if (bowlerId != null && bowlerId.isNotEmpty) {
      bowlingMap[bowlerId] = BowlingScore(
        id: '${secondInningsId}_$bowlerId',
        inningsId: secondInningsId,
        playerId: bowlerId,
      );
    }

    state = state.copyWith(
      innings: inn2,
      firstInningsTotalRuns: firstInningsRuns,
      battingScores: battingMap,
      bowlingScores: bowlingMap,
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      currentBowlerId: bowlerId,
      clearCurrentBowler: bowlerId == null,
      previousBowlerId: null,
      undoStack: [],
      isNeedBowlerSelection: bowlerId == null,
      isSyncing: true,
    );

    await _saveCurrentSnapshotLocally();

    if (_storage != null) {
      final action = SyncAction(
        id: 'start_inn2_${matchId}_${DateTime.now().millisecondsSinceEpoch}',
        matchId: matchId,
        type: SyncActionType.recordDelivery,
        payload: {
          'tournamentId': state.match.tournamentId,
          'match': state.match.toMap(),
          'innings': inn2.toMap(),
          'battingScores': battingMap.map((k, v) => MapEntry(k, v.toMap())),
          'bowlingScores': bowlingMap.map((k, v) => MapEntry(k, v.toMap())),
        },
        createdAt: DateTime.now().toIso8601String(),
      );
      await _storage.enqueueSyncAction(action);
      _syncManager?.onActionEnqueued();
    } else {
      try {
        await _syncService.recordDeliveryAtomic(
          match: state.match,
          innings: inn2,
          battingScores: battingMap,
          bowlingScores: bowlingMap,
        );
        state = state.copyWith(isSyncing: false, lastSyncError: null);
      } catch (e) {
        debugPrint('[ScoringController] Error starting 2nd Innings: $e');
        state = state.copyWith(isSyncing: false, lastSyncError: e.toString());
      }
    }
  }

  /// Finalize Match as COMPLETED and update points table
  Future<void> finalizeMatch({
    required String winningTeamId,
    required String resultText,
    String? playerOfMatchId,
  }) async {
    final updatedMatch = state.match.copyWith(
      status: 'COMPLETED',
      winningTeamId: winningTeamId,
      resultText: resultText,
      playerOfMatchId: playerOfMatchId,
    );

    state = state.copyWith(match: updatedMatch, isSyncing: true);
    await _saveCurrentSnapshotLocally();

    if (_storage != null) {
      final action = SyncAction(
        id: 'finalize_${matchId}_${DateTime.now().millisecondsSinceEpoch}',
        matchId: matchId,
        type: SyncActionType.finalizeMatch,
        payload: {
          'winningTeamId': winningTeamId,
          'resultText': resultText,
          'playerOfMatchId': playerOfMatchId,
          'tournamentId': state.match.tournamentId,
        },
        createdAt: DateTime.now().toIso8601String(),
      );
      await _storage.enqueueSyncAction(action);
      _syncManager?.onActionEnqueued();
    } else {
      try {
        await _syncService.finalizeMatch(
          matchId: matchId,
          winningTeamId: winningTeamId,
          resultText: resultText,
          playerOfMatchId: playerOfMatchId,
          tournamentId: state.match.tournamentId,
        );
        state = state.copyWith(isSyncing: false, lastSyncError: null);
      } catch (e) {
        debugPrint('[ScoringController] Error finalizing match: $e');
        state = state.copyWith(isSyncing: false, lastSyncError: e.toString());
      }
    }
  }

  /// Mid-Match Scorecard Correction: Swaps a wrongly attributed player on batting or bowling scorecard
  Future<void> swapPlayer({
    required String oldPlayerId,
    required String newPlayerId,
    required String newPlayerName,
    required bool isBatting,
  }) async {
    if (oldPlayerId == newPlayerId) return;

    var updatedBattingScores = Map<String, BattingScore>.from(state.battingScores);
    var updatedBowlingScores = Map<String, BowlingScore>.from(state.bowlingScores);
    var updatedPlayerNames = Map<String, String>.from(state.playerNames);

    updatedPlayerNames[newPlayerId] = newPlayerName;

    String? newStrikerId = state.strikerId;
    String? newNonStrikerId = state.nonStrikerId;
    String? newCurrentBowlerId = state.currentBowlerId;
    String? newPreviousBowlerId = state.previousBowlerId;

    if (isBatting) {
      if (updatedBattingScores.containsKey(oldPlayerId)) {
        final oldStat = updatedBattingScores.remove(oldPlayerId)!;
        updatedBattingScores[newPlayerId] = oldStat.copyWith(
          id: '${state.innings.id}_$newPlayerId',
          playerId: newPlayerId,
        );
      }
      if (newStrikerId == oldPlayerId) newStrikerId = newPlayerId;
      if (newNonStrikerId == oldPlayerId) newNonStrikerId = newPlayerId;
    } else {
      if (updatedBowlingScores.containsKey(oldPlayerId)) {
        final oldStat = updatedBowlingScores.remove(oldPlayerId)!;
        updatedBowlingScores[newPlayerId] = oldStat.copyWith(
          id: '${state.innings.id}_$newPlayerId',
          playerId: newPlayerId,
        );
      }
      if (newCurrentBowlerId == oldPlayerId) newCurrentBowlerId = newPlayerId;
      if (newPreviousBowlerId == oldPlayerId) newPreviousBowlerId = newPlayerId;
    }

    state = state.copyWith(
      battingScores: updatedBattingScores,
      bowlingScores: updatedBowlingScores,
      playerNames: updatedPlayerNames,
      strikerId: newStrikerId,
      nonStrikerId: newNonStrikerId,
      currentBowlerId: newCurrentBowlerId,
      previousBowlerId: newPreviousBowlerId,
      isSyncing: true,
    );

    await _saveCurrentSnapshotLocally();

    if (_storage != null) {
      final action = SyncAction(
        id: 'swap_${matchId}_${state.innings.id}_${oldPlayerId}_$newPlayerId',
        matchId: matchId,
        type: SyncActionType.swapPlayer,
        payload: {
          'tournamentId': state.match.tournamentId,
          'inningsId': state.innings.id,
          'inningsNumber': state.innings.inningsNumber,
          'oldPlayerId': oldPlayerId,
          'newPlayerId': newPlayerId,
          'newPlayerName': newPlayerName,
          'isBatting': isBatting,
        },
        createdAt: DateTime.now().toIso8601String(),
      );
      await _storage.enqueueSyncAction(action);
      _syncManager?.onActionEnqueued();
    } else {
      try {
        await _syncService.swapScorecardPlayer(
          matchId: matchId,
          inningsId: state.innings.id,
          inningsNumber: state.innings.inningsNumber,
          oldPlayerId: oldPlayerId,
          newPlayerId: newPlayerId,
          newPlayerName: newPlayerName,
          isBatting: isBatting,
        );
        state = state.copyWith(isSyncing: false, lastSyncError: null);
      } catch (e) {
        debugPrint('[ScoringController] Error swapping player in Firestore: $e');
        state = state.copyWith(isSyncing: false, lastSyncError: e.toString());
      }
    }
  }

  /// Mid-Match Lineup Update: Updates Playing VI and Reserves for both teams
  Future<void> updateLineup({
    required List<String> teamAPlayingVI,
    String? teamAReserveId,
    required List<String> teamBPlayingVI,
    String? teamBReserveId,
  }) async {
    final updatedMatch = state.match.copyWith(
      teamAPlayingVI: teamAPlayingVI,
      teamAReserveId: teamAReserveId,
      teamBPlayingVI: teamBPlayingVI,
      teamBReserveId: teamBReserveId,
    );

    state = state.copyWith(match: updatedMatch, isSyncing: true);
    await _saveCurrentSnapshotLocally();

    if (_storage != null) {
      final action = SyncAction(
        id: 'lineup_${matchId}_${DateTime.now().millisecondsSinceEpoch}',
        matchId: matchId,
        type: SyncActionType.updateLineup,
        payload: {
          'tournamentId': state.match.tournamentId,
          'teamAPlayingVI': teamAPlayingVI,
          'teamAReserveId': teamAReserveId,
          'teamBPlayingVI': teamBPlayingVI,
          'teamBReserveId': teamBReserveId,
        },
        createdAt: DateTime.now().toIso8601String(),
      );
      await _storage.enqueueSyncAction(action);
      _syncManager?.onActionEnqueued();
    } else {
      try {
        await _syncService.updateMatchLineup(
          matchId: matchId,
          teamAPlayingVI: teamAPlayingVI,
          teamAReserveId: teamAReserveId,
          teamBPlayingVI: teamBPlayingVI,
          teamBReserveId: teamBReserveId,
        );
        state = state.copyWith(isSyncing: false, lastSyncError: null);
      } catch (e) {
        debugPrint('[ScoringController] Error updating lineup in Firestore: $e');
        state = state.copyWith(isSyncing: false, lastSyncError: e.toString());
      }
    }
  }
}
