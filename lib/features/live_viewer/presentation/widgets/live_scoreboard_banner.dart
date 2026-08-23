import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/cricket_calculator.dart';
import '../../../scoring/models/match_model.dart';
import '../../../scoring/models/innings_model.dart';
import '../../../scoring/models/team_model.dart';

class LiveScoreboardBanner extends StatelessWidget {
  final MatchModel match;
  final InningsModel innings;
  final TeamModel? battingTeam;
  final TeamModel? bowlingTeam;
  final int? firstInningsRuns;

  const LiveScoreboardBanner({
    super.key,
    required this.match,
    required this.innings,
    required this.battingTeam,
    required this.bowlingTeam,
    this.firstInningsRuns,
  });

  @override
  Widget build(BuildContext context) {
    final isChasing = innings.inningsNumber == 2 && firstInningsRuns != null;
    final target = isChasing ? firstInningsRuns! + 1 : null;
    final runsNeeded = isChasing ? (target! - innings.runs) : null;
    final ballsRemaining = isChasing ? (match.maxBalls - innings.balls) : null;
    final rrr = isChasing
        ? CricketCalculator.calculateRRR(runsNeeded!, ballsRemaining!)
        : null;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF131C2E), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Bar: Stage & LIVE Status
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${match.stage} MATCH #${match.matchNumber}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: match.isLive
                        ? AppColors.liveRed.withOpacity(0.2)
                        : AppColors.completedGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: match.isLive ? AppColors.liveRed : AppColors.completedGreen,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: match.isLive ? AppColors.liveRed : AppColors.completedGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        match.status,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: match.isLive ? AppColors.liveRed : AppColors.completedGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white10),

          // Main Score Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Batting Team Logo & Name
                _buildTeamBadge(battingTeam, isBatting: true),

                // Center Score Display
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${innings.runs}',
                            style: GoogleFonts.outfit(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -1,
                            ),
                          ),
                          Text(
                            '/${innings.wickets}',
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.wicket,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'OVERS: ${innings.oversString} / ${match.maxOvers}.0',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (innings.isFreeHit) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.accent, width: 1),
                          ),
                          child: Text(
                            '⚡ FREE HIT',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Bowling Team Logo & Name
                _buildTeamBadge(bowlingTeam, isBatting: false),
              ],
            ),
          ),

          // Footer Metrics (CRR, RRR, Target Equation)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CRR: ${innings.crr.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                if (isChasing && rrr != null)
                  Text(
                    'RRR: ${rrr.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentCyan,
                    ),
                  ),
                if (isChasing && target != null)
                  Text(
                    'Target: $target',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamBadge(TeamModel? team, {required bool isBatting}) {
    final logoUrl = team?.formattedLogoUrl ?? '';
    final shortName = team?.shortName ?? (isBatting ? 'BAT' : 'BOWL');

    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceLight,
            border: Border.all(
              color: isBatting ? AppColors.accent : Colors.white24,
              width: isBatting ? 2 : 1,
            ),
          ),
          child: ClipOval(
            child: logoUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: logoUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _fallbackLogo(shortName),
                  )
                : _fallbackLogo(shortName),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          shortName,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isBatting ? AppColors.accent : AppColors.textPrimary,
          ),
        ),
        Text(
          isBatting ? 'Batting' : 'Bowling',
          style: GoogleFonts.outfit(
            fontSize: 10,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _fallbackLogo(String shortName) {
    return Center(
      child: Text(
        shortName.isNotEmpty ? shortName[0] : 'T',
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
