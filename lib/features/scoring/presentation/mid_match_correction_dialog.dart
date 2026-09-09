import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../models/match_model.dart';
import '../models/team_model.dart';
import '../models/player_model.dart';
import '../providers/scoring_controller.dart';
import '../../match_management/presentation/widgets/quick_add_player_dialog.dart';

class MidMatchCorrectionDialog extends ConsumerStatefulWidget {
  final String matchId;
  final MatchModel match;
  final TeamModel teamA;
  final TeamModel teamB;
  final List<PlayerModel> allPlayers;

  const MidMatchCorrectionDialog({
    super.key,
    required this.matchId,
    required this.match,
    required this.teamA,
    required this.teamB,
    required this.allPlayers,
  });

  @override
  ConsumerState<MidMatchCorrectionDialog> createState() => _MidMatchCorrectionDialogState();
}

class _MidMatchCorrectionDialogState extends ConsumerState<MidMatchCorrectionDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Lineup Editor State
  late Set<String> _teamAPlayingVI;
  String? _teamAReserveId;
  late Set<String> _teamBPlayingVI;
  String? _teamBReserveId;
  int _selectedTeamTab = 0; // 0 = Team A, 1 = Team B
  bool _isSavingLineup = false;

  // Scorecard Correction State
  bool _isBattingCorrection = true;
  String? _selectedOldPlayerId;
  String? _selectedNewPlayerId;
  bool _isSwappingPlayer = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _teamAPlayingVI = Set.from(widget.match.teamAPlayingVI);
    _teamAReserveId = widget.match.teamAReserveId;
    _teamBPlayingVI = Set.from(widget.match.teamBPlayingVI);
    _teamBReserveId = widget.match.teamBReserveId;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openQuickAddPlayer(TeamModel team, int targetSquadSize) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickAddPlayerBottomSheet(
        teamId: team.id,
        teamName: team.name,
        onPlayerAdded: (newPlayerId) {
          setState(() {
            final isTeamA = team.id == widget.teamA.id;
            final targetSet = isTeamA ? _teamAPlayingVI : _teamBPlayingVI;
            if (targetSet.length < targetSquadSize) {
              targetSet.add(newPlayerId);
            }
          });
        },
      ),
    );
  }

  Future<void> _saveLineupChanges() async {
    setState(() => _isSavingLineup = true);
    try {
      final controller = ref.read(liveScoringControllerProvider(widget.matchId).notifier);
      await controller.updateLineup(
        teamAPlayingVI: _teamAPlayingVI.toList(),
        teamAReserveId: _teamAReserveId,
        teamBPlayingVI: _teamBPlayingVI.toList(),
        teamBReserveId: _teamBReserveId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Text('Lineup updated successfully!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: AppColors.cardBackground,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating lineup: $e'), backgroundColor: AppColors.wicket),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingLineup = false);
    }
  }

  Future<void> _applyScorecardCorrection(Map<String, String> playerNamesMap) async {
    if (_selectedOldPlayerId == null || _selectedNewPlayerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both the mistaken player and the replacement player.'),
          backgroundColor: AppColors.wicket,
        ),
      );
      return;
    }

    if (_selectedOldPlayerId == _selectedNewPlayerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mistaken player and replacement player cannot be the same person.'),
          backgroundColor: AppColors.wicket,
        ),
      );
      return;
    }

    setState(() => _isSwappingPlayer = true);
    try {
      final newPlayerName = playerNamesMap[_selectedNewPlayerId] ?? 'Player';
      final controller = ref.read(liveScoringControllerProvider(widget.matchId).notifier);

      await controller.swapPlayer(
        oldPlayerId: _selectedOldPlayerId!,
        newPlayerId: _selectedNewPlayerId!,
        newPlayerName: newPlayerName,
        isBatting: _isBattingCorrection,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Scorecard corrected: ${playerNamesMap[_selectedOldPlayerId] ?? "Old"} ➔ $newPlayerName',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.cardBackground,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error correcting scorecard: $e'), backgroundColor: AppColors.wicket),
        );
      }
    } finally {
      if (mounted) setState(() => _isSwappingPlayer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scoringState = ref.watch(liveScoringControllerProvider(widget.matchId));
    final playerMap = {for (var p in widget.allPlayers) p.id: p};

    final teamAPlayers = widget.allPlayers.where((p) => p.teamId == widget.teamA.id).toList();
    final teamBPlayers = widget.allPlayers.where((p) => p.teamId == widget.teamB.id).toList();

    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.manage_accounts_rounded, color: AppColors.accentCyan, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mid-Match Squad & Scorecard Fix',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Correct wrong selections or swap players live',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: AppColors.surfaceLight,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accent,
                indicatorWeight: 3,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.groups_rounded, size: 18), text: 'Lineup & Squad'),
                  Tab(icon: Icon(Icons.swap_horiz_rounded, size: 18), text: 'Scorecard Correction'),
                ],
              ),
            ),

            // Tab Contents
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Lineup & Squad Editor
                  _buildLineupEditorTab(teamAPlayers, teamBPlayers),

                  // Tab 2: Scorecard Correction
                  _buildScorecardCorrectionTab(scoringState, playerMap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // Tab 1: Lineup Editor
  // ----------------------------------------------------
  Widget _buildLineupEditorTab(List<PlayerModel> teamAPlayers, List<PlayerModel> teamBPlayers) {
    final isTeamA = _selectedTeamTab == 0;
    final currentTeam = isTeamA ? widget.teamA : widget.teamB;
    final currentSquad = isTeamA ? teamAPlayers : teamBPlayers;
    final playingSet = isTeamA ? _teamAPlayingVI : _teamBPlayingVI;
    final reserveId = isTeamA ? _teamAReserveId : _teamBReserveId;
    final targetSquadSize = widget.match.playersPerTeam;

    return Column(
      children: [
        // Team Selector Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.background,
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(
                      widget.teamA.name,
                      style: GoogleFonts.outfit(
                        fontWeight: isTeamA ? FontWeight.w900 : FontWeight.normal,
                        fontSize: 12,
                        color: isTeamA ? Colors.black : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  selected: isTeamA,
                  selectedColor: AppColors.accent,
                  onSelected: (val) => setState(() => _selectedTeamTab = 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(
                      widget.teamB.name,
                      style: GoogleFonts.outfit(
                        fontWeight: !isTeamA ? FontWeight.w900 : FontWeight.normal,
                        fontSize: 12,
                        color: !isTeamA ? Colors.black : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  selected: !isTeamA,
                  selectedColor: AppColors.accent,
                  onSelected: (val) => setState(() => _selectedTeamTab = 1),
                ),
              ),
            ],
          ),
        ),

        // Subheader with + Add Player button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STARTERS (${playingSet.length}/$targetSquadSize Selected)',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: playingSet.length == targetSquadSize ? AppColors.accent : AppColors.wicket,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openQuickAddPlayer(currentTeam, targetSquadSize),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                label: Text('+ Add Player', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent, width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        // Player List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            itemCount: currentSquad.length,
            itemBuilder: (ctx, index) {
              final player = currentSquad[index];
              final isStarter = playingSet.contains(player.id);
              final isReserve = reserveId == player.id;

              return Card(
                color: isStarter
                    ? AppColors.accent.withValues(alpha: 0.12)
                    : (isReserve ? AppColors.accentCyan.withValues(alpha: 0.08) : AppColors.surfaceLight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isStarter
                        ? AppColors.accent
                        : (isReserve ? AppColors.accentCyan : Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: isStarter ? AppColors.accent : AppColors.background,
                    child: Text(
                      '${player.jerseyNumber ?? player.name[0]}',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isStarter ? Colors.black : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  title: Text(
                    player.name,
                    style: GoogleFonts.outfit(
                      fontWeight: isStarter ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '${player.role} • ${player.designation ?? "Member"}',
                    style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textMuted),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Toggle Starter
                      IconButton(
                        icon: Icon(
                          isStarter ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          color: isStarter ? AppColors.accent : AppColors.textMuted,
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() {
                            if (isStarter) {
                              playingSet.remove(player.id);
                            } else {
                              if (playingSet.length < targetSquadSize) {
                                playingSet.add(player.id);
                              }
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Save Lineup Button
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isSavingLineup ? null : _saveLineupChanges,
              icon: _isSavingLineup
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_isSavingLineup ? 'Saving...' : 'SAVE LINEUP CHANGES', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // Tab 2: Scorecard Correction
  // ----------------------------------------------------
  Widget _buildScorecardCorrectionTab(
    ScoringState scoringState,
    Map<String, PlayerModel> playerMap,
  ) {
    final innings = scoringState.innings;
    final currentBattingTeamId = innings.battingTeamId;
    final currentBowlingTeamId = innings.bowlingTeamId;

    // Available players on scorecard
    final activeBattingPlayerIds = scoringState.battingScores.keys.toList();
    final activeBowlingPlayerIds = scoringState.bowlingScores.keys.toList();

    final targetScorecardPlayerIds = _isBattingCorrection ? activeBattingPlayerIds : activeBowlingPlayerIds;
    final relevantTeamId = _isBattingCorrection ? currentBattingTeamId : currentBowlingTeamId;
    final squadCandidates = widget.allPlayers.where((p) => p.teamId == relevantTeamId).toList();

    final playerNamesMap = {for (var p in widget.allPlayers) p.id: p.name};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector: Batting vs Bowling Scorecard
          Text(
            '1. Which scorecard contains the mistake?',
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(
                      'Batting Scorecard',
                      style: GoogleFonts.outfit(
                        fontWeight: _isBattingCorrection ? FontWeight.bold : FontWeight.normal,
                        color: _isBattingCorrection ? Colors.black : AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  selected: _isBattingCorrection,
                  selectedColor: AppColors.accent,
                  onSelected: (val) {
                    setState(() {
                      _isBattingCorrection = true;
                      _selectedOldPlayerId = null;
                      _selectedNewPlayerId = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(
                      'Bowling Scorecard',
                      style: GoogleFonts.outfit(
                        fontWeight: !_isBattingCorrection ? FontWeight.bold : FontWeight.normal,
                        color: !_isBattingCorrection ? Colors.black : AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  selected: !_isBattingCorrection,
                  selectedColor: AppColors.accentCyan,
                  onSelected: (val) {
                    setState(() {
                      _isBattingCorrection = false;
                      _selectedOldPlayerId = null;
                      _selectedNewPlayerId = null;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Dropdown 1: Mistaken Player
          Text(
            '2. Select Mistaken Player Currently on Scorecard:',
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: AppColors.cardBackground,
                hint: Text('Select mistaken player', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted)),
                value: targetScorecardPlayerIds.contains(_selectedOldPlayerId) ? _selectedOldPlayerId : null,
                items: targetScorecardPlayerIds.map((id) {
                  final p = playerMap[id];
                  final name = p?.name ?? id;
                  String extraInfo = '';
                  if (_isBattingCorrection) {
                    final stat = scoringState.battingScores[id];
                    if (stat != null) extraInfo = ' (${stat.runs}r, ${stat.balls}b)';
                  } else {
                    final stat = scoringState.bowlingScores[id];
                    if (stat != null) extraInfo = ' (${stat.wickets}w, ${stat.runs}r, ${stat.oversString} ov)';
                  }

                  return DropdownMenuItem<String>(
                    value: id,
                    child: Text(
                      '$name$extraInfo',
                      style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedOldPlayerId = val),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Dropdown 2: Correct Replacement Player
          Text(
            '3. Select Correct Player from Squad:',
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: AppColors.cardBackground,
                hint: Text('Select correct player', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted)),
                value: squadCandidates.any((p) => p.id == _selectedNewPlayerId) ? _selectedNewPlayerId : null,
                items: squadCandidates.map((player) {
                  return DropdownMenuItem<String>(
                    value: player.id,
                    child: Text(
                      '${player.name} (${player.role})',
                      style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedNewPlayerId = val),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Explanation Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.accentCyan, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All runs, balls, boundaries, and wickets will be transferred to the replacement player. Active batsman/bowler status will update immediately in live scoring and Firestore.',
                    style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Apply Correction Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSwappingPlayer ? null : () => _applyScorecardCorrection(playerNamesMap),
              icon: _isSwappingPlayer
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Icon(Icons.swap_horiz_rounded),
              label: Text(
                _isSwappingPlayer ? 'Applying Correction...' : 'APPLY SCORECARD CORRECTION',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
