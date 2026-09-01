import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/cricket_calculator.dart';
import '../../scoring/models/match_model.dart';
import '../../scoring/models/team_model.dart';
import '../../scoring/models/player_model.dart';
import '../../scoring/models/innings_model.dart';
import '../../scoring/models/batting_score.dart';
import '../../scoring/models/bowling_score.dart';
import '../../match_management/providers/tournament_providers.dart';
import '../../sharing/presentation/share_story_modal.dart';
import '../../sharing/presentation/widgets/match_story_card.dart';

class MatchScorecardScreen extends ConsumerStatefulWidget {
  final String matchId;

  const MatchScorecardScreen({super.key, required this.matchId});

  @override
  ConsumerState<MatchScorecardScreen> createState() => _MatchScorecardScreenState();
}

class _MatchScorecardScreenState extends ConsumerState<MatchScorecardScreen>
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

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(singleMatchProvider(widget.matchId));
    final teamsAsync = ref.watch(teamsProvider);
    final playersAsync = ref.watch(playersProvider);
    final inningsAsync = ref.watch(matchInningsProvider(widget.matchId));

    final match = matchAsync.value;
    final matchTourId = match?.tournamentId.isNotEmpty == true ? match!.tournamentId : ref.watch(activeTournamentIdProvider);
    final matchTeamsAsync = ref.watch(tournamentTeamsProvider(matchTourId));
    final teams = matchTeamsAsync.value ?? teamsAsync.value ?? [];
    final players = playersAsync.value ?? [];
    final inningsList = inningsAsync.value ?? [];

    if (match == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('MATCH SCORECARD')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    final teamMap = {for (var t in teams) t.id: t};
    final playerMap = {for (var p in players) p.id: p};

    final teamA = teamMap[match.teamAId] ??
        ref.watch(singleTeamStreamProvider(match.teamAId)).value ??
        TeamModel(id: match.teamAId, name: 'Team A', shortName: 'TMA');
    final teamB = teamMap[match.teamBId] ??
        ref.watch(singleTeamStreamProvider(match.teamBId)).value ??
        TeamModel(id: match.teamBId, name: 'Team B', shortName: 'TMB');

    final innings1 = inningsList.isNotEmpty ? inningsList.firstWhere((i) => i.inningsNumber == 1, orElse: () => inningsList.first) : null;
    final innings2 = inningsList.length > 1 ? inningsList.firstWhere((i) => i.inningsNumber == 2, orElse: () => inningsList.last) : null;

    final inn1BattingTeam = innings1 != null
        ? (teamMap[innings1.battingTeamId] ?? ref.watch(singleTeamStreamProvider(innings1.battingTeamId)).value ?? teamA)
        : teamA;
    final inn2BattingTeam = innings2 != null
        ? (teamMap[innings2.battingTeamId] ?? ref.watch(singleTeamStreamProvider(innings2.battingTeamId)).value ?? teamB)
        : teamB;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${match.stage} MATCH ${match.matchNumber}',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accentCyan),
            ),
            Text(
              '${teamA.shortName} vs ${teamB.shortName} Scorecard',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.accent),
            tooltip: 'Share Instagram Story Card',
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
        ],
      ),
      body: Column(
        children: [
          // 1. ESPN Cricinfo Match Header Summary Card
          _buildEspnMatchHeader(match, teamA, teamB, innings1, innings2),

          // 2. Innings Selector Tabs (ESPN Cricinfo Style)
          Container(
            color: AppColors.primary,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accent,
              indicatorWeight: 3,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: [
                Tab(text: '${inn1BattingTeam.shortName} Innings'),
                Tab(text: innings2 != null ? '${inn2BattingTeam.shortName} Innings' : '2nd Innings'),
                const Tab(text: 'Match Info'),
              ],
            ),
          ),

          // 3. Tab Views with detailed ESPN Cricinfo Scorecards
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1st Innings Tab
                innings1 != null
                    ? _InningsScorecardView(
                        innings: innings1,
                        battingTeam: inn1BattingTeam,
                        bowlingTeam: inn1BattingTeam.id == teamA.id ? teamB : teamA,
                        playerMap: playerMap,
                        match: match,
                      )
                    : _buildEmptyInningsPlaceholder('1st Innings has not started yet'),

                // 2nd Innings Tab
                innings2 != null
                    ? _InningsScorecardView(
                        innings: innings2,
                        battingTeam: inn2BattingTeam,
                        bowlingTeam: inn2BattingTeam.id == teamA.id ? teamB : teamA,
                        playerMap: playerMap,
                        match: match,
                      )
                    : _buildEmptyInningsPlaceholder('2nd Innings has not started yet'),

                // Match Info Tab
                _buildMatchInfoTab(match, teamA, teamB, playerMap),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEspnMatchHeader(
    MatchModel match,
    TeamModel teamA,
    TeamModel teamB,
    InningsModel? inn1,
    InningsModel? inn2,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Match Subtitle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${match.venue} • ${match.date}',
                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: match.isLive
                      ? AppColors.liveRed.withValues(alpha: 0.2)
                      : (match.isCompleted ? AppColors.accent.withValues(alpha: 0.15) : AppColors.surfaceLight),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  match.status,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: match.isLive
                        ? AppColors.liveRed
                        : (match.isCompleted ? AppColors.accent : AppColors.textMuted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Team A Score Row
          _buildTeamScoreRow(teamA, inn1?.battingTeamId == teamA.id ? inn1 : inn2, match),
          const SizedBox(height: 8),

          // Team B Score Row
          _buildTeamScoreRow(teamB, inn1?.battingTeamId == teamB.id ? inn1 : inn2, match),
          const SizedBox(height: 12),

          // Result or Status Equation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  match.isCompleted ? Icons.emoji_events_rounded : Icons.info_outline,
                  size: 16,
                  color: match.isCompleted ? AppColors.gold : AppColors.accentCyan,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    match.resultText ??
                        (match.isLive
                            ? 'Match in progress • ${match.oversPerSide} overs per side'
                            : 'Match scheduled to start at ${match.time}'),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: match.isCompleted ? AppColors.gold : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    ShareStoryModal.show(
                      context,
                      match: match,
                      teamA: teamA,
                      teamB: teamB,
                      inningsList: ref.read(matchInningsProvider(match.id)).value ?? [],
                      allPlayers: ref.read(playersProvider).value ?? [],
                      initialTemplate: match.isCompleted ? StoryCardTemplate.matchResult : StoryCardTemplate.matchOverview,
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.share_rounded, size: 12, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Story',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamScoreRow(TeamModel team, InningsModel? inn, MatchModel match) {
    return Row(
      children: [
        // Logo
        Container(
          width: 28,
          height: 28,
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

        // Team Name
        Expanded(
          child: Text(
            team.name,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),

        // Score / Overs
        if (inn != null)
          Row(
            children: [
              Text(
                '${inn.runs}/${inn.wickets}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${inn.oversString}/${match.maxOvers} ov)',
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
            'Yet to bat',
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
          ),
      ],
    );
  }

  Widget _buildEmptyInningsPlaceholder(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_cricket, size: 54, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchInfoTab(
    MatchModel match,
    TeamModel teamA,
    TeamModel teamB,
    Map<String, PlayerModel> playerMap,
  ) {
    final squadLabel = match.playersPerTeam == 11
        ? 'Playing XI'
        : (match.playersPerTeam == 6 ? 'Playing VI' : 'Playing ${match.playersPerTeam}');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard('MATCH DETAILS', [
            _buildInfoRow('Tournament', 'WASA Premier League 2026'),
            _buildInfoRow('Match', '${match.stage} Match ${match.matchNumber}'),
            _buildInfoRow('Date & Time', '${match.date} at ${match.time}'),
            _buildInfoRow('Venue', match.venue),
            _buildInfoRow('Format', '${match.maxOvers} Overs per side • ${match.playersPerTeam} Players + 1 Reserve'),
            if (match.tossWinnerId != null)
              _buildInfoRow(
                'Toss',
                '${teamA.id == match.tossWinnerId ? teamA.name : teamB.name} won the toss and elected to ${match.tossDecision ?? "BAT"}',
              ),
            if (match.resultText != null) _buildInfoRow('Result', match.resultText!),
          ]),
          const SizedBox(height: 16),

          // Team Squads
          _buildInfoCard('${teamA.name} $squadLabel', [
            for (var pid in match.teamAPlayingVI)
              _buildPlayerRow(playerMap[pid] ?? PlayerModel(id: pid, teamId: teamA.id, name: 'Player $pid')),
            if (match.teamAReserveId != null)
              _buildInfoRow(
                'Reserve Player',
                playerMap[match.teamAReserveId!]?.name ?? 'Reserve (${match.teamAReserveId})',
              ),
          ]),
          const SizedBox(height: 16),

          _buildInfoCard('${teamB.name} $squadLabel', [
            for (var pid in match.teamBPlayingVI)
              _buildPlayerRow(playerMap[pid] ?? PlayerModel(id: pid, teamId: teamB.id, name: 'Player $pid')),
            if (match.teamBReserveId != null)
              _buildInfoRow(
                'Reserve Player',
                playerMap[match.teamBReserveId!]?.name ?? 'Reserve (${match.teamBReserveId})',
              ),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.accent,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(PlayerModel player) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.person, size: 14, color: AppColors.accentCyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              player.name,
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            player.designation ?? player.role,
            style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _fallbackLogo(String text) {
    return Container(
      color: AppColors.primary,
      alignment: Alignment.center,
      child: Text(
        text.isNotEmpty ? text.substring(0, 1) : 'W',
        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
      ),
    );
  }
}

/// Dedicated ESPN Cricinfo Innings Scorecard View
class _InningsScorecardView extends ConsumerWidget {
  final InningsModel innings;
  final TeamModel battingTeam;
  final TeamModel bowlingTeam;
  final Map<String, PlayerModel> playerMap;
  final MatchModel match;

  const _InningsScorecardView({
    required this.innings,
    required this.battingTeam,
    required this.bowlingTeam,
    required this.playerMap,
    required this.match,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final battingAsync = ref.watch(battingScoresProvider(innings.id));
    final bowlingAsync = ref.watch(bowlingScoresProvider(innings.id));

    final battingScores = battingAsync.value ?? [];
    final bowlingScores = bowlingAsync.value ?? [];

    // Identify players who did not bat from the team squad
    final playingSquad = battingTeam.id == match.teamAId ? match.teamAPlayingVI : match.teamBPlayingVI;
    final battedPlayerIds = battingScores.map((b) => b.playerId).toSet();
    final didNotBatPlayers = playingSquad.where((pid) => !battedPlayerIds.contains(pid)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Batting Scorecard Table
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 5, child: Text('BATTER', style: _headerStyle)),
                      Expanded(flex: 1, child: Text('R', textAlign: TextAlign.right, style: _headerStyleBold)),
                      Expanded(flex: 1, child: Text('B', textAlign: TextAlign.right, style: _headerStyle)),
                      Expanded(flex: 1, child: Text('4s', textAlign: TextAlign.right, style: _headerStyle)),
                      Expanded(flex: 1, child: Text('6s', textAlign: TextAlign.right, style: _headerStyle)),
                      Expanded(flex: 2, child: Text('SR', textAlign: TextAlign.right, style: _headerStyle)),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white10),

                // Batsmen Rows
                if (battingScores.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text('No batting entries yet', style: GoogleFonts.outfit(color: AppColors.textMuted)),
                    ),
                  )
                else
                  ...battingScores.map((b) => _buildBattingRow(b)),

                const Divider(height: 1, color: Colors.white10),

                // Extras Row
                _buildExtrasRow(),
                const Divider(height: 1, color: Colors.white10),

                // TOTAL Row
                _buildTotalRow(),

                // Did Not Bat Section
                if (didNotBatPlayers.isNotEmpty) ...[
                  const Divider(height: 1, color: Colors.white10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yet to bat: ',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                        ),
                        Expanded(
                          child: Text(
                            didNotBatPlayers.map((pid) => playerMap[pid]?.name ?? pid).join(', '),
                            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.accentCyan),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Bowling Figures Table
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 5, child: Text('BOWLER', style: _headerStyle)),
                      Expanded(flex: 1, child: Text('O', textAlign: TextAlign.right, style: _headerStyle)),
                      Expanded(flex: 1, child: Text('M', textAlign: TextAlign.right, style: _headerStyle)),
                      Expanded(flex: 1, child: Text('R', textAlign: TextAlign.right, style: _headerStyleBold)),
                      Expanded(flex: 1, child: Text('W', textAlign: TextAlign.right, style: _headerStyleBold)),
                      Expanded(flex: 2, child: Text('ECON', textAlign: TextAlign.right, style: _headerStyle)),
                      Expanded(flex: 1, child: Text('WD', textAlign: TextAlign.right, style: _headerStyle)),
                      Expanded(flex: 1, child: Text('NB', textAlign: TextAlign.right, style: _headerStyle)),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white10),

                // Bowlers Rows
                if (bowlingScores.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text('No bowling entries yet', style: GoogleFonts.outfit(color: AppColors.textMuted)),
                    ),
                  )
                else
                  ...bowlingScores.map((bo) => _buildBowlingRow(bo)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattingRow(BattingScore b) {
    final player = playerMap[b.playerId];
    final name = player?.name ?? 'Player ${b.playerId}';
    final isNotOut = !b.isOut;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isNotOut ? AppColors.accent.withValues(alpha: 0.03) : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
      ),
      child: Row(
        children: [
          // Batter name & dismissal
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: isNotOut ? FontWeight.bold : FontWeight.w600,
                        color: isNotOut ? AppColors.accent : AppColors.textPrimary,
                      ),
                    ),
                    if (isNotOut)
                      Text(
                        ' *',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accent,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  b.isOut ? (b.dismissal ?? 'Out') : 'not out',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: isNotOut ? AppColors.accentCyan : AppColors.textMuted,
                    fontStyle: isNotOut ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // Runs
          Expanded(
            flex: 1,
            child: Text(
              '${b.runs}',
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: b.runs >= 20 ? AppColors.gold : AppColors.textPrimary,
              ),
            ),
          ),

          // Balls
          Expanded(
            flex: 1,
            child: Text(
              '${b.balls}',
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
            ),
          ),

          // 4s
          Expanded(
            flex: 1,
            child: Text(
              '${b.fours}',
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(fontSize: 12, color: b.fours > 0 ? AppColors.fourRuns : AppColors.textMuted),
            ),
          ),

          // 6s
          Expanded(
            flex: 1,
            child: Text(
              '${b.sixes}',
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(fontSize: 12, color: b.sixes > 0 ? AppColors.sixRuns : AppColors.textMuted),
            ),
          ),

          // Strike Rate
          Expanded(
            flex: 2,
            child: Text(
              b.strikeRate.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: b.strikeRate >= 150 ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtrasRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Extras',
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          Text(
            '${innings.totalExtras} (b ${innings.byes}, lb ${innings.legByes}, w ${innings.wides}, nb ${innings.noBalls}, p ${innings.penaltyRuns})',
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accent,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                '${innings.oversString} Overs (RR: ${innings.crr.toStringAsFixed(2)})',
                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          Text(
            '${innings.runs}/${innings.wickets}',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBowlingRow(BowlingScore bo) {
    final player = playerMap[bo.playerId];
    final name = player?.name ?? 'Bowler ${bo.playerId}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
      ),
      child: Row(
        children: [
          // Bowler Name
          Expanded(
            flex: 5,
            child: Text(
              name,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Overs
          Expanded(
            flex: 1,
            child: Text(
              bo.oversString,
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),

          // Maidens
          Expanded(
            flex: 1,
            child: Text(
              '${bo.maidens}',
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(fontSize: 12, color: bo.maidens > 0 ? AppColors.gold : AppColors.textMuted),
            ),
          ),

          // Runs
          Expanded(
            flex: 1,
            child: Text(
              '${bo.runs}',
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),

          // Wickets
          Expanded(
            flex: 1,
            child: Text(
              '${bo.wickets}',
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: bo.wickets > 0 ? AppColors.wicket : AppColors.textMuted,
              ),
            ),
          ),

          // Economy
          Expanded(
            flex: 2,
            child: Text(
              bo.economy.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: bo.economy <= 8.0 ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ),

          // Wides
          Expanded(
            flex: 1,
            child: Text(
              '${bo.wides}',
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
            ),
          ),

          // No Balls
          Expanded(
            flex: 1,
            child: Text(
              '${bo.noBalls}',
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  static TextStyle get _headerStyle => GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      );

  static TextStyle get _headerStyleBold => GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
        letterSpacing: 0.5,
      );
}
