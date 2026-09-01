import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../scoring/models/tournament_model.dart';
import '../../auth/models/tournament_member_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/tournament_providers.dart';
import '../../auth/presentation/scorer_pin_auth_dialog.dart';

class TournamentDiscoveryDialog extends ConsumerStatefulWidget {
  const TournamentDiscoveryDialog({super.key});

  @override
  ConsumerState<TournamentDiscoveryDialog> createState() => _TournamentDiscoveryDialogState();
}

class _TournamentDiscoveryDialogState extends ConsumerState<TournamentDiscoveryDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _shareTournamentWhatsApp(TournamentModel tournament) async {
    final text = Uri.encodeComponent(tournament.shareWhatsAppText);
    final url = Uri.parse('https://api.whatsapp.com/send?text=$text');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _showCreateTournamentModal() {
    final nameController = TextEditingController();
    final shortNameController = TextEditingController();
    final venueController = TextEditingController(text: 'Sports Ground');
    String selectedFormat = 'TAPE_BALL_INDOOR';
    int overs = 4;
    int playersPerTeam = 6;
    bool allowLms = true;
    int maxWickets = 6;
    final pinController = TextEditingController(text: '1234');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, color: AppColors.accent, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Create Tournament',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: GoogleFonts.outfit(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Tournament Name *',
                    labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                    hintText: 'e.g. Lahore Champions Trophy 2026',
                    hintStyle: GoogleFonts.outfit(color: AppColors.textMuted.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: shortNameController,
                        style: GoogleFonts.outfit(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Short Name / Tag *',
                          labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                          hintText: 'e.g. LCT 2026',
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        style: GoogleFonts.outfit(color: AppColors.accent, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          counterText: '',
                          labelText: '4-Digit Scorer PIN *',
                          labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                          hintText: '1234',
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: venueController,
                  style: GoogleFonts.outfit(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Venue Name',
                    labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: selectedFormat,
                        dropdownColor: AppColors.surfaceLight,
                        style: GoogleFonts.outfit(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Format',
                          labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'TAPE_BALL_INDOOR', child: Text('Indoor Tape Ball (6-a-side, 4 Overs)')),
                          DropdownMenuItem(value: 'T10', child: Text('T10 (11-a-side, 10 Overs)')),
                          DropdownMenuItem(value: 'T20', child: Text('T20 (11-a-side, 20 Overs)')),
                          DropdownMenuItem(value: 'CUSTOM', child: Text('Custom')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedFormat = val;
                              if (val == 'TAPE_BALL_INDOOR') {
                                overs = 4;
                                playersPerTeam = 6;
                                allowLms = true;
                                maxWickets = 6;
                              } else if (val == 'T10') {
                                overs = 10;
                                playersPerTeam = 11;
                                allowLms = false;
                                maxWickets = 10;
                              } else if (val == 'T20') {
                                overs = 20;
                                playersPerTeam = 11;
                                allowLms = false;
                                maxWickets = 10;
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        value: playersPerTeam,
                        dropdownColor: AppColors.surfaceLight,
                        style: GoogleFonts.outfit(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Squad / Team',
                          labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5 Players')),
                          DropdownMenuItem(value: 6, child: Text('6 Players')),
                          DropdownMenuItem(value: 7, child: Text('7 Players')),
                          DropdownMenuItem(value: 8, child: Text('8 Players')),
                          DropdownMenuItem(value: 9, child: Text('9 Players')),
                          DropdownMenuItem(value: 10, child: Text('10 Players')),
                          DropdownMenuItem(value: 11, child: Text('11 Players')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              playersPerTeam = val;
                              allowLms = playersPerTeam <= 8;
                              maxWickets = allowLms ? playersPerTeam : playersPerTeam - 1;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final shortName = shortNameController.text.trim();
                      final pin = pinController.text.trim().isEmpty ? '1234' : pinController.text.trim();
                      if (name.isEmpty || shortName.isEmpty) return;

                      final user = ref.read(currentUserProvider);
                      final autoId = 'tour_${DateTime.now().millisecondsSinceEpoch}';
                      final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');

                      final newTournament = TournamentModel(
                        id: autoId,
                        name: name,
                        shortName: shortName,
                        slug: slug,
                        formatType: selectedFormat,
                        oversPerSide: overs,
                        playersPerTeam: playersPerTeam,
                        maxWickets: maxWickets,
                        allowLastManStanding: allowLms,
                        scorerPin: pin,
                        ownerId: user.uid.isNotEmpty && user.uid != 'guest' ? user.uid : null,
                        ownerEmail: user.email.isNotEmpty ? user.email : null,
                        venueName: venueController.text.trim(),
                        status: 'LIVE',
                        createdAt: DateTime.now().toIso8601String(),
                      );

                      final service = ref.read(scoringServiceProvider);
                      await service.saveTournament(newTournament);

                      if (user.email.isNotEmpty) {
                        final ownerMember = TournamentMemberModel(
                          id: '${autoId}_${user.email.toLowerCase().trim()}',
                          tournamentId: autoId,
                          userId: user.uid,
                          userEmail: user.email,
                          userName: user.name.isNotEmpty ? user.name : user.email.split('@').first,
                          role: 'OWNER',
                          createdAt: DateTime.now().toIso8601String(),
                        );
                        await service.saveTournamentMember(ownerMember);
                      }

                      // Unlock for current user session
                      await ref.read(unlockedTournamentsProvider.notifier).unlockTournament(autoId);

                      // Set active
                      ref.read(activeTournamentIdProvider.notifier).state = autoId;
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('CREATE & SET ACTIVE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isPlatformAdmin = currentUser.isPlatformAdmin;
    final unlockedIds = ref.watch(unlockedTournamentsProvider);
    final allTournamentsAsync = ref.watch(allTournamentsProvider);
    final scorableTournaments = ref.watch(scorableTournamentsProvider);
    final activeId = ref.watch(activeTournamentIdProvider);

    // Scorers and PIN users are scoped to authorized tournaments
    final isScopedScorer = !isPlatformAdmin && (currentUser.isScorer || unlockedIds.isNotEmpty);

    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 580, maxWidth: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Bar
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppColors.accent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isScopedScorer ? 'Allowed Tournaments' : 'Tournament Switcher',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (isScopedScorer)
                        Text(
                          '${scorableTournaments.length} tournament${scorableTournaments.length == 1 ? "" : "s"} authorized for your session',
                          style: GoogleFonts.outfit(fontSize: 10, color: AppColors.accentCyan),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Single Tournament Active / Locked Banner
            if (isScopedScorer && scorableTournaments.length == 1)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Scoped strictly to unlocked tournament: ${scorableTournaments.first.shortName}',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent),
                      ),
                    ),
                  ],
                ),
              ),

            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search tournament or venue...',
                hintStyle: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 18),
                filled: true,
                fillColor: AppColors.surfaceLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Tournaments List
            Expanded(
              child: allTournamentsAsync.when(
                data: (allTournaments) {
                  final listToFilter = isScopedScorer ? scorableTournaments : allTournaments;
                  final filtered = listToFilter.where((t) {
                    if (_searchQuery.isEmpty) return true;
                    return t.name.toLowerCase().contains(_searchQuery) ||
                        t.shortName.toLowerCase().contains(_searchQuery) ||
                        t.venueName.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_clock_outlined, size: 36, color: AppColors.textMuted),
                            const SizedBox(height: 8),
                            Text(
                              isScopedScorer ? 'No authorized tournaments unlocked' : 'No tournaments found',
                              style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isActive = item.id == activeId;

                      return InkWell(
                        onTap: () {
                          ref.read(activeTournamentIdProvider.notifier).state = item.id;
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.accent.withValues(alpha: 0.15)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive ? AppColors.accent : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isActive ? AppColors.accent : AppColors.cardBackground,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  item.shortName.length > 3
                                      ? item.shortName.substring(0, 3).toUpperCase()
                                      : item.shortName.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: isActive ? Colors.black : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isActive ? AppColors.accent : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          '${item.oversPerSide} Overs • ${item.venueName}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // WhatsApp Share Button
                              IconButton(
                                onPressed: () => _shareTournamentWhatsApp(item),
                                icon: const Icon(Icons.share_rounded, size: 16, color: AppColors.accentCyan),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              // Scorer PIN Key
                              IconButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => ScorerPinAuthDialog(
                                      initialTournamentId: item.id,
                                      initialTournamentName: item.name,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.pin_rounded, size: 16, color: AppColors.accent),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                error: (e, _) => Center(child: Text('Error loading tournaments: $e')),
              ),
            ),
            const SizedBox(height: 12),

            // Action Buttons based on Role
            if (isScopedScorer)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const ScorerPinAuthDialog(),
                    );
                  },
                  icon: const Icon(Icons.pin_rounded, size: 18),
                  label: Text(
                    'UNLOCK ANOTHER TOURNAMENT VIA PIN',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            else ...[
              // Platform Admin / Tournament Admin gets "+ CREATE NEW TOURNAMENT"
              if (currentUser.isAdmin)
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _showCreateTournamentModal,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      '+ CREATE NEW TOURNAMENT',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const ScorerPinAuthDialog(),
                      );
                    },
                    icon: const Icon(Icons.pin_rounded, size: 18),
                    label: Text(
                      'GROUND SCORER PIN ACCESS',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
