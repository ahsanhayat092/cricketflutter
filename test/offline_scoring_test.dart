import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wpl_cricket_app/features/scoring/models/match_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/innings_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/batting_score.dart';
import 'package:wpl_cricket_app/features/scoring/models/bowling_score.dart';
import 'package:wpl_cricket_app/features/scoring/data/offline_scoring_storage.dart';
import 'package:wpl_cricket_app/features/scoring/data/offline_sync_manager.dart';
import 'package:wpl_cricket_app/features/scoring/data/scoring_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late OfflineScoringStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = OfflineScoringStorage(prefs: prefs);
  });

  final sampleMatch = MatchModel(
    id: 'match_offline_1',
    matchNumber: 1,
    stage: 'LEAGUE',
    teamAId: 'team_a',
    teamBId: 'team_b',
    date: '2026-08-27',
    tournamentId: 'tour_test',
  );

  final sampleInnings = InningsModel(
    id: 'inn_match_offline_1_1',
    matchId: 'match_offline_1',
    inningsNumber: 1,
    battingTeamId: 'team_a',
    bowlingTeamId: 'team_b',
    runs: 24,
    balls: 12,
    wickets: 1,
  );

  final Map<String, BattingScore> sampleBattingScores = {
    'p1': const BattingScore(id: 'inn_1_p1', inningsId: 'inn_1', playerId: 'p1', runs: 18, balls: 8),
    'p2': const BattingScore(id: 'inn_1_p2', inningsId: 'inn_1', playerId: 'p2', runs: 6, balls: 4),
  };

  final Map<String, BowlingScore> sampleBowlingScores = {
    'b1': const BowlingScore(id: 'inn_1_b1', inningsId: 'inn_1', playerId: 'b1', balls: 6, runs: 12, wickets: 1),
    'b2': const BowlingScore(id: 'inn_1_b2', inningsId: 'inn_1', playerId: 'b2', balls: 6, runs: 12, wickets: 0),
  };

  group('OfflineScoringStorage Tests', () {
    test('Saves and restores match snapshot locally without network', () async {
      await storage.saveMatchSnapshot(
        matchId: 'match_offline_1',
        match: sampleMatch,
        innings: sampleInnings,
        firstInningsTotalRuns: null,
        battingScores: sampleBattingScores,
        bowlingScores: sampleBowlingScores,
        strikerId: 'p1',
        nonStrikerId: 'p2',
        currentBowlerId: 'b2',
        previousBowlerId: 'b1',
        undoStack: [],
        teamNames: {'team_a': 'Titans', 'team_b': 'Warriors'},
        playerNames: {'p1': 'Alice', 'p2': 'Bob', 'b1': 'Charlie', 'b2': 'David'},
      );

      final restored = await storage.getMatchSnapshot('match_offline_1');
      expect(restored, isNotNull);
      expect(restored!['match']['id'], equals('match_offline_1'));
      expect(restored['innings']['runs'], equals(24));
      expect(restored['innings']['wickets'], equals(1));
      expect(restored['strikerId'], equals('p1'));
      expect(restored['currentBowlerId'], equals('b2'));
      expect(restored['teamNames']['team_a'], equals('Titans'));
      expect(restored['playerNames']['p1'], equals('Alice'));
    });

    test('Sync Action Queue FIFO order and removal', () async {
      final action1 = SyncAction(
        id: 'act_1',
        matchId: 'match_offline_1',
        type: SyncActionType.recordDelivery,
        payload: {'ball': 1},
        createdAt: DateTime.now().toIso8601String(),
      );

      final action2 = SyncAction(
        id: 'act_2',
        matchId: 'match_offline_1',
        type: SyncActionType.recordDelivery,
        payload: {'ball': 2},
        createdAt: DateTime.now().toIso8601String(),
      );

      await storage.enqueueSyncAction(action1);
      await storage.enqueueSyncAction(action2);

      var queue = await storage.getPendingSyncQueue();
      expect(queue.length, equals(2));
      expect(queue[0].id, equals('act_1'));
      expect(queue[1].id, equals('act_2'));

      expect(await storage.getPendingCount(), equals(2));

      await storage.removeSyncAction('act_1');
      queue = await storage.getPendingSyncQueue();
      expect(queue.length, equals(1));
      expect(queue[0].id, equals('act_2'));
      expect(await storage.getPendingCount(), equals(1));

      final lastSync = await storage.getLastSyncTimestamp();
      expect(lastSync, isNotNull);
    });
  });

  group('OfflineSyncManager Tests', () {
    test('Enqueues action and records pending count', () async {
      final fakeSyncService = _FakeScoringSyncService();
      final manager = OfflineSyncManager(
        storage: storage,
        syncService: fakeSyncService,
      );

      final action = SyncAction(
        id: 'act_del_1',
        matchId: 'match_offline_1',
        type: SyncActionType.recordDelivery,
        payload: {
          'tournamentId': 'tour_test',
          'match': sampleMatch.toMap(),
          'innings': sampleInnings.toMap(),
          'battingScores': sampleBattingScores.map((k, v) => MapEntry(k, v.toMap())),
          'bowlingScores': sampleBowlingScores.map((k, v) => MapEntry(k, v.toMap())),
        },
        createdAt: DateTime.now().toIso8601String(),
      );

      await storage.enqueueSyncAction(action);
      await manager.onActionEnqueued();

      // Flushes through queue
      await manager.syncPendingQueue();

      expect(fakeSyncService.recordedDeliveriesCount, equals(1));
      expect(manager.pendingCount, equals(0));
      expect(manager.status, equals(SyncStatus.synced));

      manager.dispose();
    });

    test('Processes finalizeMatch action and triggers standings recalculation', () async {
      final fakeSyncService = _FakeScoringSyncService();
      final manager = OfflineSyncManager(
        storage: storage,
        syncService: fakeSyncService,
      );

      final action = SyncAction(
        id: 'act_final_1',
        matchId: 'match_offline_1',
        type: SyncActionType.finalizeMatch,
        payload: {
          'winningTeamId': 'team_a',
          'resultText': 'Team A won by 10 runs',
          'playerOfMatchId': 'p1',
          'tournamentId': 'tour_test',
        },
        createdAt: DateTime.now().toIso8601String(),
      );

      await storage.enqueueSyncAction(action);
      await manager.syncPendingQueue();

      expect(fakeSyncService.finalizedMatchesCount, equals(1));
      expect(fakeSyncService.recalculatedTournaments.contains('tour_test'), isTrue);
      expect(manager.pendingCount, equals(0));
      expect(manager.status, equals(SyncStatus.synced));

      manager.dispose();
    });
  });
}

class _FakeScoringSyncService extends ScoringSyncService {
  int recordedDeliveriesCount = 0;
  int finalizedMatchesCount = 0;
  final Set<String> recalculatedTournaments = {};

  @override
  Future<void> ensureAuthenticated() async {}

  @override
  Future<void> recordDeliveryAtomic({
    required MatchModel match,
    required InningsModel innings,
    required Map<String, BattingScore> battingScores,
    required Map<String, BowlingScore> bowlingScores,
  }) async {
    recordedDeliveriesCount += 1;
  }

  @override
  Future<void> finalizeMatch({
    required String matchId,
    required String winningTeamId,
    required String resultText,
    String? playerOfMatchId,
    String tournamentId = 'main',
  }) async {
    finalizedMatchesCount += 1;
  }

  @override
  Future<void> recalculateTournamentStandings({String tournamentId = 'main'}) async {
    recalculatedTournaments.add(tournamentId);
  }
}
