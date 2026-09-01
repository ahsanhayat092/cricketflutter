import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../match_management/providers/tournament_providers.dart';
import '../../match_management/presentation/match_lineup_screen.dart';
import '../../scoring/models/match_model.dart';
import '../../scoring/models/team_model.dart';
import '../../scoring/models/player_model.dart';
import '../../scoring/models/innings_model.dart';
import '../../scoring/models/tournament_model.dart';
import '../../scoring/presentation/scorer_console_screen.dart';
import '../../auth/presentation/scorer_pin_auth_dialog.dart';
import 'widgets/live_scoreboard_banner.dart';
import 'widgets/delivery_wheel.dart';
import 'widgets/live_scorecard_tabs.dart';
import 'widgets/celebration_overlay.dart';
import 'match_scorecard_screen.dart';
import '../../sharing/presentation/share_story_modal.dart';
import '../../sharing/presentation/widgets/match_story_card.dart';

class LiveMatchScreen extends ConsumerStatefulWidget {
  final String matchId;

  const LiveMatchScreen({super.key, required this.matchId});

  @override
  ConsumerState<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends ConsumerState<LiveMatchScreen> {
  String? _activeCelebrationType;
  String? _activeCelebrationText;
  int _lastEventTimestamp = 0;

  @override
  void initState() {
    super.initState();
    // Set timestamp to now so stale events from previous sessions do not animate on entry
    _lastEventTimestamp = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final matchAsync = ref.watch(singleMatchProvider(widget.matchId));
    final inningsAsync = ref.watch(matchInningsProvider(widget.matchId));
    final teamsAsync = ref.watch(teamsProvider);
    final playersAsync = ref.watch(playersProvider);

    return matchAsync.when(
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
                Text('Could not load live match', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('$err', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
      data: (match) {
        if (match == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Match Not Found')),
            body: Center(
              child: Text(
                'Match not found in Firestore.',
                style: GoogleFonts.outfit(color: AppColors.textMuted),
              ),
            ),
          );
        }

        final inningsList = inningsAsync.value ?? [];
        final hasInningsStarted = inningsList.isNotEmpty && (inningsList.first.balls > 0 || inningsList.first.runs > 0 || match.isLive || match.isCompleted);

        final currentInnings = inningsList.isNotEmpty
            ? inningsList.last
            : InningsModel(
                id: 'inn_${match.id}_1',
                matchId: match.id,
                inningsNumber: 1,
                battingTeamId: match.teamAId,
                bowlingTeamId: match.teamBId,
              );

        final matchTourId = match.tournamentId.isNotEmpty ? match.tournamentId : ref.watch(activeTournamentIdProvider);
        final matchTeamsAsync = ref.watch(tournamentTeamsProvider(matchTourId));
        final teams = matchTeamsAsync.value ?? teamsAsync.value ?? [];
        final players = playersAsync.value ?? [];

        final teamMap = {for (var t in teams) t.id: t};
        final playerMap = {for (var p in players) p.id: p};

        final teamA = teamMap[match.teamAId] ??
            ref.watch(singleTeamStreamProvider(match.teamAId)).value ??
            (match.teamAId.isNotEmpty
                ? TeamModel(id: match.teamAId, name: 'Team ${match.teamAId.substring(0, match.teamAId.length.clamp(1, 4))}', shortName: match.teamAId.substring(0, match.teamAId.length.clamp(1, 3)).toUpperCase())
                : const TeamModel(id: '', name: 'TBD', shortName: 'TBD'));
        final teamB = teamMap[match.teamBId] ??
            ref.watch(singleTeamStreamProvider(match.teamBId)).value ??
            (match.teamBId.isNotEmpty
                ? TeamModel(id: match.teamBId, name: 'Team ${match.teamBId.substring(0, match.teamBId.length.clamp(1, 4))}', shortName: match.teamBId.substring(0, match.teamBId.length.clamp(1, 3)).toUpperCase())
                : const TeamModel(id: '', name: 'TBD', shortName: 'TBD'));

        final battingTeam = teamMap[currentInnings.battingTeamId] ??
            ref.watch(singleTeamStreamProvider(currentInnings.battingTeamId)).value ??
            (currentInnings.battingTeamId == teamB.id ? teamB : teamA);
        final bowlingTeam = teamMap[currentInnings.bowlingTeamId] ??
            ref.watch(singleTeamStreamProvider(currentInnings.bowlingTeamId)).value ??
            (currentInnings.bowlingTeamId == teamA.id ? teamA : teamB);

        final firstInningsRuns = inningsList.length > 1 ? inningsList.first.runs : null;

        // Check for celebration events (FOUR, SIX, WICKET, MAIDEN) only if fresh (< 5 seconds ago)
        final now = DateTime.now().millisecondsSinceEpoch;
        if (match.recentEvent != null &&
            match.recentEvent!.timestamp > _lastEventTimestamp &&
            (now - match.recentEvent!.timestamp) < 5000) {
          _lastEventTimestamp = match.recentEvent!.timestamp;
          _activeCelebrationType = match.recentEvent!.type;
          _activeCelebrationText = match.recentEvent!.text;
        } else if (match.recentEvent != null && match.recentEvent!.timestamp > _lastEventTimestamp) {
          _lastEventTimestamp = match.recentEvent!.timestamp;
        }

        final titleText = hasInningsStarted
            ? '${battingTeam.shortName} vs ${bowlingTeam.shortName}'
            : '${teamA.shortName} vs ${teamB.shortName}';

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (match.isLive) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.liveRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      '${match.stage} MATCH ${match.matchNumber}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: match.isLive ? AppColors.liveRed : AppColors.accentCyan,
                      ),
                    ),
                  ],
                ),
                Text(
                  titleText,
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            actions: [
              // Full ESPN Cricinfo Scorecard Button
              if (hasInningsStarted) ...[
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: AppColors.accent),
                  tooltip: 'Share Instagram Story',
                  onPressed: () {
                    ShareStoryModal.show(
                      context,
                      match: match,
                      teamA: teamA,
                      teamB: teamB,
                      inningsList: inningsList,
                      allPlayers: players,
                      initialTemplate: match.isCompleted ? StoryCardTemplate.matchResult : StoryCardTemplate.matchOverview,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.table_chart_rounded, color: AppColors.accentCyan),
                  tooltip: 'Full ESPN Scorecard',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MatchScorecardScreen(matchId: widget.matchId),
                      ),
                    );
                  },
                ),
              ],

              // Scorer Access Button (PIN-aware or authenticated official)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Builder(
                  builder: (ctx) {
                    final activeId = ref.watch(activeTournamentIdProvider);
                    final matchTourId = match.tournamentId.isNotEmpty ? match.tournamentId : activeId;
                    final isMatchScorable = ref.watch(isTournamentScorableProvider(matchTourId));

                    return IconButton(
                      icon: Icon(
                        Icons.edit_note_rounded,
                        color: isMatchScorable ? AppColors.accent : AppColors.textMuted,
                      ),
                      tooltip: match.isUpcoming ? 'Setup Lineups & Start Match' : 'Open Scorer Console',
                      onPressed: () async {
                        if (isMatchScorable) {
                          if (match.isUpcoming) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MatchLineupScreen(match: match),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScorerConsoleScreen(matchId: widget.matchId),
                              ),
                            );
                          }
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
                            if (match.isUpcoming) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MatchLineupScreen(match: match),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ScorerConsoleScreen(matchId: widget.matchId),
                                ),
                              );
                            }
                          }
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(singleMatchProvider(widget.matchId));
                  ref.invalidate(matchInningsProvider(widget.matchId));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: hasInningsStarted
                      ? Column(
                          children: [
                            // 1. Live Match Scoreboard Banner
                            LiveScoreboardBanner(
                              match: match,
                              innings: currentInnings,
                              battingTeam: battingTeam,
                              bowlingTeam: bowlingTeam,
                              firstInningsRuns: firstInningsRuns,
                            ),

                            // 2. Delivery Timeline / Wheel
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: DeliveryWheel(recentBalls: currentInnings.recentBalls),
                            ),

                            const SizedBox(height: 16),

                            // 3. Batting & Bowling Scorecards with Multi-Innings Tabs
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: LiveScorecardTabs(
                                match: match,
                                inningsList: inningsList,
                                teamMap: teamMap,
                                playerMap: playerMap,
                              ),
                            ),

                            const SizedBox(height: 32),
                          ],
                        )
                      : _buildUpcomingMatchPreview(
                          context: context,
                          match: match,
                          teamA: teamA,
                          teamB: teamB,
                          playerMap: playerMap,
                          canScore: user.canScore,
                        ),
                ),
              ),

              // Celebration Overlay Popup
              if (_activeCelebrationType != null)
                CelebrationOverlay(
                  type: _activeCelebrationType!,
                  text: _activeCelebrationText ?? '',
                  onDismissed: () {
                    if (mounted) setState(() => _activeCelebrationType = null);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcomingMatchPreview({
    required BuildContext context,
    required MatchModel match,
    required TeamModel teamA,
    required TeamModel teamB,
    required Map<String, PlayerModel> playerMap,
    required bool canScore,
  }) {
    final tossWinner = match.tossWinnerId != null
        ? (match.tossWinnerId == teamA.id ? teamA : teamB)
        : null;

    final teamAPlayers = match.teamAPlayingVI.map((id) => playerMap[id]).whereType<PlayerModel>().toList();
    final teamBPlayers = match.teamBPlayingVI.map((id) => playerMap[id]).whereType<PlayerModel>().toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Match Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF131C2E), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
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
                        '${match.stage} • MATCH #${match.matchNumber}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentCyan,
                        ),
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
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentCyan,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildTeamAvatar(teamA),
                          const SizedBox(height: 8),
                          Text(
                            teamA.name,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'VS',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _buildTeamAvatar(teamB),
                          const SizedBox(height: 8),
                          Text(
                            teamB.name,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Colors.white10),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 5),
                        Text(
                          '${match.day}, ${match.date} • ${match.time}',
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
          ),

          const SizedBox(height: 16),

          // 2. Toss Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sports_rounded, size: 20, color: AppColors.accentCyan),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOSS STATUS',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tossWinner != null
                            ? '${tossWinner.name} won the toss and elected to ${match.tossDecision ?? 'BAT'}.'
                            : 'Toss has not taken place yet.',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tossWinner != null ? AppColors.accent : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Playing Squads Preview
          if (teamAPlayers.isNotEmpty || teamBPlayers.isNotEmpty) ...[
            Text(
              match.playersPerTeam == 11
                  ? 'ANNOUNCED PLAYING XI'
                  : (match.playersPerTeam == 6 ? 'ANNOUNCED PLAYING VI' : 'ANNOUNCED PLAYING ${match.playersPerTeam}'),
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildSquadList(teamA.shortName, teamAPlayers)),
                const SizedBox(width: 12),
                Expanded(child: _buildSquadList(teamB.shortName, teamBPlayers)),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // 4. Scorer Action Button
          if (canScore) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(
                'SET LINEUPS & START MATCH',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MatchLineupScreen(match: match)),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamAvatar(TeamModel team) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceLight,
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: ClipOval(
        child: team.logoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: team.logoUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _fallbackAvatarText(team.shortName),
              )
            : _fallbackAvatarText(team.shortName),
      ),
    );
  }

  Widget _fallbackAvatarText(String shortName) {
    return Center(
      child: Text(
        shortName.isNotEmpty ? shortName[0] : 'T',
        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildSquadList(String teamShortName, List<PlayerModel> players) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teamShortName,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.accent),
          ),
          const SizedBox(height: 8),
          if (players.isEmpty)
            Text(
              'No lineup submitted',
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
            )
          else
            ...players.map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Text(
                  '• ${p.name}',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
