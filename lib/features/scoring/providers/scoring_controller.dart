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
import '../../match_management/providers/tournament_providers.dart';

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
  final service = ref.watch(scoringServiceProvider);
  final syncService = ref.watch(scoringSyncServiceProvider);
  return ScoringController(service, syncService, matchId);
});

class ScoringController extends StateNotifier<ScoringState> {
  final FirebaseScoringService _service;
  final ScoringSyncService _syncService;
  final String matchId;

  ScoringController(this._service, this._syncService, this.matchId)
      : super(ScoringState(
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
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    try {
      final match = await _service.getMatch(matchId);
      if (match != null) {
        final Map<String, String> teamNames = {};
        try {
          final teams = await _service.getTeams(tournamentId: match.tournamentId);
          for (final t in teams) {
            teamNames[t.id] = t.name;
          }
          if (match.teamAId.isNotEmpty && !teamNames.containsKey(match.teamAId)) {
            final tA = await _service.getTeam(match.teamAId);
            if (tA != null) teamNames[tA.id] = tA.name;
          }
          if (match.teamBId.isNotEmpty && !teamNames.containsKey(match.teamBId)) {
            final tB = await _service.getTeam(match.teamBId);
            if (tB != null) teamNames[tB.id] = tB.name;
          }
        } catch (e) {
          debugPrint('[ScoringController] Error fetching team names: $e');
        }

        final Map<String, String> playerNames = {};
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

          final striker = batting.isNotEmpty ? batting.first.playerId : null;
          final nonStriker = batting.length > 1 ? batting[1].playerId : null;
          
          // Only auto-restore bowler if over is currently mid-flight (not at end of over)
          final isOverEnded = currentInnings.balls > 0 && (currentInnings.balls % 6 == 0);
          final bowler = isOverEnded ? null : (bowling.isNotEmpty ? bowling.first.playerId : null);

          final firstInningsRuns = inningsList.length > 1 ? inningsList.first.runs : null;

          state = state.copyWith(
            match: match,
            innings: currentInnings,
            firstInningsTotalRuns: firstInningsRuns,
            battingScores: battingMap,
            bowlingScores: bowlingMap,
            strikerId: striker ?? state.strikerId,
            nonStrikerId: nonStriker ?? state.nonStrikerId,
            currentBowlerId: bowler,
            clearCurrentBowler: isOverEnded,
            isNeedBowlerSelection: isOverEnded && !currentInnings.completed,
            teamNames: teamNames,
            playerNames: playerNames,
            isLoading: false,
          );
        } else {
          // Determine batting/bowling teams from match toss if innings not created yet
          final isTeamAWon = match.tossWinnerId == match.teamAId;
          final isBatFirst = match.tossDecision?.toUpperCase() == 'BAT';
          final batTeam = (isTeamAWon && isBatFirst) || (!isTeamAWon && !isBatFirst)
              ? match.teamAId
              : match.teamBId;
          final bowlTeam = batTeam == match.teamAId ? match.teamBId : match.teamAId;

          final battingSquad = batTeam == match.teamAId ? match.teamAPlayingVI : match.teamBPlayingVI;
          final bowlingSquad = bowlTeam == match.teamAId ? match.teamAPlayingVI : match.teamBPlayingVI;

          final s1 = battingSquad.isNotEmpty ? battingSquad[0] : null;
          final s2 = battingSquad.length > 1 ? battingSquad[1] : null;
          final b1 = bowlingSquad.isNotEmpty ? bowlingSquad[0] : null;

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
            strikerId: s1,
            nonStrikerId: s2,
            isNeedBowlerSelection: false,
            teamNames: teamNames,
            playerNames: playerNames,
            isLoading: false,
          );
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint('[ScoringController] Load from Firestore error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void setPlayerNames(Map<String, String> names) {
    state = state.copyWith(playerNames: {...state.playerNames, ...names});
  }

  /// Change/Select current bowler
  void setCurrentBowler(String bowlerId) {
    // Over Guard: Bowler cannot be changed mid-over once legal balls have been bowled in current over
    final isMidOver = state.innings.balls > 0 && (state.innings.balls % 6 != 0);
    if (isMidOver && state.currentBowlerId != null && state.currentBowlerId != bowlerId) {
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
    state = state.copyWith(
      currentBowlerId: bowlerId,
      clearCurrentBowler: false,
      bowlingScores: bowlingMap,
      isNeedBowlerSelection: false,
    );
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

    final battingMap = {
      strikerId: s1Batting,
      nonStrikerId: s2Batting,
    };

    var bowlingMap = Map<String, BowlingScore>.from(state.bowlingScores);
    if (bowlerId != null) {
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
      clearCurrentBowler: bowlerId == null && state.currentBowlerId == null,
      battingScores: battingMap,
      bowlingScores: bowlingMap,
    );

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

  /// Swap Striker and Non-Striker
  void swapStriker() {
    final s = state.strikerId;
    final ns = state.nonStrikerId;
    state = state.copyWith(
      strikerId: ns,
      nonStrikerId: s,
    );
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

    // 4. Sync to Firestore atomically using WriteBatch with Auth Guard
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

    // Sync rollback to Firestore
    try {
      await _syncService.recordDeliveryAtomic(
        match: lastSnapshot.match,
        innings: lastSnapshot.innings,
        battingScores: lastSnapshot.battingScores,
        bowlingScores: lastSnapshot.bowlingScores,
      );
      state = state.copyWith(isSyncing: false, lastSyncError: null);
    } catch (e) {
      debugPrint('[ScoringController] Error syncing undo to Firestore: $e');
      state = state.copyWith(isSyncing: false, lastSyncError: e.toString());
    }
  }

  /// Start 2nd Innings
  Future<void> startSecondInnings({
    required String battingTeamId,
    required String bowlingTeamId,
    String? strikerId,
    String? nonStrikerId,
    String? bowlerId,
  }) async {
    final secondInnings = InningsModel(
      id: 'inn_${matchId}_2',
      matchId: matchId,
      inningsNumber: 2,
      battingTeamId: battingTeamId,
      bowlingTeamId: bowlingTeamId,
    );

    final battingPlayingVI = battingTeamId == state.match.teamAId
        ? state.match.teamAPlayingVI
        : state.match.teamBPlayingVI;
    final bowlingPlayingVI = bowlingTeamId == state.match.teamAId
        ? state.match.teamAPlayingVI
        : state.match.teamBPlayingVI;

    final s1 = strikerId ?? (battingPlayingVI.isNotEmpty ? battingPlayingVI[0] : 'p1');
    final s2 = nonStrikerId ?? (battingPlayingVI.length > 1 ? battingPlayingVI[1] : 'p2');
    final b1 = bowlerId ?? (bowlingPlayingVI.isNotEmpty ? bowlingPlayingVI[0] : 'b1');

    final initialBattingScores = {
      s1: BattingScore(
        id: '${secondInnings.id}_$s1',
        inningsId: secondInnings.id,
        playerId: s1,
        battingOrder: 1,
      ),
      s2: BattingScore(
        id: '${secondInnings.id}_$s2',
        inningsId: secondInnings.id,
        playerId: s2,
        battingOrder: 2,
      ),
    };

    final initialBowlingScores = {
      b1: BowlingScore(
        id: '${secondInnings.id}_$b1',
        inningsId: secondInnings.id,
        playerId: b1,
      ),
    };

    state = state.copyWith(
      firstInningsTotalRuns: state.innings.runs,
      innings: secondInnings,
      battingScores: initialBattingScores,
      bowlingScores: initialBowlingScores,
      strikerId: s1,
      nonStrikerId: s2,
      currentBowlerId: b1,
      clearCurrentBowler: false,
      previousBowlerId: null,
      undoStack: [],
      isNeedBowlerSelection: false,
      isSyncing: true,
    );

    try {
      await _syncService.saveInnings(secondInnings);
      await _syncService.recordDeliveryAtomic(
        match: state.match,
        innings: secondInnings,
        battingScores: initialBattingScores,
        bowlingScores: initialBowlingScores,
      );
      state = state.copyWith(isSyncing: false, lastSyncError: null);
    } catch (e) {
      debugPrint('[ScoringController] Error starting 2nd Innings in Firestore: $e');
      state = state.copyWith(isSyncing: false, lastSyncError: e.toString());
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
