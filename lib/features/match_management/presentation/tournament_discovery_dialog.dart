import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../scoring/models/tournament_model.dart';
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
                          DropdownMenuItem(value: 'TAPE_BALL_INDOOR', child: Text('Indoor Tape Ball (4 Overs)')),
                          DropdownMenuItem(value: 'T10', child: Text('T10 (10 Overs)')),
                          DropdownMenuItem(value: 'T20', child: Text('T20 (20 Overs)')),
                          DropdownMenuItem(value: 'CUSTOM', child: Text('Custom')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedFormat = val;
                              if (val == 'TAPE_BALL_INDOOR') overs = 4;
                              if (val == 'T10') overs = 10;
                              if (val == 'T20') overs = 20;
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

                      final autoId = 'tour_${DateTime.now().millisecondsSinceEpoch}';
                      final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');

                      final newTournament = TournamentModel(
                        id: autoId,
                        name: name,
                        shortName: shortName,
                        slug: slug,
                        formatType: selectedFormat,
                        oversPerSide: overs,
                        maxWickets: maxWickets,
                        scorerPin: pin,
                        venueName: venueController.text.trim(),
                        status: 'LIVE',
                        createdAt: DateTime.now().toIso8601String(),
                      );

                      final service = ref.read(scoringServiceProvider);
                      await service.saveTournament(newTournament);

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
    final tournamentsAsync = ref.watch(allTournamentsProvider);
    final activeId = ref.watch(activeTournamentIdProvider);

    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 560, maxWidth: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Bar
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppColors.accent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tournament Switcher',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
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
              child: tournamentsAsync.when(
                data: (tournaments) {
                  final filtered = tournaments.where((t) {
                    if (_searchQuery.isEmpty) return true;
                    return t.name.toLowerCase().contains(_searchQuery) ||
                        t.shortName.toLowerCase().contains(_searchQuery) ||
                        t.venueName.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No tournaments found',
                        style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13),
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
                                      tournamentId: item.id,
                                      tournamentName: item.name,
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

            // "+ Create Tournament" Button
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
            ),
          ],
        ),
      ),
    );
  }
}
