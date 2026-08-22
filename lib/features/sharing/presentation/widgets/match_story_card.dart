import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../scoring/models/match_model.dart';
import '../../../scoring/models/team_model.dart';
import '../../../scoring/models/player_model.dart';
import '../../../scoring/models/innings_model.dart';
import '../../../scoring/models/batting_score.dart';
import '../../../scoring/models/bowling_score.dart';

enum StoryCardTemplate {
  matchResult,
  playerOfTheMatch,
  massiveSix,
  wicketFall,
  matchOverview,
}

class MatchStoryCard extends StatelessWidget {
  final StoryCardTemplate template;
  final MatchModel match;
  final TeamModel teamA;
  final TeamModel teamB;
  final List<InningsModel> inningsList;
  final List<PlayerModel> allPlayers;
  final List<BattingScore> allBattingScores;
  final List<BowlingScore> allBowlingScores;
  final PlayerModel? potmPlayer;
  final PlayerModel? highlightBatsman;
  final PlayerModel? highlightBowler;
  final String? customHighlightText;

  const MatchStoryCard({
    super.key,
    required this.template,
    required this.match,
    required this.teamA,
    required this.teamB,
    required this.inningsList,
    required this.allPlayers,
    this.allBattingScores = const [],
    this.allBowlingScores = const [],
    this.potmPlayer,
    this.highlightBatsman,
    this.highlightBowler,
    this.customHighlightText,
  });

  InningsModel? get _innings1 => inningsList.isNotEmpty
      ? inningsList.firstWhere((i) => i.inningsNumber == 1, orElse: () => inningsList.first)
      : null;

  InningsModel? get _innings2 => inningsList.length > 1
      ? inningsList.firstWhere((i) => i.inningsNumber == 2, orElse: () => inningsList.last)
      : null;

  TeamModel _getTeam(String teamId) {
    if (teamId == teamA.id) return teamA;
    if (teamId == teamB.id) return teamB;
    return TeamModel(id: teamId, name: 'Team', shortName: 'TM');
  }

  PlayerModel? _findPlayer(String? id) {
    if (id == null) return null;
    try {
      return allPlayers.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 9:16 Instagram Story Canvas Dimensions (360 x 640 @ 3x = 1080 x 1920)
    return Container(
      width: 360,
      height: 640,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 1. Dynamic Background Gradients & Glows
          _buildBackgroundGradients(),

          // 2. Main Story Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // Championship Header Bar
                  _buildHeader(),

                  const Spacer(flex: 1),

                  // Template-specific Centerpiece Body
                  _buildTemplateBody(),

                  const Spacer(flex: 2),

                  // Footer Watermark & Branding
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGradients() {
    Color primaryGlow = AppColors.accent;
    Color secondaryGlow = AppColors.accentCyan;

    switch (template) {
      case StoryCardTemplate.matchResult:
        primaryGlow = AppColors.gold;
        secondaryGlow = AppColors.accent;
        break;
      case StoryCardTemplate.playerOfTheMatch:
        primaryGlow = const Color(0xFFFFB703);
        secondaryGlow = const Color(0xFFFB8500);
        break;
      case StoryCardTemplate.massiveSix:
        primaryGlow = AppColors.sixRuns;
        secondaryGlow = AppColors.accentCyan;
        break;
      case StoryCardTemplate.wicketFall:
        primaryGlow = AppColors.wicket;
        secondaryGlow = const Color(0xFF9333EA);
        break;
      case StoryCardTemplate.matchOverview:
        primaryGlow = AppColors.accent;
        secondaryGlow = AppColors.accentCyan;
        break;
    }

    return Stack(
      children: [
        // Top radial glow
        Positioned(
          top: -80,
          right: -80,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primaryGlow.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Bottom radial glow
        Positioned(
          bottom: -100,
          left: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  secondaryGlow.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Noise grid overlay pattern simulation
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0F172A).withValues(alpha: 0.8),
                const Color(0xFF020617).withValues(alpha: 0.95),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'WASA PREMIER LEAGUE 2026',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${match.stage} • M#${match.matchNumber}',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.2),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateBody() {
    switch (template) {
      case StoryCardTemplate.matchResult:
        return _buildMatchResultBody();
      case StoryCardTemplate.playerOfTheMatch:
        return _buildPOTMBody();
      case StoryCardTemplate.massiveSix:
        return _buildMassiveSixBody();
      case StoryCardTemplate.wicketFall:
        return _buildWicketFallBody();
      case StoryCardTemplate.matchOverview:
        return _buildMatchOverviewBody();
    }
  }

  // 1. FINAL MATCH RESULT TEMPLATE
  Widget _buildMatchResultBody() {
    final inn1 = _innings1;
    final inn2 = _innings2;
    final team1 = inn1 != null ? _getTeam(inn1.battingTeamId) : teamA;
    final team2 = inn2 != null ? _getTeam(inn2.battingTeamId) : teamB;

    return Column(
      children: [
        // Trophy & Match Result Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 16),
              const SizedBox(width: 6),
              Text(
                'MATCH RESULT',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Team 1 Score Card
        _buildTeamScoreTile(
          team: team1,
          innings: inn1,
          isWinner: match.winningTeamId == team1.id,
        ),

        const SizedBox(height: 12),

        // VS Divider
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 40, height: 1, color: Colors.white24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'VS',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Container(width: 40, height: 1, color: Colors.white24),
          ],
        ),

        const SizedBox(height: 12),

        // Team 2 Score Card
        _buildTeamScoreTile(
          team: team2,
          innings: inn2,
          isWinner: match.winningTeamId == team2.id,
        ),

        const SizedBox(height: 24),

        // Verdict Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
          ),
          child: Text(
            match.resultText?.toUpperCase() ?? 'MATCH CONCLUDED',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.accent,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamScoreTile({
    required TeamModel team,
    required InningsModel? innings,
    required bool isWinner,
  }) {
    final runs = innings?.runs ?? 0;
    final wickets = innings?.wickets ?? 0;
    final overs = innings?.oversString ?? '0.0';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isWinner ? AppColors.surfaceLight : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner ? AppColors.gold.withValues(alpha: 0.6) : Colors.white12,
          width: isWinner ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Logo / Avatar
          _buildTeamLogo(team, radius: 24),
          const SizedBox(width: 14),

          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        team.name,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isWinner) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 16),
                    ],
                  ],
                ),
                Text(
                  '($overs / ${match.maxOvers}.0 ov)',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$runs/$wickets',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isWinner ? AppColors.gold : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. PLAYER OF THE MATCH (POTM) TEMPLATE
  Widget _buildPOTMBody() {
    final player = potmPlayer ?? _findBestPerformer();
    final playerTeam = player != null ? _getTeam(player.teamId) : teamA;

    // Find player's batting and bowling stats in this match
    final batting = allBattingScores.where((b) => b.playerId == player?.id).toList();
    final bowling = allBowlingScores.where((b) => b.playerId == player?.id).toList();

    final bRuns = batting.isNotEmpty ? batting.first.runs : null;
    final bBalls = batting.isNotEmpty ? batting.first.balls : null;
    final bFours = batting.isNotEmpty ? batting.first.fours : null;
    final bSixes = batting.isNotEmpty ? batting.first.sixes : null;

    final bwWickets = bowling.isNotEmpty ? bowling.first.wickets : null;
    final bwRuns = bowling.isNotEmpty ? bowling.first.runs : null;
    final bwOvers = bowling.isNotEmpty ? bowling.first.oversString : null;

    return Column(
      children: [
        // POTM Crown Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFBE0B), Color(0xFFFB5607)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFB5607).withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                'PLAYER OF THE MATCH',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Big Avatar Frame
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFFFFBE0B), Colors.transparent],
                ),
                border: Border.all(color: const Color(0xFFFFBE0B), width: 3),
              ),
            ),
            CircleAvatar(
              radius: 54,
              backgroundColor: AppColors.surfaceLight,
              backgroundImage: player?.photoUrl != null && player!.photoUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(ImageUrlHelper.formatDirectUrl(player.photoUrl)!)
                  : null,
              child: player?.photoUrl == null || player!.photoUrl!.isEmpty
                  ? Text(
                      player?.name.isNotEmpty == true ? player!.name[0] : '★',
                      style: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.gold),
                    )
                  : null,
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Player Name & Team
        Text(
          player?.name.toUpperCase() ?? 'MATCH HERO',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          '${playerTeam.name.toUpperCase()} • ${player?.role.toUpperCase() ?? "ALL-ROUNDER"}',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.accentCyan,
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 20),

        // Key Performance Stats Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFBE0B).withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (bRuns != null)
                Column(
                  children: [
                    Text(
                      '$bRuns',
                      style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.gold),
                    ),
                    Text(
                      'Runs ($bBalls b • 4s:$bFours 6s:$bSixes)',
                      style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              if (bRuns != null && bwWickets != null)
                Container(width: 1, height: 36, color: Colors.white12),
              if (bwWickets != null)
                Column(
                  children: [
                    Text(
                      '$bwWickets/$bwRuns',
                      style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.accentCyan),
                    ),
                    Text(
                      'Wickets ($bwOvers ov)',
                      style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              if (bRuns == null && bwWickets == null)
                Text(
                  'Match Winning Match Impact',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.gold),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // 3. MASSIVE SIX MOMENT TEMPLATE
  Widget _buildMassiveSixBody() {
    final batsman = highlightBatsman ?? _findTopBatsman();
    final bScore = allBattingScores.firstWhere(
      (b) => b.playerId == batsman?.id,
      orElse: () => BattingScore(id: '', inningsId: '', playerId: batsman?.id ?? '', runs: 24, balls: 10, sixes: 3),
    );

    return Column(
      children: [
        // MAXIMUM TAG
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF007F), Color(0xFF7928CA)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF007F).withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                'MAXIMUM! 🚀 6 RUNS',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Big Six Number Display
        Text(
          '6',
          style: GoogleFonts.outfit(
            fontSize: 88,
            fontWeight: FontWeight.w900,
            color: AppColors.sixRuns,
            height: 0.9,
            shadows: [
              Shadow(
                color: AppColors.sixRuns.withValues(alpha: 0.8),
                blurRadius: 30,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Text(
          batsman?.name.toUpperCase() ?? 'POWER HITTER',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),

        Text(
          'Score: ${bScore.runs} (${bScore.balls}b) • ${bScore.sixes} SIXES',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.accentCyan,
          ),
        ),

        const SizedBox(height: 20),

        if (customHighlightText != null && customHighlightText!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              customHighlightText!,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  // 4. WICKET MOMENT TEMPLATE
  Widget _buildWicketFallBody() {
    final bowler = highlightBowler ?? _findTopBowler();
    final batsman = highlightBatsman;

    return Column(
      children: [
        // WICKET TAG
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE11D48).withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cancel_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                'WICKET! ⚡ TIMBER',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Wicket Icon
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.wicket.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.wicket, width: 2.5),
          ),
          child: const Icon(
            Icons.sports_baseball_rounded,
            color: AppColors.wicket,
            size: 46,
          ),
        ),

        const SizedBox(height: 18),

        Text(
          bowler?.name.toUpperCase() ?? 'STRIKE BOWLER',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),

        Text(
          'CLEAN BOWLED / DISMISSAL',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.wicket,
            letterSpacing: 0.8,
          ),
        ),

        if (batsman != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              'Batter: ${batsman.name} departs',
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }

  // 5. MATCH OVERVIEW TEMPLATE
  Widget _buildMatchOverviewBody() {
    final inn1 = _innings1;
    final inn2 = _innings2;
    final team1 = inn1 != null ? _getTeam(inn1.battingTeamId) : teamA;
    final team2 = inn2 != null ? _getTeam(inn2.battingTeamId) : teamB;

    return Column(
      children: [
        Text(
          'MATCH SUMMARY',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.accentCyan,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),

        _buildTeamScoreTile(team: team1, innings: inn1, isWinner: match.winningTeamId == team1.id),
        const SizedBox(height: 10),
        _buildTeamScoreTile(team: team2, innings: inn2, isWinner: match.winningTeamId == team2.id),

        const SizedBox(height: 16),

        // Key Performers Mini strip
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOP BATSMAN', style: GoogleFonts.outfit(fontSize: 9, color: AppColors.accent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      _findTopBatsman()?.name ?? 'Top Batter',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOP BOWLER', style: GoogleFonts.outfit(fontSize: 9, color: AppColors.gold, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      _findTopBowler()?.name ?? 'Top Bowler',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamLogo(TeamModel team, {double radius = 20}) {
    final directUrl = ImageUrlHelper.formatDirectUrl(team.logoUrl);
    if (directUrl != null && directUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surface,
        backgroundImage: CachedNetworkImageProvider(directUrl),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.accent.withValues(alpha: 0.2),
      child: Text(
        team.shortName.isNotEmpty ? team.shortName : team.name.substring(0, 1),
        style: GoogleFonts.outfit(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w900,
          color: AppColors.accent,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          height: 1,
          color: Colors.white.withValues(alpha: 0.12),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_cricket_rounded, color: AppColors.accent, size: 14),
                const SizedBox(width: 6),
                Text(
                  'WASA Cricket App',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Text(
              '#WPL2026 • Live Match',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.accentCyan,
              ),
            ),
          ],
        ),
      ],
    );
  }

  PlayerModel? _findBestPerformer() {
    if (allBattingScores.isNotEmpty) {
      final sorted = List<BattingScore>.from(allBattingScores)..sort((a, b) => b.runs.compareTo(a.runs));
      return _findPlayer(sorted.first.playerId);
    }
    if (allBowlingScores.isNotEmpty) {
      final sorted = List<BowlingScore>.from(allBowlingScores)..sort((a, b) => b.wickets.compareTo(a.wickets));
      return _findPlayer(sorted.first.playerId);
    }
    return null;
  }

  PlayerModel? _findTopBatsman() {
    if (allBattingScores.isNotEmpty) {
      final sorted = List<BattingScore>.from(allBattingScores)..sort((a, b) => b.runs.compareTo(a.runs));
      return _findPlayer(sorted.first.playerId);
    }
    return null;
  }

  PlayerModel? _findTopBowler() {
    if (allBowlingScores.isNotEmpty) {
      final sorted = List<BowlingScore>.from(allBowlingScores)..sort((a, b) => b.wickets.compareTo(a.wickets));
      return _findPlayer(sorted.first.playerId);
    }
    return null;
  }
}
