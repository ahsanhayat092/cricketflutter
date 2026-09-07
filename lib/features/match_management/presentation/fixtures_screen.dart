import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/pitchpe_logo.dart';
import '../../auth/providers/auth_provider.dart';
import '../../scoring/models/match_model.dart';
import '../../scoring/models/team_model.dart';
import '../../scoring/models/innings_model.dart';
import '../../scoring/models/tournament_model.dart';
import '../../live_viewer/presentation/live_match_screen.dart';
import '../../live_viewer/presentation/match_scorecard_screen.dart';
import '../providers/tournament_providers.dart';
import 'match_lineup_screen.dart';
import 'tournament_discovery_dialog.dart';
import 'tournament_permissions_screen.dart';
import '../../auth/presentation/scorer_pin_auth_dialog.dart';
import '../../scoring/presentation/widgets/scoring_sync_badge.dart';

class FixturesScreen extends ConsumerStatefulWidget {
  const FixturesScreen({super.key});

  @override
  ConsumerState<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends ConsumerState<FixturesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _shareTournamentWhatsApp() async {
    final tournament = ref.read(activeTournamentProvider).value;
    if (tournament == null) return;
    final text = Uri.encodeComponent(tournament.shareWhatsAppText);
    final url = Uri.parse('https://api.whatsapp.com/send?text=$text');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(matchesProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final user = ref.watch(currentUserProvider);
    final activeTournamentAsync = ref.watch(activeTournamentProvider);
    final activeId = ref.watch(activeTournamentIdProvider);
    final canScore = ref.watch(isTournamentScorableProvider(activeId));

    final allMatches = matchesAsync.value ?? [];
    final allTeams = teamsAsync.value ?? [];

    final teamMap = {for (var t in allTeams) t.id: t};

    final liveMatches = allMatches.where((m) => m.isLive).toList();
    final upcomingMatches = allMatches.where((m) => m.isUpcoming).toList();
    final completedMatches = allMatches.where((m) => m.isCompleted).toList();

    final tournament = activeTournamentAsync.value;
    final tournamentTitle = tournament?.shortName ?? 'WPL 2026';
    final canManage = ref.watch(isTournamentAdminProvider(activeId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 8,
        leadingWidth: 44,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Center(child: PitchPeLogo.icon(height: 28)),
        ),
        title: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => const TournamentDiscoveryDialog(),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppColors.accent, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    tournamentTitle,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down_rounded, color: AppColors.accent, size: 20),
              ],
            ),
          ),
        ),
        actions: [
          // Offline / Online Sync Status Badge
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: ScoringSyncBadge(compact: true),
          ),
          // Ground Scorer PIN Access
          IconButton(
            icon: Icon(
              canScore ? Icons.verified_user_rounded : Icons.pin_rounded,
              color: canScore ? AppColors.accent : AppColors.textMuted,
            ),
            tooltip: 'Ground Scorer PIN',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => ScorerPinAuthDialog(
                  initialTournamentId: tournament?.id,
                  initialTournamentName: tournament?.name,
                ),
              );
            },
          ),
          // People & Permissions (RBAC) - Strictly for Tournament Admins / Owners / Platform Admin
          if (canManage)
            IconButton(
              icon: const Icon(Icons.shield_outlined, color: AppColors.accentCyan),
              tooltip: 'People & Permissions',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TournamentPermissionsScreen()),
                );
              },
            ),
          // WhatsApp Share Tournament
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.accent),
            tooltip: 'Share on WhatsApp',
            onPressed: _shareTournamentWhatsApp,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            Tab(text: 'LIVE (${liveMatches.length})'),
            Tab(text: 'UPCOMING (${upcomingMatches.length})'),
            Tab(text: 'COMPLETED (${completedMatches.length})'),
          ],
        ),
      ),
      body: matchesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (err, _) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.wicket),
                const SizedBox(height: 12),
                Text(
                  'Failed to load matches from Firestore',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  err.toString().split('\n').first,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
                  icon: const Icon(Icons.refresh),
                  label: const Text('RETRY'),
                  onPressed: () => ref.invalidate(matchesProvider),
                ),
              ],
            ),
          ),
        ),
        data: (_) => TabBarView(
          controller: _tabController,
          children: [
            _buildMatchList(liveMatches, teamMap, user.canScore, 'No live matches in progress'),
            _buildMatchList(upcomingMatches, teamMap, user.canScore, 'No upcoming matches scheduled'),
            _buildMatchList(completedMatches, teamMap, user.canScore, 'No completed matches yet'),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchList(
    List<MatchModel> matches,
    Map<String, TeamModel> teamMap,
    bool canScore,
    String emptyMessage,
  ) {
    if (matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_cricket_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final match = matches[index];
        final tournament = ref.watch(activeTournamentProvider).value;

        final nameA = (match.teamAId != null && match.teamAId!.isNotEmpty)
            ? (teamMap[match.teamAId]?.name ?? 'Team A')
            : match.getPlaceholderTeamName(isTeamA: true, groupPlayoffFormat: tournament?.groupPlayoffFormat);
        final shortA = (match.teamAId != null && match.teamAId!.isNotEmpty)
            ? (teamMap[match.teamAId]?.shortName ?? 'TMA')
            : 'TBD';
        final teamA = teamMap[match.teamAId] ?? TeamModel(id: match.teamAId ?? '', name: nameA, shortName: shortA);

        final nameB = (match.teamBId != null && match.teamBId!.isNotEmpty)
            ? (teamMap[match.teamBId]?.name ?? 'Team B')
            : match.getPlaceholderTeamName(isTeamA: false, groupPlayoffFormat: tournament?.groupPlayoffFormat);
        final shortB = (match.teamBId != null && match.teamBId!.isNotEmpty)
            ? (teamMap[match.teamBId]?.shortName ?? 'TMB')
            : 'TBD';
        final teamB = teamMap[match.teamBId] ?? TeamModel(id: match.teamBId ?? '', name: nameB, shortName: shortB);

        return _MatchCard(
          match: match,
          teamA: teamA,
          teamB: teamB,
          canScore: canScore,
        );
      },
    );
  }
}

class _MatchCard extends ConsumerWidget {
  final MatchModel match;
  final TeamModel teamA;
  final TeamModel teamB;
  final bool canScore;

  const _MatchCard({
    required this.match,
    required this.teamA,
    required this.teamB,
    required this.canScore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(activeTournamentIdProvider);
    final matchTourId = match.tournamentId.isNotEmpty ? match.tournamentId : activeId;
    final isMatchScorable = ref.watch(isTournamentScorableProvider(matchTourId));

    final inningsAsync = ref.watch(matchInningsProvider(match.id));
    final inningsList = inningsAsync.value ?? [];

    final inn1 = inningsList.isNotEmpty ? inningsList.firstWhere((i) => i.inningsNumber == 1, orElse: () => inningsList.first) : null;
    final inn2 = inningsList.length > 1 ? inningsList.firstWhere((i) => i.inningsNumber == 2, orElse: () => inningsList.last) : null;

    final resolvedTeamA = (match.teamAId != null && match.teamAId!.isNotEmpty)
        ? ((teamA.name.isNotEmpty && !teamA.name.startsWith('Team '))
            ? teamA
            : (ref.watch(singleTeamStreamProvider(match.teamAId!)).value ?? teamA))
        : teamA;
    final resolvedTeamB = (match.teamBId != null && match.teamBId!.isNotEmpty)
        ? ((teamB.name.isNotEmpty && !teamB.name.startsWith('Team '))
            ? teamB
            : (ref.watch(singleTeamStreamProvider(match.teamBId!)).value ?? teamB))
        : teamB;

    final isWinnerA = match.winningTeamId != null && match.winningTeamId!.isNotEmpty && match.winningTeamId == resolvedTeamA.id;
    final isWinnerB = match.winningTeamId != null && match.winningTeamId!.isNotEmpty && match.winningTeamId == resolvedTeamB.id;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: match.isLive
              ? AppColors.liveRed.withValues(alpha: 0.3)
              : (match.isCompleted ? AppColors.accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.08)),
          width: match.isLive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (match.isUpcoming) {
              if (match.teamAId == null || match.teamBId == null || match.teamAId!.isEmpty || match.teamBId!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Teams have not yet qualified for this knockout match.'),
                    backgroundColor: AppColors.cardBackground,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              if (isMatchScorable) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MatchLineupScreen(match: match)),
                );
              } else {
                final allTournamentsAsync = ref.read(allTournamentsProvider);
                final tournament = allTournamentsAsync.value?.cast<TournamentModel?>().firstWhere(
                      (t) => t?.id == matchTourId,
                      orElse: () => ref.read(activeTournamentProvider).value,
                    ) ?? ref.read(activeTournamentProvider).value;
                final tourName = tournament?.name ?? 'this tournament';
                final result = await showDialog<bool>(
                  context: context,
                  builder: (_) => ScorerPinAuthDialog(
                    initialTournamentId: matchTourId,
                    initialTournamentName: tournament?.name,
                    customPrompt: 'Enter the 4-digit Scorer PIN for $tourName to unlock this live scoring console.',
                  ),
                );
                if (result == true && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MatchLineupScreen(match: match)),
                  );
                }
              }
            } else if (match.isCompleted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MatchScorecardScreen(matchId: match.id)),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LiveMatchScreen(matchId: match.id)),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Match Number, Stage, Venue, Status, Share
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${match.stageDisplayName.toUpperCase()} • MATCH #${match.matchNumber} • ${match.day}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            final tournament = ref.read(activeTournamentProvider).value;
                            final tournamentName = tournament?.name ?? 'PitchPe';
                            final shareUrl = tournament?.shareUrl ?? 'https://wasacricket.vercel.app';
                            final message = '🏏 *$tournamentName - Match #${match.matchNumber}*\n'
                                '⚔️ *${resolvedTeamA.name}* vs *${resolvedTeamB.name}*\n'
                                '${match.resultText ?? (match.isLive ? "🔴 Live Match in Progress" : "📅 Scheduled on ${match.date} ${match.time}")}\n\n'
                                '📊 View Live Scorecard: $shareUrl';
                            final text = Uri.encodeComponent(message);
                            final url = Uri.parse('https://api.whatsapp.com/send?text=$text');
                            launchUrl(url, mode: LaunchMode.externalApplication);
                          },
                          icon: const Icon(Icons.share_rounded, size: 16, color: AppColors.accentCyan),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(match.status),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Team A Row
                _buildTeamRow(
                  team: resolvedTeamA,
                  inn: inn1?.battingTeamId == resolvedTeamA.id ? inn1 : (inn2?.battingTeamId == resolvedTeamA.id ? inn2 : null),
                  isWinner: isWinnerA,
                  match: match,
                ),
                const SizedBox(height: 8),

                // 3. Team B Row
                _buildTeamRow(
                  team: resolvedTeamB,
                  inn: inn1?.battingTeamId == resolvedTeamB.id ? inn1 : (inn2?.battingTeamId == resolvedTeamB.id ? inn2 : null),
                  isWinner: isWinnerB,
                  match: match,
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Colors.white10),
                const SizedBox(height: 8),

                // 4. Completed Match Summary Banner / Action Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (match.isCompleted)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.emoji_events_rounded, size: 16, color: AppColors.gold),
                            ),
                          Expanded(
                            child: Text(
                              match.resultText ??
                                  (match.isLive
                                      ? '🔴 Live in Progress • ${match.maxOvers} Overs'
                                      : 'Starts ${match.date} ${match.time.isNotEmpty ? "at ${match.time}" : ""}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
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
                          match.isUpcoming && isMatchScorable
                              ? 'Setup Lineup'
                              : (match.isCompleted ? 'View Scorecard' : 'Live Score'),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentCyan,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 16, color: AppColors.accentCyan),
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

  Widget _buildTeamRow({
    required TeamModel team,
    required InningsModel? inn,
    required bool isWinner,
    required MatchModel match,
  }) {
    return Row(
      children: [
        // Logo
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.surfaceLight,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: team.logoUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: team.logoUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _fallbackLogo(team.shortName),
                  )
                : _fallbackLogo(team.shortName),
          ),
        ),
        const SizedBox(width: 10),

        // Team Name + Winner Trophy
        Expanded(
          child: Row(
            children: [
              Text(
                team.name,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: isWinner ? FontWeight.w900 : FontWeight.w700,
                  color: isWinner ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              if (isWinner) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check_circle_rounded, size: 15, color: AppColors.accent),
              ],
            ],
          ),
        ),

        // Score & Overs
        if (inn != null)
          Row(
            children: [
              Text(
                '${inn.runs}/${inn.wickets}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isWinner ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${inn.oversString} ov)',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          )
        else
          Text(
            match.isUpcoming ? 'Yet to play' : 'Yet to bat',
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
          ),
      ],
    );
  }

  Widget _fallbackLogo(String text) {
    return Center(
      child: Text(
        text.isNotEmpty ? text[0] : 'T',
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isLive = status.toUpperCase() == 'LIVE';
    final isCompleted = status.toUpperCase() == 'COMPLETED';

    Color bgColor = AppColors.surfaceLight;
    Color textColor = AppColors.textMuted;

    if (isLive) {
      bgColor = AppColors.liveRed.withValues(alpha: 0.2);
      textColor = AppColors.liveRed;
    } else if (isCompleted) {
      bgColor = AppColors.accent.withValues(alpha: 0.15);
      textColor = AppColors.accent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
