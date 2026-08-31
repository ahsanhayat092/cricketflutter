import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/offline_scoring_storage.dart';
import '../data/offline_sync_manager.dart';
import '../../match_management/providers/tournament_providers.dart';

/// Offline Scoring Storage Provider
final offlineScoringStorageProvider = Provider<OfflineScoringStorage>((ref) {
  return OfflineScoringStorage();
});

/// Offline Sync Manager Provider (ChangeNotifier)
final offlineSyncManagerProvider = ChangeNotifierProvider<OfflineSyncManager>((ref) {
  final storage = ref.watch(offlineScoringStorageProvider);
  final syncService = ref.watch(scoringSyncServiceProvider);
  return OfflineSyncManager(storage: storage, syncService: syncService);
});

/// Reactive Sync Status Provider
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final manager = ref.watch(offlineSyncManagerProvider);
  return manager.status;
});

/// Reactive Count of Pending Offline Sync Actions
final pendingSyncCountProvider = Provider<int>((ref) {
  final manager = ref.watch(offlineSyncManagerProvider);
  return manager.pendingCount;
});

/// Reactive Boolean: Is device currently online
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(syncStatusProvider);
  return status != SyncStatus.offline;
});
