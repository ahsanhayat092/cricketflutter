import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../models/standing.dart';
import '../providers/standings_provider.dart';

class StandingsScreen extends ConsumerWidget {
  const StandingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(standingsStreamProvider);

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
          data: (standingsList) => _buildStandingsContent(context, standingsList),
        ),
      ),
    );
  }

  Widget _buildStandingsContent(BuildContext context, List<StandingWithTeam> list) {
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
                        'WASA Premier League 2026',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentCyan,
                        ),
                      ),
                      Text(
                        'Top 2 teams qualify directly for the Grand Final',
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

          const SizedBox(height: 16),

          // 2. Standings Table Container
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
                  return _buildTableRow(index + 1, item, isLast: index == list.length - 1);
                }),
              ],
            ),
          ),

          const SizedBox(height: 20),

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
                      'TOURNAMENT SCORING & NRR RULES',
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
                  'Net Run Rate (NRR)',
                  '(Runs Scored / Overs Faced) - (Runs Conceded / Overs Bowled)',
                ),
                _buildLegendItem('Tiebreaker', 'Points > Higher NRR > Head to Head'),
              ],
            ),
          ),
          const SizedBox(height: 24),
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

  Widget _buildTableRow(int pos, StandingWithTeam item, {required bool isLast}) {
    final s = item.standing;
    final isTopTwo = pos <= 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isTopTwo ? AppColors.accent.withValues(alpha: 0.04) : Colors.transparent,
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
                      color: isTopTwo ? AppColors.accent : AppColors.textMuted,
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
                          if (isTopTwo) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.star_rounded, size: 12, color: AppColors.gold),
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
                color: isTopTwo ? AppColors.accent : AppColors.textPrimary,
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
