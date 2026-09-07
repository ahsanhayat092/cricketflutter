import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/pitchpe_logo.dart';
import '../../match_management/providers/tournament_providers.dart';
import '../../scoring/models/match_model.dart';
import '../../scoring/models/team_model.dart';
import 'live_match_screen.dart';
import 'match_scorecard_screen.dart';
import '../../sharing/presentation/share_story_modal.dart';
import '../../sharing/presentation/widgets/match_story_card.dart';

class LiveMatchHubScreen extends ConsumerStatefulWidget {
  final VoidCallback? onExploreFixtures;

  const LiveMatchHubScreen({super.key, this.onExploreFixtures});

  @override
  ConsumerState<LiveMatchHubScreen> createState() => _LiveMatchHubScreenState();
}

class _LiveMatchHubScreenState extends ConsumerState<LiveMatchHubScreen> {
  String? _selectedLiveMatchId;

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(matchesProvider);
    final teamsAsync = ref.watch(teamsProvider);

    return matchesAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Live Match')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.wicket),
                const SizedBox(height: 12),
                Text('Could not load matches', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('$err', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
      data: (allMatches) {
        final teams = teamsAsync.value ?? [];
        final teamMap = {for (var t in teams) t.id: t};

        final liveMatches = allMatches.where((m) => m.isLive).toList();

        if (liveMatches.isNotEmpty) {
          // If selected match is no longer in liveMatches, reset to the first live match
          final activeMatchId = (_selectedLiveMatchId != null &&
                  liveMatches.any((m) => m.id == _selectedLiveMatchId))
              ? _selectedLiveMatchId!
              : liveMatches.first.id;

          if (liveMatches.length == 1) {
            return LiveMatchScreen(matchId: activeMatchId);
          }

          // Multiple live matches in progress: show switcher at top
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: Text(
                'LIVE MATCHES (${liveMatches.length})',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: liveMatches.length,
                    itemBuilder: (ctx, i) {
                      final m = liveMatches[i];
                      final tA = teamMap[m.teamAId]?.shortName ?? 'TMA';
                      final tB = teamMap[m.teamBId]?.shortName ?? 'TMB';
                      final isSelected = m.id == activeMatchId;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('$tA vs $tB • M#${m.matchNumber}'),
                          selected: isSelected,
                          selectedColor: AppColors.accent,
                          backgroundColor: AppColors.surfaceLight,
                          labelStyle: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isSelected ? Colors.black : AppColors.textPrimary,
                          ),
                          onSelected: (_) => setState(() => _selectedLiveMatchId = m.id),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            body: LiveMatchScreen(matchId: activeMatchId),
          );
        }

        // NO live matches currently in progress
        final upcomingMatches = allMatches.where((m) => m.isUpcoming).toList();
        final latestCompleted = allMatches.where((m) => m.isCompleted).toList().lastOrNull;
        final nextUpcoming = upcomingMatches.isNotEmpty ? upcomingMatches.first : null;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              'LIVE MATCH',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1.0),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.accentCyan),
                tooltip: 'Refresh',
                onPressed: () {
                  ref.invalidate(matchesProvider);
                  ref.invalidate(teamsProvider);
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Sleek Empty State Hero Box
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF131C2E), Color(0xFF0D1524)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Center(
                        child: PitchPeLogo.appIcon(height: 64),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'No Match Currently Live',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Live ball-by-ball scoring, real-time commentary, and wagon wheels will appear here automatically when a match begins.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      if (widget.onExploreFixtures != null) ...[
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.calendar_month_rounded, size: 18),
                          label: Text(
                            'VIEW FIXTURES & SCHEDULE',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                          onPressed: widget.onExploreFixtures,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // 2. Next Upcoming Match Card (if exists)
                if (nextUpcoming != null) ...[
                  _buildSectionHeader('NEXT UPCOMING MATCH'),
                  const SizedBox(height: 12),
                  _buildUpcomingCard(context, nextUpcoming, teamMap),
                ] else if (latestCompleted != null) ...[
                  _buildSectionHeader('LATEST MATCH RESULT'),
                  const SizedBox(height: 12),
                  _buildCompletedCard(context, latestCompleted, teamMap),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingCard(BuildContext context, MatchModel match, Map<String, TeamModel> teamMap) {
    final nameA = match.getPlaceholderTeamName(isTeamA: true);
    final nameB = match.getPlaceholderTeamName(isTeamA: false);
    final teamA = (match.teamAId != null ? teamMap[match.teamAId!] : null) ??
        TeamModel(id: match.teamAId ?? '', name: nameA, shortName: nameA.startsWith('TBD') ? 'TBD' : 'TMA');
    final teamB = (match.teamBId != null ? teamMap[match.teamBId!] : null) ??
        TeamModel(id: match.teamBId ?? '', name: nameB, shortName: nameB.startsWith('TBD') ? 'TBD' : 'TMB');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  match.stageDisplayName.toUpperCase(),
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentCyan),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'UPCOMING',
                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.accentCyan),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _buildTeamLogo(teamA),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        teamA.name,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'VS',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.textMuted),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        teamB.name,
                        textAlign: TextAlign.end,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildTeamLogo(teamB),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    '${match.date} • ${match.time}',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    match.venue,
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(BuildContext context, MatchModel match, Map<String, TeamModel> teamMap) {
    final teamA = (match.teamAId != null ? teamMap[match.teamAId!] : null) ??
        TeamModel(id: match.teamAId ?? '', name: 'Team A', shortName: 'TMA');
    final teamB = (match.teamBId != null ? teamMap[match.teamBId!] : null) ??
        TeamModel(id: match.teamBId ?? '', name: 'Team B', shortName: 'TMB');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                match.stageDisplayName.toUpperCase(),
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.completedGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'FINAL RESULT',
                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.completedGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${teamA.shortName} vs ${teamB.shortName}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.share_rounded, size: 18, color: AppColors.accent),
                    tooltip: 'Share Story',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ShareStoryModal.show(
                        context,
                        match: match,
                        teamA: teamA,
                        teamB: teamB,
                        inningsList: ref.read(matchInningsProvider(match.id)).value ?? [],
                        allPlayers: ref.read(playersProvider).value ?? [],
                        initialTemplate: StoryCardTemplate.matchResult,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceLight,
                      foregroundColor: AppColors.accentCyan,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MatchScorecardScreen(matchId: match.id)),
                      );
                    },
                    child: Text('SCORECARD', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
          if (match.resultText != null) ...[
            const SizedBox(height: 8),
            Text(
              match.resultText!,
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamLogo(TeamModel team) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceLight,
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: ClipOval(
        child: team.logoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: team.logoUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _fallbackText(team.shortName),
              )
            : _fallbackText(team.shortName),
      ),
    );
  }

  Widget _fallbackText(String shortName) {
    return Center(
      child: Text(
        shortName.isNotEmpty ? shortName[0] : 'T',
        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
      ),
    );
  }
}
