import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../scoring/models/innings_model.dart';
import '../../../scoring/models/batting_score.dart';
import '../../../scoring/models/bowling_score.dart';
import '../../../scoring/models/player_model.dart';
import '../../../scoring/models/match_model.dart';
import '../../../scoring/models/team_model.dart';
import '../../../match_management/providers/tournament_providers.dart';

class LiveScorecardTabs extends ConsumerStatefulWidget {
  final MatchModel match;
  final List<InningsModel> inningsList;
  final Map<String, TeamModel> teamMap;
  final Map<String, PlayerModel> playerMap;

  const LiveScorecardTabs({
    super.key,
    required this.match,
    required this.inningsList,
    required this.teamMap,
    required this.playerMap,
  });

  @override
  ConsumerState<LiveScorecardTabs> createState() => _LiveScorecardTabsState();
}

class _LiveScorecardTabsState extends ConsumerState<LiveScorecardTabs> {
  int _selectedInningsIndex = 0;

  @override
  void initState() {
    super.initState();
    // Default to the latest / active innings
    if (widget.inningsList.length > 1) {
      _selectedInningsIndex = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.inningsList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text('Scorecard will appear once the match starts', style: GoogleFonts.outfit(color: AppColors.textMuted)),
        ),
      );
    }

    final safeIndex = _selectedInningsIndex.clamp(0, widget.inningsList.length - 1);
    final activeInnings = widget.inningsList[safeIndex];

    final battingTeam = widget.teamMap[activeInnings.battingTeamId] ??
        TeamModel(id: activeInnings.battingTeamId, name: 'Batting Team', shortName: 'BAT');
    final bowlingTeam = widget.teamMap[activeInnings.bowlingTeamId] ??
        TeamModel(id: activeInnings.bowlingTeamId, name: 'Bowling Team', shortName: 'BWL');

    final battingAsync = ref.watch(battingScoresProvider(activeInnings.id));
    final bowlingAsync = ref.watch(bowlingScoresProvider(activeInnings.id));

    final battingScores = battingAsync.value ?? [];
    final bowlingScores = bowlingAsync.value ?? [];

    final playingSquad = battingTeam.id == widget.match.teamAId ? widget.match.teamAPlayingVI : widget.match.teamBPlayingVI;
    final battedPlayerIds = battingScores.map((b) => b.playerId).toSet();
    final didNotBatPlayers = playingSquad.where((pid) => !battedPlayerIds.contains(pid)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. ESPN Cricinfo Segmented Innings Switcher Tabs
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              for (int i = 0; i < widget.inningsList.length; i++)
                Expanded(
                  child: _buildInningsChip(
                    index: i,
                    inn: widget.inningsList[i],
                    isSelected: _selectedInningsIndex == i,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Batting Table (ESPN Cricinfo Style)
        _buildSectionTitle('${battingTeam.shortName} BATTING'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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

              // Batters List
              if (battingScores.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text('No batting records yet', style: GoogleFonts.outfit(color: AppColors.textMuted)),
                  ),
                )
              else
                ...battingScores.map((b) => _buildBattingRow(b)),

              const Divider(height: 1, color: Colors.white10),

              // Extras
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Extras', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    Text(
                      '${activeInnings.totalExtras} (b ${activeInnings.byes}, lb ${activeInnings.legByes}, w ${activeInnings.wides}, nb ${activeInnings.noBalls})',
                      style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white10),

              // TOTAL
              Container(
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
                        Text('TOTAL', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.accent)),
                        Text('${activeInnings.oversString} Overs (RR: ${activeInnings.crr.toStringAsFixed(2)})', style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    Text(
                      '${activeInnings.runs}/${activeInnings.wickets}',
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),

              // Did Not Bat
              if (didNotBatPlayers.isNotEmpty) ...[
                const Divider(height: 1, color: Colors.white10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Yet to bat: ', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                      Expanded(
                        child: Text(
                          didNotBatPlayers.map((pid) => widget.playerMap[pid]?.name ?? pid).join(', '),
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

        // 3. Bowling Table (ESPN Cricinfo Style)
        _buildSectionTitle('${bowlingTeam.shortName} BOWLING'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white10),

              // Bowlers
              if (bowlingScores.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text('No bowling records yet', style: GoogleFonts.outfit(color: AppColors.textMuted)),
                  ),
                )
              else
                ...bowlingScores.map((bo) => _buildBowlingRow(bo)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInningsChip({
    required int index,
    required InningsModel inn,
    required bool isSelected,
  }) {
    final team = widget.teamMap[inn.battingTeamId];
    final shortName = team?.shortName ?? (inn.inningsNumber == 1 ? '1st Inn' : '2nd Inn');

    return InkWell(
      onTap: () => setState(() => _selectedInningsIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$shortName INNINGS',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.black : AppColors.textMuted,
              ),
            ),
            Text(
              '${inn.runs}/${inn.wickets} (${inn.oversString} ov)',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.accent,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildBattingRow(BattingScore b) {
    final player = widget.playerMap[b.playerId];
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
          Expanded(
            flex: 1,
            child: Text('${b.balls}', textAlign: TextAlign.right, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted)),
          ),
          Expanded(
            flex: 1,
            child: Text('${b.fours}', textAlign: TextAlign.right, style: GoogleFonts.outfit(fontSize: 12, color: b.fours > 0 ? AppColors.fourRuns : AppColors.textMuted)),
          ),
          Expanded(
            flex: 1,
            child: Text('${b.sixes}', textAlign: TextAlign.right, style: GoogleFonts.outfit(fontSize: 12, color: b.sixes > 0 ? AppColors.sixRuns : AppColors.textMuted)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              b.strikeRate.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: b.strikeRate >= 150 ? AppColors.accent : AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBowlingRow(BowlingScore bo) {
    final player = widget.playerMap[bo.playerId];
    final name = player?.name ?? 'Bowler ${bo.playerId}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(name, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          Expanded(
            flex: 1,
            child: Text(bo.oversString, textAlign: TextAlign.right, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textPrimary)),
          ),
          Expanded(
            flex: 1,
            child: Text('${bo.maidens}', textAlign: TextAlign.right, style: GoogleFonts.outfit(fontSize: 12, color: bo.maidens > 0 ? AppColors.gold : AppColors.textMuted)),
          ),
          Expanded(
            flex: 1,
            child: Text('${bo.runs}', textAlign: TextAlign.right, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${bo.wickets}',
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: bo.wickets > 0 ? AppColors.wicket : AppColors.textMuted),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              bo.economy.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: bo.economy <= 8.0 ? AppColors.accent : AppColors.textSecondary),
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
