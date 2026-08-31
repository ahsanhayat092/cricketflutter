import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/offline_sync_manager.dart';
import '../../providers/offline_sync_providers.dart';

class ScoringSyncBadge extends ConsumerWidget {
  final bool compact;
  const ScoringSyncBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider);

    Color badgeColor;
    Color textColor;
    IconData iconData;
    String label;
    bool isSpinning = false;

    switch (status) {
      case SyncStatus.synced:
        if (pendingCount > 0) {
          badgeColor = AppColors.gold.withValues(alpha: 0.2);
          textColor = AppColors.gold;
          iconData = Icons.cloud_queue_rounded;
          label = '$pendingCount Queued';
        } else {
          badgeColor = AppColors.accent.withValues(alpha: 0.15);
          textColor = AppColors.accent;
          iconData = Icons.cloud_done_rounded;
          label = 'Synced';
        }
        break;

      case SyncStatus.syncing:
        badgeColor = AppColors.accentCyan.withValues(alpha: 0.2);
        textColor = AppColors.accentCyan;
        iconData = Icons.sync_rounded;
        label = pendingCount > 0 ? 'Syncing ($pendingCount)' : 'Syncing...';
        isSpinning = true;
        break;

      case SyncStatus.offline:
        badgeColor = Colors.amber.withValues(alpha: 0.2);
        textColor = Colors.amber;
        iconData = Icons.cloud_off_rounded;
        label = pendingCount > 0 ? 'Offline ($pendingCount)' : 'Offline';
        break;

      case SyncStatus.error:
        badgeColor = AppColors.wicket.withValues(alpha: 0.2);
        textColor = AppColors.wicket;
        iconData = Icons.sync_problem_rounded;
        label = 'Sync Paused';
        break;
    }

    if (compact) {
      return Tooltip(
        message: 'Cloud Sync: $label (Tap for details)',
        child: InkWell(
          onTap: () => _showSyncDetailsModal(context, ref),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: textColor.withValues(alpha: 0.35), width: 1),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (isSpinning)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                else
                  Icon(iconData, size: 18, color: textColor),
                if (pendingCount > 0 && status != SyncStatus.syncing)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$pendingCount',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _showSyncDetailsModal(context, ref),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: textColor.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSpinning)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            else
              Icon(iconData, size: 14, color: textColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSyncDetailsModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final status = ref.watch(syncStatusProvider);
            final pendingCount = ref.watch(pendingSyncCountProvider);
            final manager = ref.watch(offlineSyncManagerProvider);
            final lastSync = manager.lastSyncTime;

            String statusTitle;
            String statusDesc;
            Color statusColor;
            IconData statusIcon;

            switch (status) {
              case SyncStatus.synced:
                if (pendingCount > 0) {
                  statusTitle = 'Changes Queued';
                  statusDesc = '$pendingCount scoring action(s) saved locally, waiting to flush.';
                  statusColor = AppColors.gold;
                  statusIcon = Icons.cloud_queue_rounded;
                } else {
                  statusTitle = 'All Scores Live & Synced';
                  statusDesc = 'All deliveries and match stats are up to date in the cloud database.';
                  statusColor = AppColors.accent;
                  statusIcon = Icons.check_circle_rounded;
                }
                break;
              case SyncStatus.syncing:
                statusTitle = 'Syncing to Cloud...';
                statusDesc = 'Uploading $pendingCount offline deliveries to Firebase Firestore.';
                statusColor = AppColors.accentCyan;
                statusIcon = Icons.sync_rounded;
                break;
              case SyncStatus.offline:
                statusTitle = 'Offline Scoring Active';
                statusDesc = 'No internet connection detected. Deliveries are securely stored on device and will automatically sync when online.';
                statusColor = Colors.amber;
                statusIcon = Icons.cloud_off_rounded;
                break;
              case SyncStatus.error:
                statusTitle = 'Sync Temporarily Paused';
                statusDesc = manager.lastError ?? 'Network timeout. Automatic retry will trigger shortly.';
                statusColor = AppColors.wicket;
                statusIcon = Icons.error_outline_rounded;
                break;
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(statusIcon, color: statusColor, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusTitle,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                statusDesc,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 14),

                    // Info Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoColumn(
                          label: 'PENDING MUTATIONS',
                          value: '$pendingCount actions',
                          color: pendingCount > 0 ? AppColors.gold : AppColors.accent,
                        ),
                        _buildInfoColumn(
                          label: 'LAST CLOUD SYNC',
                          value: lastSync != null ? DateFormat('hh:mm:ss a').format(lastSync) : 'Never / Cold Start',
                          color: AppColors.textPrimary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Manual Sync Now Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: status == SyncStatus.syncing
                            ? null
                            : () async {
                                await manager.syncPendingQueue();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: status == SyncStatus.syncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.sync_rounded),
                        label: Text(
                          status == SyncStatus.syncing ? 'SYNCING IN PROGRESS...' : 'SYNC NOW WITH CLOUD',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoColumn({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}
