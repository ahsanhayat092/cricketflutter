import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/presentation/login_screen.dart';
import '../../scoring/models/match_model.dart';
import '../../scoring/models/team_model.dart';
import '../../scoring/models/player_model.dart';
import '../../scoring/presentation/scorer_console_screen.dart';
import '../../scoring/presentation/opening_players_dialog.dart';
import '../providers/tournament_providers.dart';
import '../../standings/providers/standings_provider.dart';
import 'toss_modal.dart';
import 'widgets/quick_add_player_dialog.dart';

class MatchLineupScreen extends ConsumerStatefulWidget {
  final MatchModel match;

  const MatchLineupScreen({super.key, required this.match});

  @override
  ConsumerState<MatchLineupScreen> createState() => _MatchLineupScreenState();
}

class _MatchLineupScreenState extends ConsumerState<MatchLineupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late Set<String> _teamAPlayingVI;
  String? _teamAReserveId;

  late Set<String> _teamBPlayingVI;
  String? _teamBReserveId;

  String? _tossWinnerId;
  String? _tossDecision;
  bool _isStartingMatch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _teamAPlayingVI = Set.from(widget.match.teamAPlayingVI);
    _teamAReserveId = widget.match.teamAReserveId;

    _teamBPlayingVI = Set.from(widget.match.teamBPlayingVI);
    _teamBReserveId = widget.match.teamBReserveId;

    _tossWinnerId = widget.match.tossWinnerId;
    _tossDecision = widget.match.tossDecision;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _togglePlayer(String teamId, String teamAId, String playerId) {
    setState(() {
      final isTeamA = teamId == teamAId;
      final playingSet = isTeamA ? _teamAPlayingVI : _teamBPlayingVI;

      if (playingSet.contains(playerId)) {
        playingSet.remove(playerId);
      } else {
        if (playingSet.length < AppConstants.playingSquadSize) {
          playingSet.add(playerId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Playing VI already full (6 players max). Select Reserve below.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.cardBackground,
            ),
          );
        }
      }
    });
  }

  Future<void> _openTossModal(TeamModel teamA, TeamModel teamB) async {
    final TossResult? result = await showDialog<TossResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TossModal(teamA: teamA, teamB: teamB),
    );

    if (result != null) {
      setState(() {
        _tossWinnerId = result.winnerTeamId;
        _tossDecision = result.decision;
      });
    }
  }

  void _openQuickAddPlayerBottomSheet(TeamModel team) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickAddPlayerBottomSheet(
        teamId: team.id,
        teamName: team.name,
        onPlayerAdded: (newPlayerId) {
          setState(() {
            final isTeamA = team.id == widget.match.teamAId;
            final targetSet = isTeamA ? _teamAPlayingVI : _teamBPlayingVI;
            // Auto-select into playing VI if slots are available (< 6)
            if (targetSet.length < AppConstants.playingSquadSize) {
              targetSet.add(newPlayerId);
            }
          });
        },
      ),
    );
  }

  Future<void> _saveAndProceedToScoring(List<PlayerModel> teamAPlayers, List<PlayerModel> teamBPlayers) async {
    if (_teamAPlayingVI.length != AppConstants.playingSquadSize ||
        _teamBPlayingVI.length != AppConstants.playingSquadSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select exactly 6 Playing VI for BOTH teams.'),
          backgroundColor: AppColors.wicket,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_tossWinnerId == null || _tossDecision == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please conduct the Toss before starting the match.'),
          backgroundColor: AppColors.wicket,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final standingsAsync = ref.read(standingsStreamProvider);
    final standings = standingsAsync.value ?? [];
    final currentMatch = hydrateMatchWithStandings(widget.match, standings);

    final allTeams = ref.read(teamsProvider).value ?? [];
    final teamA = allTeams.firstWhere(
      (t) => t.id == currentMatch.teamAId,
      orElse: () => TeamModel(id: currentMatch.teamAId, name: 'Team A', shortName: 'TMA'),
    );
    final teamB = allTeams.firstWhere(
      (t) => t.id == currentMatch.teamBId,
      orElse: () => TeamModel(id: currentMatch.teamBId, name: 'Team B', shortName: 'TMB'),
    );

    // Determine batting & bowling teams based on toss
    final isTeamAWonToss = _tossWinnerId == teamA.id;
    final isBatFirst = _tossDecision?.toUpperCase() == 'BAT';

    final battingTeam = (isTeamAWonToss && isBatFirst) || (!isTeamAWonToss && !isBatFirst)
        ? teamA
        : teamB;
    final bowlingTeam = battingTeam.id == teamA.id ? teamB : teamA;

    final allPlayers = ref.read(playersProvider).value ?? [];
    final allKnownPlayers = [...teamAPlayers, ...teamBPlayers, ...allPlayers];
    final playerMap = {for (var p in allKnownPlayers) p.id: p};

    final isBattingTeamA = battingTeam.id == teamA.id;
    final battingSquadPlayers = (isBattingTeamA ? _teamAPlayingVI : _teamBPlayingVI)
        .map((id) => playerMap[id] ?? PlayerModel(id: id, teamId: battingTeam.id, name: 'Player $id'))
        .toList();
    final bowlingSquadPlayers = (!isBattingTeamA ? _teamAPlayingVI : _teamBPlayingVI)
        .map((id) => playerMap[id] ?? PlayerModel(id: id, teamId: bowlingTeam.id, name: 'Player $id'))
        .toList();

    // Prompt user to select opening striker, non-striker, and opening bowler
    final openingResult = await showDialog<OpeningPlayersResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OpeningPlayersDialog(
        title: 'START 1ST INNINGS',
        battingTeam: battingTeam,
        bowlingTeam: bowlingTeam,
        battingSquad: battingSquadPlayers,
        bowlingSquad: bowlingSquadPlayers,
      ),
    );

    if (openingResult == null) return; // User cancelled

    setState(() => _isStartingMatch = true);

    try {
      final syncService = ref.read(scoringSyncServiceProvider);

      await syncService.startMatch(
        matchId: currentMatch.id,
        teamAId: currentMatch.teamAId,
        teamBId: currentMatch.teamBId,
        teamAPlayingVI: _teamAPlayingVI.toList(),
        teamAReserveId: _teamAReserveId,
        teamBPlayingVI: _teamBPlayingVI.toList(),
        teamBReserveId: _teamBReserveId,
        tossWinnerId: _tossWinnerId!,
        tossDecision: _tossDecision!,
        battingTeamId: battingTeam.id,
        bowlingTeamId: bowlingTeam.id,
        strikerId: openingResult.strikerId,
        nonStrikerId: openingResult.nonStrikerId,
        bowlerId: openingResult.bowlerId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Match started successfully in Firebase!'),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ScorerConsoleScreen(matchId: widget.match.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting match: $e'),
            backgroundColor: AppColors.wicket,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingMatch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (!user.canScore) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'RESTRICTED ACCESS',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.wicket.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.wicket, width: 2),
                  ),
                  child: const Icon(Icons.lock_rounded, size: 40, color: AppColors.wicket),
                ),
                const SizedBox(height: 20),
                Text(
                  'Match Official Login Required',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only authenticated tournament scorers and admins can select playing VI, conduct the toss, and launch matches.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.login_rounded),
                  label: Text('SIGN IN AS OFFICIAL', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Back to Fixtures',
                    style: GoogleFonts.outfit(color: AppColors.accentCyan, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final standingsAsync = ref.watch(standingsStreamProvider);
    final standings = standingsAsync.value ?? [];
    final currentMatch = hydrateMatchWithStandings(widget.match, standings);

    final allTeams = ref.watch(teamsProvider).value ?? [];
    final teamA = allTeams.firstWhere(
      (t) => t.id == currentMatch.teamAId,
      orElse: () => TeamModel(id: currentMatch.teamAId, name: 'Team A', shortName: 'TMA'),
    );
    final teamB = allTeams.firstWhere(
      (t) => t.id == currentMatch.teamBId,
      orElse: () => TeamModel(id: currentMatch.teamBId, name: 'Team B', shortName: 'TMB'),
    );

    // Dedicated reactive streams for both teams
    final teamAPlayersAsync = ref.watch(teamPlayersStreamProvider(teamA.id));
    final teamBPlayersAsync = ref.watch(teamPlayersStreamProvider(teamB.id));

    final teamAPlayers = teamAPlayersAsync.value ?? [];
    final teamBPlayers = teamBPlayersAsync.value ?? [];

    // Auto-fill squads once loaded if not set yet
    if (_teamAPlayingVI.isEmpty && teamAPlayers.isNotEmpty) {
      _teamAPlayingVI = teamAPlayers.take(6).map((p) => p.id).toSet();
      if (teamAPlayers.length > 6) _teamAReserveId = teamAPlayers[6].id;
    }
    if (_teamBPlayingVI.isEmpty && teamBPlayers.isNotEmpty) {
      _teamBPlayingVI = teamBPlayers.take(6).map((p) => p.id).toSet();
      if (teamBPlayers.length > 6) _teamBReserveId = teamBPlayers[6].id;
    }

    final isTeamAReady = _teamAPlayingVI.length == AppConstants.playingSquadSize;
    final isTeamBReady = _teamBPlayingVI.length == AppConstants.playingSquadSize;
    final isTossReady = _tossWinnerId != null && _tossDecision != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('LINEUP & TOSS • MATCH #${widget.match.matchNumber}'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: '${teamA.shortName} (${_teamAPlayingVI.length}/6)'),
            Tab(text: '${teamB.shortName} (${_teamBPlayingVI.length}/6)'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Toss Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.cardBackground,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOSS STATUS',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                    ),
                    Text(
                      isTossReady
                          ? '${_tossWinnerId == teamA.id ? teamA.shortName : teamB.shortName} won & elected to $_tossDecision'
                          : 'Toss Pending',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isTossReady ? AppColors.gold : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.monetization_on, size: 16),
                  label: Text(isTossReady ? 'Change Toss' : 'Conduct Toss'),
                  onPressed: () => _openTossModal(teamA, teamB),
                ),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSquadTab(teamA, teamAPlayersAsync, _teamAPlayingVI, _teamAReserveId, teamA.id, (resId) {
                  setState(() => _teamAReserveId = resId);
                }),
                _buildSquadTab(teamB, teamBPlayersAsync, _teamBPlayingVI, _teamBReserveId, teamA.id, (resId) {
                  setState(() => _teamBReserveId = resId);
                }),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: (isTeamAReady && isTeamBReady && isTossReady)
                    ? AppColors.accent
                    : AppColors.surfaceLight,
                foregroundColor: (isTeamAReady && isTeamBReady && isTossReady)
                    ? Colors.black
                    : AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: (_isStartingMatch || !(isTeamAReady && isTeamBReady && isTossReady))
                  ? null
                  : () => _saveAndProceedToScoring(teamAPlayers, teamBPlayers),
              child: _isStartingMatch
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      'START MATCH & SCORE LIVE',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquadTab(
    TeamModel team,
    AsyncValue<List<PlayerModel>> playersAsync,
    Set<String> playingVI,
    String? reserveId,
    String teamAId,
    ValueChanged<String?> onReserveChanged,
  ) {
    return playersAsync.when(
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 16),
            Text(
              'Loading players for ${team.name} from Firebase...',
              style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 42, color: AppColors.wicket),
              const SizedBox(height: 12),
              Text(
                'Could not load players for ${team.name}',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text('$err', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
                icon: const Icon(Icons.refresh),
                label: const Text('RETRY'),
                onPressed: () => ref.invalidate(teamPlayersStreamProvider(team.id)),
              ),
            ],
          ),
        ),
      ),
      data: (players) {
        if (players.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_off_rounded, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 14),
                  Text(
                    'No players found for ${team.name} in Firebase',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Please add players to the /players collection with teamId: "${team.id}" in Firestore.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('ADD PLAYER'),
                        onPressed: () => _openQuickAddPlayerBottomSheet(team),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        style: ElevatedButton.styleFrom(foregroundColor: AppColors.textPrimary),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                        onPressed: () => ref.invalidate(teamPlayersStreamProvider(team.id)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Playing VI Section Header with "+ Add Player" Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECT STARTING 6 (PLAYING VI)',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.accent),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${playingVI.length} / 6 Starters Selected',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: playingVI.length == 6 ? AppColors.accent : AppColors.wicket,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => _openQuickAddPlayerBottomSheet(team),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                  label: Text('Add Player', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ...players.map((player) {
              final isSelected = playingVI.contains(player.id);
              final isReserve = reserveId == player.id;

              return Card(
                color: isSelected
                    ? AppColors.accent.withValues(alpha: 0.12)
                    : (isReserve ? AppColors.accentCyan.withValues(alpha: 0.08) : AppColors.cardBackground),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.accent
                        : (isReserve ? AppColors.accentCyan : Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: isSelected ? AppColors.accent : AppColors.surfaceLight,
                    child: Text(
                      '${player.jerseyNumber ?? player.name[0]}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.black : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  title: Text(
                    player.name,
                    style: GoogleFonts.outfit(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '${player.role}${player.designation != null ? " • ${player.designation}" : ""}',
                    style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
                  ),
                  trailing: Checkbox(
                    value: isSelected,
                    activeColor: AppColors.accent,
                    checkColor: Colors.black,
                    onChanged: isReserve ? null : (_) => _togglePlayer(team.id, teamAId, player.id),
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // Reserve Player Selector
            Text(
              'RESERVE PLAYER (1 PLAYER)',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.accentCyan),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  dropdownColor: AppColors.cardBackground,
                  value: reserveId,
                  hint: Text('Select 1 Reserve Player', style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13)),
                  items: players.where((p) => !playingVI.contains(p.id)).map((p) {
                    return DropdownMenuItem<String>(
                      value: p.id,
                      child: Text('${p.name} (${p.role})', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) => onReserveChanged(val),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
