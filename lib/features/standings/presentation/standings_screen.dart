import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../match_management/providers/tournament_providers.dart';
import '../../scoring/models/tournament_model.dart';
import '../models/standing.dart';
import '../providers/standings_provider.dart';

class StandingsScreen extends ConsumerStatefulWidget {
  const StandingsScreen({super.key});

  @override
  ConsumerState<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends ConsumerState<StandingsScreen> {
  String _selectedGroupTab = 'ALL'; // 'ALL' | 'A' | 'B'

  @override
  Widget build(BuildContext context) {
    final standingsAsync = ref.watch(standingsStreamProvider);
    final tournamentAsync = ref.watch(activeTournamentProvider);
    final tournament = tournamentAsync.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'STANDINGS & POINTS TABLE',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 0.8),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.accentCyan),
            tooltip: 'Refresh Standings',
            onPressed: () => ref.invalidate(standingsStreamProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(standingsStreamProvider),
        child: standingsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.wicket),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load standings',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$err',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('RETRY'),
                    onPressed: () => ref.invalidate(standingsStreamProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (standingsList) => _buildStandingsContent(context, standingsList, tournament),
        ),
      ),
    );
  }

  Widget _buildStandingsContent(
    BuildContext context,
    List<StandingWithTeam> list,
    TournamentModel? tournament,
  ) {
    final isGroupFormat = tournament?.isGroupsAndKnockout == true ||
        (tournament?.groups != null && tournament!.groups!.isNotEmpty);
    final advanceCount = tournament?.teamsPerGroupAdvance ?? 2;

    String subtitle;
    if (isGroupFormat) {
      if (tournament?.groupPlayoffFormat == 'GROUP_DIRECT_FINAL') {
        subtitle = 'Top 1 from each group qualifies directly for the Grand Final';
      } else {
        subtitle = 'Top $advanceCount from Group A & Group B qualify for Semi-Finals';
      }
    } else {
      subtitle = 'Top 2 teams qualify directly for the Grand Final';
    }

    final groupA = list.where((item) {
      final g = item.standing.groupName ?? item.team?.groupName ?? 'A';
      return g.toUpperCase() == 'A';
    }).toList();

    final groupB = list.where((item) {
      final g = item.standing.groupName ?? item.team?.groupName ?? 'B';
      return g.toUpperCase() == 'B';
    }).toList();

    // Sort group-scoped by position, then points, then NRR
    groupA.sort((a, b) {
      if (a.standing.position != b.standing.position) {
        return a.standing.position.compareTo(b.standing.position);
      }
      if (b.standing.points != a.standing.points) {
        return b.standing.points.compareTo(a.standing.points);
      }
      return b.standing.nrr.compareTo(a.standing.nrr);
    });

    groupB.sort((a, b) {
      if (a.standing.position != b.standing.position) {
        return a.standing.position.compareTo(b.standing.position);
      }
      if (b.standing.points != a.standing.points) {
        return b.standing.points.compareTo(a.standing.points);
      }
      return b.standing.nrr.compareTo(a.standing.nrr);
    });

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Qualification Info Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.15),
                  AppColors.accentCyan.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events_rounded, color: Colors.black, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament?.name ?? 'Cricket Tournament',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentCyan,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Champion Banner if crowned
          if (tournament?.championTeamId != null && tournament!.championTeamId!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildChampionBanner(list, tournament.championTeamId!),
          ],

          const SizedBox(height: 16),

          // 2. Format specific tables
          if (isGroupFormat) ...[
            // Group Filter Pills
            Row(
              children: [
                _buildGroupFilterPill('ALL', 'All Groups'),
                const SizedBox(width: 8),
                _buildGroupFilterPill('A', 'Group A (${groupA.length})'),
                const SizedBox(width: 8),
                _buildGroupFilterPill('B', 'Group B (${groupB.length})'),
              ],
            ),
            const SizedBox(height: 16),

            if (_selectedGroupTab == 'ALL' || _selectedGroupTab == 'A') ...[
              _buildGroupSection(
                groupName: 'Group A',
                items: groupA,
                advanceCount: advanceCount,
                qualificationLabel: tournament?.groupPlayoffFormat == 'GROUP_DIRECT_FINAL' ? 'Final (Q)' : 'Semi-Final (Q)',
              ),
              const SizedBox(height: 20),
            ],

            if (_selectedGroupTab == 'ALL' || _selectedGroupTab == 'B') ...[
              _buildGroupSection(
                groupName: 'Group B',
                items: groupB,
                advanceCount: advanceCount,
                qualificationLabel: tournament?.groupPlayoffFormat == 'GROUP_DIRECT_FINAL' ? 'Final (Q)' : 'Semi-Final (Q)',
              ),
              const SizedBox(height: 20),
            ],
          ] else ...[
            // Standard Unified Table
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildTableHeader(),
                  const Divider(height: 1, color: Colors.white10),
                  ...list.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return _buildTableRow(
                      index + 1,
                      item,
                      isLast: index == list.length - 1,
                      isQualifiedZone: index < 2,
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 3. Points Rules & Tiebreaker System Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text(
                      'CENTRAL BRAIN SCORING & NRR RULES',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildLegendItem('Win', '2 Points'),
                _buildLegendItem('Tie / No Result', '1 Point'),
                _buildLegendItem('Loss', '0 Points'),
                _buildLegendItem(
                  'ICC Net Run Rate (NRR)',
                  '(Total Runs Scored / Overs Faced) - (Total Runs Conceded / Overs Bowled)',
                ),
                _buildLegendItem('Tiebreaker', 'Points > Higher NRR > Head to Head'),
                if (isGroupFormat)
                  _buildLegendItem('Knockout Bracket', 'A1 vs B2 & B1 vs A2 (Winners advance to Grand Final)'),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGroupFilterPill(String tabKey, String label) {
    final isSelected = _selectedGroupTab == tabKey;
    return InkWell(
      onTap: () => setState(() => _selectedGroupTab = tabKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.white10,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildChampionBanner(List<StandingWithTeam> list, String championId) {
    final champ = list.firstWhere(
      (item) => item.team?.id == championId || item.standing.teamId == championId,
      orElse: () => list.first,
    );
    final name = champ.team?.name ?? champ.standing.teamName ?? 'Champion';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOURNAMENT CHAMPION',
                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.gold, letterSpacing: 0.5),
                ),
                Text(
                  name,
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection({
    required String groupName,
    required List<StandingWithTeam> items,
    required int advanceCount,
    required String qualificationLabel,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      groupName.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.completedGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.completedGreen.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Top $advanceCount Qualify',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.completedGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          _buildTableHeader(),
          const Divider(height: 1, color: Colors.white10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text('No teams in $groupName', style: GoogleFonts.outfit(color: AppColors.textMuted)),
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isQualZone = index < advanceCount;
              return _buildTableRow(
                index + 1,
                item,
                isLast: index == items.length - 1,
                isQualifiedZone: isQualZone,
                qualificationLabel: qualificationLabel,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(flex: 7, child: Text('TEAM', style: _headerStyle)),
          Expanded(flex: 2, child: Text('P', textAlign: TextAlign.center, style: _headerStyle)),
          Expanded(flex: 2, child: Text('W', textAlign: TextAlign.center, style: _headerStyle)),
          Expanded(flex: 2, child: Text('L', textAlign: TextAlign.center, style: _headerStyle)),
          Expanded(flex: 2, child: Text('T/NR', textAlign: TextAlign.center, style: _headerStyle)),
          Expanded(flex: 3, child: Text('NRR', textAlign: TextAlign.right, style: _headerStyle)),
          Expanded(flex: 3, child: Text('PTS', textAlign: TextAlign.right, style: _headerStyle)),
          Expanded(flex: 4, child: Text('FORM', textAlign: TextAlign.center, style: _headerStyle)),
        ],
      ),
    );
  }

  Widget _buildTableRow(
    int pos,
    StandingWithTeam item, {
    required bool isLast,
    bool isQualifiedZone = false,
    String? qualificationLabel,
  }) {
    final s = item.standing;
    final isQualified = s.status == 'QUALIFIED_PLAYOFF' || isQualifiedZone;
    final isEliminated = s.status == 'ELIMINATED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isQualified ? AppColors.accent.withValues(alpha: 0.04) : Colors.transparent,
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          // 1. Team & Rank
          Expanded(
            flex: 7,
            child: Row(
              children: [
                // Qualification Bar / Position Number
                Container(
                  width: 20,
                  alignment: Alignment.center,
                  child: Text(
                    '$pos',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isQualified ? AppColors.accent : AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Team Logo
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: item.logoUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.logoUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _fallbackLogo(item.shortName),
                          )
                        : _fallbackLogo(item.shortName),
                  ),
                ),
                const SizedBox(width: 8),

                // Short Name & Full Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.shortName,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (isQualified) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.completedGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.completedGreen.withValues(alpha: 0.4), width: 0.8),
                              ),
                              child: Text(
                                qualificationLabel ?? 'Q',
                                style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.completedGreen),
                              ),
                            ),
                          ] else if (isEliminated) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.wicket.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.wicket.withValues(alpha: 0.4), width: 0.8),
                              ),
                              child: Text(
                                'Eliminated',
                                style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w800, color: AppColors.wicket),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        item.teamName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Played
          Expanded(
            flex: 2,
            child: Text('${s.played}', textAlign: TextAlign.center, style: _cellStyle),
          ),

          // 3. Won
          Expanded(
            flex: 2,
            child: Text('${s.won}', textAlign: TextAlign.center, style: _cellStyle),
          ),

          // 4. Lost
          Expanded(
            flex: 2,
            child: Text('${s.lost}', textAlign: TextAlign.center, style: _cellStyle),
          ),

          // 5. Tied / No Result
          Expanded(
            flex: 2,
            child: Text('${s.tied + s.noResult}', textAlign: TextAlign.center, style: _cellStyle),
          ),

          // 6. Net Run Rate
          Expanded(
            flex: 3,
            child: Text(
              s.nrrFormatted,
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: s.nrr >= 0 ? AppColors.completedGreen : AppColors.wicket,
              ),
            ),
          ),

          // 7. Points
          Expanded(
            flex: 3,
            child: Text(
              '${s.points}',
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: isQualified ? AppColors.accent : AppColors.textPrimary,
              ),
            ),
          ),

          // 8. Form Strip (Last results)
          Expanded(
            flex: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: s.form.isEmpty
                  ? [Text('-', style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12))]
                  : s.form.take(3).map((f) => _buildFormPill(f)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPill(String result) {
    final isWin = result == 'W';
    final isTie = result == 'T' || result == 'NR';

    Color color = AppColors.wicket;
    if (isWin) {
      color = AppColors.completedGreen;
    } else if (isTie) {
      color = AppColors.gold;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        result,
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildLegendItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: GoogleFonts.outfit(color: AppColors.accent, fontWeight: FontWeight.bold)),
          Text('$title: ', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Expanded(
            child: Text(desc, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _fallbackLogo(String shortName) {
    return Center(
      child: Text(
        shortName.isNotEmpty ? shortName[0] : 'T',
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  TextStyle get _headerStyle => GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      );

  TextStyle get _cellStyle => GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      );
}
