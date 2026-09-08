import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../live_viewer/presentation/live_match_screen.dart';
import '../../live_viewer/presentation/match_scorecard_screen.dart';
import '../../match_management/presentation/match_lineup_screen.dart';
import '../../match_management/providers/tournament_providers.dart';
import '../../scoring/models/innings_model.dart';
import '../../scoring/models/match_model.dart';
import '../../scoring/models/team_model.dart';
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
    final matchesAsync = ref.watch(matchesProvider);
    final teamsAsync = ref.watch(teamsProvider);

    final tournament = tournamentAsync.value;
    final allMatches = matchesAsync.value ?? [];
    final allTeams = teamsAsync.value ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'STANDINGS & KNOCKOUTS',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 0.8),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.accentCyan),
            tooltip: 'Refresh Standings',
            onPressed: () {
              ref.invalidate(standingsStreamProvider);
              ref.invalidate(matchesProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(standingsStreamProvider);
          ref.invalidate(matchesProvider);
        },
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
                    onPressed: () {
                      ref.invalidate(standingsStreamProvider);
                      ref.invalidate(matchesProvider);
                    },
                  ),
                ],
              ),
            ),
          ),
          data: (standingsList) => _buildStandingsContent(
            context,
            standingsList,
            tournament,
            allMatches,
            allTeams,
          ),
        ),
      ),
    );
  }

  Widget _buildStandingsContent(
    BuildContext context,
    List<StandingWithTeam> list,
    TournamentModel? tournament,
    List<MatchModel> allMatches,
    List<TeamModel> allTeams,
  ) {
    final hasGroupedTeams = list.any((item) =>
        (item.standing.groupName ?? item.team?.groupName)?.trim().isNotEmpty == true);
    final isGroupFormat = (tournament?.isGroupsAndKnockout == true) ||
        (tournament?.groups != null && tournament!.groups!.isNotEmpty) ||
        (tournament?.groupCount != null && tournament!.groupCount! > 1) ||
        hasGroupedTeams;
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

    String resolveGroupName(StandingWithTeam item, int index) {
      final g = item.standing.groupName ?? item.team?.groupName;
      if (g != null && g.trim().isNotEmpty) {
        return g.trim().toUpperCase();
      }
      return index % 2 == 0 ? 'A' : 'B';
    }

    final Map<String, List<StandingWithTeam>> groupedStandings = {};
    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      final g = resolveGroupName(item, i);
      groupedStandings.putIfAbsent(g, () => []).add(item);
    }

    // Sort each group: Points desc -> Net Run Rate desc -> Wins desc -> Position
    for (final entry in groupedStandings.entries) {
      entry.value.sort((a, b) {
        if (b.standing.points != a.standing.points) {
          return b.standing.points.compareTo(a.standing.points);
        }
        if ((b.standing.nrr - a.standing.nrr).abs() > 0.0001) {
          return b.standing.nrr.compareTo(a.standing.nrr);
        }
        if (b.standing.won != a.standing.won) {
          return b.standing.won.compareTo(a.standing.won);
        }
        return a.standing.position.compareTo(b.standing.position);
      });
    }

    final sortedGroupKeys = groupedStandings.keys.toList()..sort();

    // 1. Identify Grand Final Match & Crowned Champion
    MatchModel? grandFinalMatch;
    for (final m in allMatches) {
      if (m.isFinal || m.stage.toUpperCase() == 'FINAL') {
        grandFinalMatch = m;
        break;
      }
    }

    final resolvedChampionId = (tournament?.championTeamId != null &&
            tournament!.championTeamId!.trim().isNotEmpty)
        ? tournament.championTeamId!.trim()
        : (grandFinalMatch != null &&
                grandFinalMatch.isCompleted &&
                grandFinalMatch.winningTeamId != null &&
                grandFinalMatch.winningTeamId!.trim().isNotEmpty
            ? grandFinalMatch.winningTeamId!.trim()
            : null);

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

          // Quick Champion Pill at Top (if already crowned)
          if (resolvedChampionId != null) ...[
            const SizedBox(height: 12),
            _buildChampionQuickBanner(list, allTeams, resolvedChampionId),
          ],

          const SizedBox(height: 16),

          // 2. Format specific tables (Group A & Group B or Unified)
          if (isGroupFormat) ...[
            // Group Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildGroupFilterPill('ALL', 'All Groups (${list.length})'),
                  for (final g in sortedGroupKeys) ...[
                    const SizedBox(width: 8),
                    _buildGroupFilterPill(g, 'Group $g (${groupedStandings[g]?.length ?? 0})'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            for (final g in sortedGroupKeys)
              if (_selectedGroupTab == 'ALL' || _selectedGroupTab == g) ...[
                _buildGroupSection(
                  groupKey: g,
                  items: groupedStandings[g] ?? [],
                  advanceCount: advanceCount,
                  qualificationLabel: tournament?.groupPlayoffFormat == 'GROUP_DIRECT_FINAL'
                      ? 'Final (Q)'
                      : 'Semi-Final (Q)',
                  subheaderTag: tournament?.groupPlayoffFormat == 'GROUP_DIRECT_FINAL'
                      ? 'Top 1 Advances to Grand Final'
                      : 'Top $advanceCount Advance to Semi-Finals',
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

          // 3. KNOCKOUT STAGE & SEMI-FINALS DETAILS SECTION (Directly After Standings)
          _buildKnockoutStageSection(
            context: context,
            tournament: tournament,
            allMatches: allMatches,
            allTeams: allTeams,
            standingsList: list,
            groupedStandings: groupedStandings,
            isGroupFormat: isGroupFormat,
            advanceCount: advanceCount,
          ),
          const SizedBox(height: 24),

          // 4. TOURNAMENT CHAMPION & PODIUM SHOWCASE (Who Won The Tournament Details)
          _buildChampionShowcaseCard(
            context: context,
            tournament: tournament,
            grandFinalMatch: grandFinalMatch,
            allTeams: allTeams,
            standingsList: list,
            resolvedChampionId: resolvedChampionId,
          ),
          const SizedBox(height: 24),

          // 5. Points Rules & Tiebreaker System Card
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
                  _buildLegendItem(
                    'Knockout Bracket',
                    tournament?.groupPlayoffFormat == 'GROUP_DIRECT_FINAL'
                        ? 'Winner Group A vs Winner Group B (Grand Final)'
                        : 'Semi-Final 1: A1 vs B2 • Semi-Final 2: B1 vs A2 (Winners advance to Grand Final)',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===========================================================================
  // KNOCKOUT STAGE & SEMI-FINALS SECTION
  // ===========================================================================
  Widget _buildKnockoutStageSection({
    required BuildContext context,
    required TournamentModel? tournament,
    required List<MatchModel> allMatches,
    required List<TeamModel> allTeams,
    required List<StandingWithTeam> standingsList,
    required Map<String, List<StandingWithTeam>> groupedStandings,
    required bool isGroupFormat,
    required int advanceCount,
  }) {
    // 1. Separate real knockout matches from Firestore
    final knockoutMatches = allMatches.where((m) => m.isKnockout).toList()
      ..sort((a, b) => a.matchNumber.compareTo(b.matchNumber));

    // Resolve leaders for projected cards if no match documents exist yet
    final sortedGroupA = groupedStandings['A'] ?? [];
    final sortedGroupB = groupedStandings['B'] ?? [];

    final topA1 = sortedGroupA.isNotEmpty ? sortedGroupA[0] : null;
    final topA2 = sortedGroupA.length > 1 ? sortedGroupA[1] : null;
    final topB1 = sortedGroupB.isNotEmpty ? sortedGroupB[0] : null;
    final topB2 = sortedGroupB.length > 1 ? sortedGroupB[1] : null;

    final topRank1 = standingsList.isNotEmpty ? standingsList[0] : null;
    final topRank2 = standingsList.length > 1 ? standingsList[1] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_tree_rounded, color: AppColors.accentCyan, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  'KNOCKOUT STAGE & SEMI-FINALS',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                knockoutMatches.isNotEmpty ? '${knockoutMatches.length} Fixtures' : 'Projected Bracket',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isGroupFormat
              ? 'Semi-Final 1 (A1 vs B2), Semi-Final 2 (B1 vs A2) and the Grand Final.'
              : 'Knockout playoff matches and Grand Final championship fixtures.',
          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),

        // 2. Render real knockout matches if available in Firestore
        if (knockoutMatches.isNotEmpty) ...[
          for (final match in knockoutMatches) ...[
            _KnockoutMatchCard(
              match: match,
              allTeams: allTeams,
              standingsList: standingsList,
              tournament: tournament,
            ),
            const SizedBox(height: 12),
          ],
        ] else ...[
          // 3. Fallback: Render projected knockout fixtures from current standings
          if (isGroupFormat) ...[
            if (tournament?.groupPlayoffFormat == 'GROUP_DIRECT_FINAL') ...[
              _ProjectedKnockoutCard(
                stageTitle: '🏆 GRAND FINAL (DIRECT FINAL)',
                matchSubheader: 'Winner Group A vs Winner Group B',
                teamAName: topA1?.teamName ?? 'Leader Group A (A1)',
                teamAShort: topA1?.shortName ?? 'A1',
                teamALogo: topA1?.logoUrl ?? '',
                teamBName: topB1?.teamName ?? 'Leader Group B (B1)',
                teamBShort: topB1?.shortName ?? 'B1',
                teamBLogo: topB1?.logoUrl ?? '',
                note: 'Top 1 from each group advances directly to the Grand Final.',
                isFinal: true,
              ),
            ] else ...[
              _ProjectedKnockoutCard(
                stageTitle: '🎯 SEMI-FINAL 1',
                matchSubheader: 'Winner Group A vs Runner-up Group B',
                teamAName: topA1?.teamName ?? 'Leader Group A (A1)',
                teamAShort: topA1?.shortName ?? 'A1',
                teamALogo: topA1?.logoUrl ?? '',
                teamBName: topB2?.teamName ?? 'Runner-up Group B (B2)',
                teamBShort: topB2?.shortName ?? 'B2',
                teamBLogo: topB2?.logoUrl ?? '',
                note: 'Winner advances to the Grand Final.',
                isFinal: false,
              ),
              const SizedBox(height: 12),
              _ProjectedKnockoutCard(
                stageTitle: '🎯 SEMI-FINAL 2',
                matchSubheader: 'Winner Group B vs Runner-up Group A',
                teamAName: topB1?.teamName ?? 'Leader Group B (B1)',
                teamAShort: topB1?.shortName ?? 'B1',
                teamALogo: topB1?.logoUrl ?? '',
                teamBName: topA2?.teamName ?? 'Runner-up Group A (A2)',
                teamBShort: topA2?.shortName ?? 'A2',
                teamBLogo: topA2?.logoUrl ?? '',
                note: 'Winner advances to the Grand Final.',
                isFinal: false,
              ),
              const SizedBox(height: 12),
              _ProjectedKnockoutCard(
                stageTitle: '🏆 GRAND FINAL',
                matchSubheader: 'Winner Semi-Final 1 vs Winner Semi-Final 2',
                teamAName: 'Winner Semi-Final 1',
                teamAShort: 'SF1',
                teamALogo: '',
                teamBName: 'Winner Semi-Final 2',
                teamBShort: 'SF2',
                teamBLogo: '',
                note: 'Ultimate championship match. Winner is crowned Tournament Champion.',
                isFinal: true,
              ),
            ],
          ] else ...[
            _ProjectedKnockoutCard(
              stageTitle: '🏆 GRAND FINAL',
              matchSubheader: 'Rank 1 vs Rank 2',
              teamAName: topRank1?.teamName ?? 'Rank 1 Team',
              teamAShort: topRank1?.shortName ?? 'R1',
              teamALogo: topRank1?.logoUrl ?? '',
              teamBName: topRank2?.teamName ?? 'Rank 2 Team',
              teamBShort: topRank2?.shortName ?? 'R2',
              teamBLogo: topRank2?.logoUrl ?? '',
              note: 'Top two ranked teams compete in the Grand Final for the championship trophy.',
              isFinal: true,
            ),
          ],
        ],
      ],
    );
  }

  // ===========================================================================
  // TOURNAMENT CHAMPION & PODIUM SHOWCASE
  // ===========================================================================
  Widget _buildChampionShowcaseCard({
    required BuildContext context,
    required TournamentModel? tournament,
    required MatchModel? grandFinalMatch,
    required List<TeamModel> allTeams,
    required List<StandingWithTeam> standingsList,
    required String? resolvedChampionId,
  }) {
    final tourName = tournament?.name ?? 'Cricket Tournament';

    // 1. If Champion is already Crowned
    if (resolvedChampionId != null && resolvedChampionId.isNotEmpty) {
      TeamModel? champTeam;
      for (final t in allTeams) {
        if (t.id == resolvedChampionId) {
          champTeam = t;
          break;
        }
      }
      if (champTeam == null) {
        for (final item in standingsList) {
          if (item.team?.id == resolvedChampionId || item.standing.teamId == resolvedChampionId) {
            champTeam = item.team ??
                TeamModel(
                  id: resolvedChampionId,
                  name: item.standing.teamName ?? 'Champion Team',
                  shortName: item.shortName,
                  logoUrl: item.logoUrl,
                );
            break;
          }
        }
      }

      final championName = champTeam?.name ?? 'Tournament Champion';
      final championLogo = champTeam?.formattedLogoUrl ?? '';

      // Determine Runner-Up
      String runnerUpName = 'Runner-Up Team';
      String runnerUpLogo = '';
      String runnerUpShort = 'RU';
      if (grandFinalMatch != null) {
        final runnerUpId = grandFinalMatch.teamAId == resolvedChampionId
            ? grandFinalMatch.teamBId
            : grandFinalMatch.teamAId;
        if (runnerUpId != null && runnerUpId.isNotEmpty) {
          for (final t in allTeams) {
            if (t.id == runnerUpId) {
              runnerUpName = t.name;
              runnerUpLogo = t.formattedLogoUrl;
              runnerUpShort = t.shortName;
              break;
            }
          }
          if (runnerUpName == 'Runner-Up Team') {
            for (final item in standingsList) {
              if (item.team?.id == runnerUpId || item.standing.teamId == runnerUpId) {
                runnerUpName = item.teamName;
                runnerUpLogo = item.logoUrl;
                runnerUpShort = item.shortName;
                break;
              }
            }
          }
        }
      }

      final finalResultText = grandFinalMatch?.resultText ?? 'Champions of $tourName';

      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2A2000),
              Color(0xFF1E1700),
              Color(0xFF13151D),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Top Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: Colors.black, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '🏆 TOURNAMENT CHAMPION CROWNED',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Champion Team Logo & Name
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.gold.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: championLogo.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: championLogo,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _fallbackLogoLarge(championName),
                            )
                          : _fallbackLogoLarge(championName),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star_rounded, color: Colors.black, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              championName.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'CHAMPIONS OF ${tourName.toUpperCase()}',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.gold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 16),

            // Victory Result Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: Text(
                finalResultText,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Podium: 1st & 2nd place
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  // 1st Place
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WINNER (1ST)',
                                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.gold),
                              ),
                              Text(
                                championName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 28, width: 1, color: Colors.white24),
                  const SizedBox(width: 12),
                  // 2nd Place
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade400, width: 1),
                          ),
                          child: ClipOval(
                            child: runnerUpLogo.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: runnerUpLogo,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => _fallbackLogo(runnerUpShort),
                                  )
                                : _fallbackLogo(runnerUpShort),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RUNNER-UP (2ND)',
                                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
                              ),
                              Text(
                                runnerUpName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons (Scorecard & Share)
            Row(
              children: [
                if (grandFinalMatch != null) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: Text(
                        'FINAL SCORECARD',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchScorecardScreen(matchId: grandFinalMatch.id),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentCyan,
                      side: const BorderSide(color: AppColors.accentCyan, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: Text(
                      'SHARE RESULT',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                    onPressed: () {
                      final shareUrl = tournament?.shareUrl ?? 'https://wasacricket.vercel.app';
                      final message = '🏆 *$championName* are crowned CHAMPIONS of *$tourName*!\n'
                          '🥈 Runner-Up: $runnerUpName\n'
                          '🔥 Final Result: $finalResultText\n\n'
                          '📊 Check full tournament standings & scorecard: $shareUrl';
                      final text = Uri.encodeComponent(message);
                      final url = Uri.parse('https://api.whatsapp.com/send?text=$text');
                      launchUrl(url, mode: LaunchMode.externalApplication);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 2. If Grand Final is Pending / Tournament in progress
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TOURNAMENT TROPHY',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.gold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  grandFinalMatch?.isLive == true ? '🔴 FINAL IS LIVE' : 'FINALS PENDING',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: grandFinalMatch?.isLive == true ? AppColors.liveRed : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            grandFinalMatch != null && grandFinalMatch.teamAId != null && grandFinalMatch.teamBId != null
                ? 'The Grand Final matchup is set! The tournament champion will be crowned upon completion of the Grand Final.'
                : 'Tournament championship is underway. Top teams advancing from the group stage and semi-finals will compete in the Grand Final for the ultimate trophy.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          if (grandFinalMatch != null) ...[
            const SizedBox(height: 14),
            InkWell(
              onTap: () {
                if (grandFinalMatch.isLive) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LiveMatchScreen(matchId: grandFinalMatch.id),
                    ),
                  );
                } else if (grandFinalMatch.isCompleted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatchScorecardScreen(matchId: grandFinalMatch.id),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sports_cricket_rounded, size: 16, color: AppColors.accentCyan),
                        const SizedBox(width: 8),
                        Text(
                          'Grand Final Match #${grandFinalMatch.matchNumber}',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Text(
                      grandFinalMatch.isLive ? 'Watch Live →' : 'View Fixture →',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentCyan),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Quick banner at top if champion is already crowned
  Widget _buildChampionQuickBanner(
    List<StandingWithTeam> list,
    List<TeamModel> allTeams,
    String championId,
  ) {
    String name = 'Champion Team';
    for (final t in allTeams) {
      if (t.id == championId) {
        name = t.name;
        break;
      }
    }
    if (name == 'Champion Team') {
      final champ = list.firstWhere(
        (item) => item.team?.id == championId || item.standing.teamId == championId,
        orElse: () => list.first,
      );
      name = champ.team?.name ?? champ.standing.teamName ?? 'Champion Team';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  'TOURNAMENT CHAMPION CROWNED',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.gold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
        ],
      ),
    );
  }

  Widget _buildGroupFilterPill(String tabKey, String label) {
    final isSelected = _selectedGroupTab == tabKey;
    return InkWell(
      onTap: () => setState(() => _selectedGroupTab = tabKey),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.white10,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
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

  Widget _buildGroupSection({
    required String groupKey,
    required List<StandingWithTeam> items,
    required int advanceCount,
    required String qualificationLabel,
    required String subheaderTag,
  }) {
    final isGroupA = groupKey.toUpperCase() == 'A';
    final isGroupB = groupKey.toUpperCase() == 'B';

    final gradientColors = isGroupA
        ? const [Color(0xFF00E5FF), Color(0xFF3B82F6)]
        : isGroupB
            ? const [Color(0xFFA855F7), Color(0xFF6366F1)]
            : const [Color(0xFFF59E0B), Color(0xFFEF4444)];

    final badgeShadowColor = (isGroupA
            ? const Color(0xFF00E5FF)
            : (isGroupB ? const Color(0xFFA855F7) : const Color(0xFFF59E0B)))
        .withValues(alpha: 0.35);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGroupA
              ? const Color(0xFF00E5FF).withValues(alpha: 0.25)
              : isGroupB
                  ? const Color(0xFFA855F7).withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
        ),
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
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.35),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradientColors),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: badgeShadowColor,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'GROUP $groupKey STANDINGS',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.completedGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.completedGreen.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    subheaderTag,
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
                child: Text('No teams in Group $groupKey', style: GoogleFonts.outfit(color: AppColors.textMuted)),
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
        border: Border(
          left: BorderSide(
            color: isQualified ? AppColors.completedGreen : Colors.transparent,
            width: 3.5,
          ),
          bottom: isLast ? BorderSide.none : BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
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

  Widget _fallbackLogoLarge(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0] : 'T',
        style: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: AppColors.gold,
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

// =============================================================================
// KNOCKOUT MATCH CARD (CONSUMER WIDGET FOR REAL MATCHES IN FIRESTORE)
// =============================================================================
class _KnockoutMatchCard extends ConsumerWidget {
  final MatchModel match;
  final List<TeamModel> allTeams;
  final List<StandingWithTeam> standingsList;
  final TournamentModel? tournament;

  const _KnockoutMatchCard({
    required this.match,
    required this.allTeams,
    required this.standingsList,
    required this.tournament,
  });

  TeamModel _resolveTeam(String? teamId, {required bool isTeamA}) {
    if (teamId != null && teamId.isNotEmpty) {
      for (final t in allTeams) {
        if (t.id == teamId) return t;
      }
      for (final item in standingsList) {
        if (item.team?.id == teamId || item.standing.teamId == teamId) {
          if (item.team != null) return item.team!;
          return TeamModel(
            id: teamId,
            name: item.standing.teamName ?? 'Team $teamId',
            shortName: item.shortName,
            logoUrl: item.logoUrl,
          );
        }
      }
    }

    final placeholder = match.getPlaceholderTeamName(
      isTeamA: isTeamA,
      groupPlayoffFormat: tournament?.groupPlayoffFormat,
    );
    return TeamModel(
      id: teamId ?? '',
      name: placeholder,
      shortName: placeholder.length > 8 ? placeholder.substring(0, 7) : placeholder,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamA = _resolveTeam(match.teamAId, isTeamA: true);
    final teamB = _resolveTeam(match.teamBId, isTeamA: false);

    final inningsAsync = ref.watch(matchInningsProvider(match.id));
    final inningsList = inningsAsync.value ?? [];

    final inn1 = inningsList.isNotEmpty
        ? inningsList.firstWhere((i) => i.inningsNumber == 1, orElse: () => inningsList.first)
        : null;
    final inn2 = inningsList.length > 1
        ? inningsList.firstWhere((i) => i.inningsNumber == 2, orElse: () => inningsList.last)
        : null;

    final isWinnerA = match.isCompleted &&
        match.winningTeamId != null &&
        match.winningTeamId!.isNotEmpty &&
        match.winningTeamId == match.teamAId;
    final isWinnerB = match.isCompleted &&
        match.winningTeamId != null &&
        match.winningTeamId!.isNotEmpty &&
        match.winningTeamId == match.teamBId;

    final isFinal = match.isFinal;
    final isSemi = match.isSemi;

    Color borderColor = Colors.white.withValues(alpha: 0.08);
    if (isFinal) {
      borderColor = AppColors.gold.withValues(alpha: 0.5);
    } else if (isSemi) {
      borderColor = AppColors.accentCyan.withValues(alpha: 0.4);
    } else if (match.isLive) {
      borderColor = AppColors.liveRed.withValues(alpha: 0.5);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isFinal ? 1.8 : 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (match.isCompleted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MatchScorecardScreen(matchId: match.id)),
              );
            } else if (match.isLive) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LiveMatchScreen(matchId: match.id)),
              );
            } else if (match.isUpcoming &&
                match.teamAId != null &&
                match.teamBId != null &&
                match.teamAId!.isNotEmpty &&
                match.teamBId!.isNotEmpty) {
              final isMatchScorable = ref.read(isTournamentScorableProvider(match.tournamentId));
              if (isMatchScorable) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MatchLineupScreen(match: match)),
                );
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Stage Badge, Match Number, Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isFinal
                                ? AppColors.gold.withValues(alpha: 0.18)
                                : (isSemi
                                    ? AppColors.accentCyan.withValues(alpha: 0.18)
                                    : AppColors.surfaceLight),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isFinal
                                  ? AppColors.gold
                                  : (isSemi ? AppColors.accentCyan : Colors.white24),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            match.stageDisplayName.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: isFinal
                                  ? AppColors.gold
                                  : (isSemi ? AppColors.accentCyan : AppColors.textPrimary),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Match #${match.matchNumber}',
                          style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    _buildStatusPill(match.status),
                  ],
                ),
                const SizedBox(height: 12),

                // Team A Row
                _buildTeamRow(
                  team: teamA,
                  score: _getTeamScore(teamA.id, inn1, inn2),
                  isWinner: isWinnerA,
                  isKnockoutWin: isWinnerA,
                  advancementLabel: isFinal ? 'CHAMPION 🏆' : 'ADVANCED TO FINAL ✓',
                ),
                const SizedBox(height: 8),

                // Team B Row
                _buildTeamRow(
                  team: teamB,
                  score: _getTeamScore(teamB.id, inn1, inn2),
                  isWinner: isWinnerB,
                  isKnockoutWin: isWinnerB,
                  advancementLabel: isFinal ? 'CHAMPION 🏆' : 'ADVANCED TO FINAL ✓',
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Colors.white10),
                const SizedBox(height: 8),

                // Footer: Result or Schedule + Navigation Hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (match.isCompleted)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.emoji_events_rounded, size: 14, color: AppColors.gold),
                            ),
                          Expanded(
                            child: Text(
                              match.resultText ??
                                  (match.isLive
                                      ? '🔴 Match in progress • ${match.maxOvers} Overs'
                                      : '📅 ${match.date} ${match.time.isNotEmpty ? "at ${match.time}" : ""} • ${match.venue}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: match.isCompleted ? FontWeight.bold : FontWeight.w600,
                                color: match.isCompleted
                                    ? AppColors.gold
                                    : (match.isLive ? AppColors.accent : AppColors.textSecondary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          match.isCompleted
                              ? 'Scorecard'
                              : (match.isLive ? 'Live Hub' : 'Details'),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentCyan,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right, size: 14, color: AppColors.accentCyan),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _getTeamScore(String? teamId, InningsModel? inn1, InningsModel? inn2) {
    if (teamId == null || teamId.isEmpty) return null;
    final inn = inn1?.battingTeamId == teamId
        ? inn1
        : (inn2?.battingTeamId == teamId ? inn2 : null);
    if (inn == null) return null;
    return '${inn.runs}/${inn.wickets} (${inn.oversString} ov)';
  }

  Widget _buildTeamRow({
    required TeamModel team,
    required String? score,
    required bool isWinner,
    required bool isKnockoutWin,
    required String advancementLabel,
  }) {
    return Row(
      children: [
        // Logo
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            shape: BoxShape.circle,
            border: Border.all(
              color: isWinner ? AppColors.gold : Colors.white12,
              width: isWinner ? 1.5 : 1.0,
            ),
          ),
          child: ClipOval(
            child: team.formattedLogoUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: team.formattedLogoUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _fallbackLogo(team.shortName),
                  )
                : _fallbackLogo(team.shortName),
          ),
        ),
        const SizedBox(width: 10),

        // Team Name & Advancement Tag
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      team.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: isWinner ? FontWeight.w900 : FontWeight.w700,
                        color: isWinner ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isKnockoutWin) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.gold, width: 0.8),
                      ),
                      child: Text(
                        advancementLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Score
        if (score != null) ...[
          Text(
            score,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: isWinner ? FontWeight.w900 : FontWeight.w700,
              color: isWinner ? AppColors.accent : AppColors.textPrimary,
            ),
          ),
        ] else ...[
          Text(
            '-',
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg;
    Color fg;
    final s = status.toUpperCase();
    if (s == 'LIVE') {
      bg = AppColors.liveRed.withValues(alpha: 0.18);
      fg = AppColors.liveRed;
    } else if (s == 'COMPLETED') {
      bg = AppColors.completedGreen.withValues(alpha: 0.18);
      fg = AppColors.completedGreen;
    } else {
      bg = AppColors.surfaceLight;
      fg = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        s,
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
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
}

// =============================================================================
// PROJECTED KNOCKOUT CARD (WHEN MATCH DOCUMENTS NOT YET IN FIRESTORE)
// =============================================================================
class _ProjectedKnockoutCard extends StatelessWidget {
  final String stageTitle;
  final String matchSubheader;
  final String teamAName;
  final String teamAShort;
  final String teamALogo;
  final String teamBName;
  final String teamBShort;
  final String teamBLogo;
  final String note;
  final bool isFinal;

  const _ProjectedKnockoutCard({
    required this.stageTitle,
    required this.matchSubheader,
    required this.teamAName,
    required this.teamAShort,
    required this.teamALogo,
    required this.teamBName,
    required this.teamBShort,
    required this.teamBLogo,
    required this.note,
    this.isFinal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFinal ? AppColors.gold.withValues(alpha: 0.5) : AppColors.accentCyan.withValues(alpha: 0.3),
          width: isFinal ? 1.6 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isFinal ? AppColors.gold.withValues(alpha: 0.15) : AppColors.accentCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  stageTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isFinal ? AppColors.gold : AppColors.accentCyan,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PROJECTED FIXTURE',
                  style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            matchSubheader,
            style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // Team A
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(color: AppColors.surfaceLight, shape: BoxShape.circle),
                child: ClipOval(
                  child: teamALogo.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: teamALogo,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _fallbackLogo(teamAShort),
                        )
                      : _fallbackLogo(teamAShort),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  teamAName,
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              Text('TBD', style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),

          // Team B
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(color: AppColors.surfaceLight, shape: BoxShape.circle),
                child: ClipOval(
                  child: teamBLogo.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: teamBLogo,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _fallbackLogo(teamBShort),
                        )
                      : _fallbackLogo(teamBShort),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  teamBName,
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              Text('TBD', style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  note,
                  style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ],
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
}
