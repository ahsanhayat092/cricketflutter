import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/cricket_calculator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/presentation/login_screen.dart';
import '../models/ball_event.dart';
import '../models/player_model.dart';
import '../models/innings_model.dart';
import '../models/match_model.dart';
import '../models/team_model.dart';
import '../models/batting_score.dart';
import '../models/bowling_score.dart';
import '../providers/scoring_controller.dart';
import '../../match_management/providers/tournament_providers.dart';
import 'wicket_dialog.dart';
import 'bowler_select_dialog.dart';
import 'no_ball_dialog.dart';
import 'opening_players_dialog.dart';

class ScorerConsoleScreen extends ConsumerStatefulWidget {
  final String matchId;

  const ScorerConsoleScreen({super.key, required this.matchId});

  @override
  ConsumerState<ScorerConsoleScreen> createState() => _ScorerConsoleScreenState();
}

class _ScorerConsoleScreenState extends ConsumerState<ScorerConsoleScreen> {
  bool _isBowlerModalOpen = false;

  @override
  void initState() {
    super.initState();
    // Keep screen awake while scoring matches
    try {
      WakelockPlus.enable();
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      WakelockPlus.disable();
    } catch (_) {}
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.mediumImpact();
  }

  void _onBallTapped(int runs) {
    _triggerHaptic();
    ref.read(liveScoringControllerProvider(widget.matchId).notifier).recordDelivery(
          BallDeliveryInput(runsOffBat: runs),
        );
  }

  void _onExtraTapped(ExtraType type, int extraRuns) {
    _triggerHaptic();
    ref.read(liveScoringControllerProvider(widget.matchId).notifier).recordDelivery(
          BallDeliveryInput(
            extraType: type,
            extraRuns: extraRuns,
          ),
        );
  }

  Future<void> _openNoBallModal() async {
    _triggerHaptic();
    final BallDeliveryInput? input = await showDialog<BallDeliveryInput>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const NoBallDialog(),
    );

    if (input != null) {
      await ref
          .read(liveScoringControllerProvider(widget.matchId).notifier)
          .recordDelivery(input);
    }
  }

  Future<void> _openWideModal() async {
    _triggerHaptic();
    final int? wideRuns = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'SELECT WIDE RUNS',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Standard wide gives 1 extra run without consuming legal balls.',
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildWideOption(ctx, 1, 'WD +1 (Standard)'),
                const SizedBox(width: 8),
                _buildWideOption(ctx, 2, 'WD +2 (1 Extra+1 Run)'),
                const SizedBox(width: 8),
                _buildWideOption(ctx, 5, 'WD +5 (Wide + 4s)'),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (wideRuns != null) {
      _onExtraTapped(ExtraType.wide, wideRuns);
    }
  }

  Widget _buildWideOption(BuildContext ctx, int runs, String label) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceLight,
          foregroundColor: AppColors.accent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => Navigator.pop(ctx, runs),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _openPenaltyModal() async {
    _triggerHaptic();
    int penalty = 5;
    final int? selectedPenalty = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text('AWARD PENALTY RUNS', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Award penalty runs to batting team (e.g. ball hitting helmet):', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final p in [1, 2, 5])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('+$p Runs'),
                        selected: penalty == p,
                        selectedColor: AppColors.accent,
                        onSelected: (_) => setLocal(() => penalty = p),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(ctx, penalty),
              child: const Text('AWARD'),
            ),
          ],
        ),
      ),
    );

    if (selectedPenalty != null) {
      _onExtraTapped(ExtraType.penalty, selectedPenalty);
    }
  }

  Future<void> _openWicketModal(
    PlayerModel striker,
    PlayerModel nonStriker,
    List<PlayerModel> battingSquad,
    PlayerModel currentBowler,
    int currentWickets,
  ) async {
    _triggerHaptic();
    final usedPlayerIds = ref
        .read(liveScoringControllerProvider(widget.matchId))
        .battingScores
        .keys
        .toSet();

    final unbattedPlayers =
        battingSquad.where((p) => !usedPlayerIds.contains(p.id)).toList();

    final isLastWicket = (currentWickets + 1) >= AppConstants.maxWicketsPerInnings;

    final BallDeliveryInput? input = await showDialog<BallDeliveryInput>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WicketDialog(
        striker: striker,
        nonStriker: nonStriker,
        availableNextBatsmen: unbattedPlayers,
        currentBowler: currentBowler,
        isLastPossibleWicket: isLastWicket,
      ),
    );

    if (input != null) {
      await ref
          .read(liveScoringControllerProvider(widget.matchId).notifier)
          .recordDelivery(input);
    }
  }

  Future<void> _openBowlerSelectModal(
    List<PlayerModel> bowlingSquad,
    String? previousBowlerId,
    bool isFinalMatch,
  ) async {
    final currentState = ref.read(liveScoringControllerProvider(widget.matchId));
    final isMidOver = currentState.innings.balls > 0 && (currentState.innings.balls % 6 != 0);

    // Guard: Bowler cannot be changed mid-over once an over is underway
    if (isMidOver && currentState.currentBowlerId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bowler cannot be changed mid-over. Complete all 6 legal balls first.'),
          backgroundColor: AppColors.wicket,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isBowlerModalOpen) return;
    _isBowlerModalOpen = true;

    try {
      final state = ref.read(liveScoringControllerProvider(widget.matchId));
      final String? selectedBowlerId = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => BowlerSelectDialog(
          bowlingSquad: bowlingSquad,
          previousBowlerId: previousBowlerId,
          isFinalMatch: isFinalMatch,
          bowlingScores: state.bowlingScores,
        ),
      );

      if (selectedBowlerId != null && mounted) {
        ref
            .read(liveScoringControllerProvider(widget.matchId).notifier)
            .setCurrentBowler(selectedBowlerId);
      }
    } finally {
      _isBowlerModalOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    // Security check: Only official scorer or tournament admin can score
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
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 40,
                    color: AppColors.wicket,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Scorer Login Required',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only registered match officials and scorers can input ball-by-ball deliveries. Public viewers can watch live scores from the Live Match screen.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
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
                  label: Text(
                    'SIGN IN AS SCORER',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
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
                    'Return to Live Match View',
                    style: GoogleFonts.outfit(
                      color: AppColors.accentCyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final scoringState = ref.watch(liveScoringControllerProvider(widget.matchId));

    if (scoringState.isLoading && scoringState.match.teamAId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'LOADING SCORER...',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(height: 16),
              Text(
                'Connecting to live match scoring...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final allPlayers = ref.watch(playersProvider).value ?? [];
    final match = scoringState.match;
    final innings = scoringState.innings;

    // Helper map of players
    final playerMap = {for (var p in allPlayers) p.id: p};

    final allTeams = ref.watch(teamsProvider).value ?? [];
    final teamMap = {for (var t in allTeams) t.id: t};

    final battingTeam = teamMap[innings.battingTeamId] ??
        TeamModel(id: innings.battingTeamId, name: 'Batting Team', shortName: 'BAT');
    final bowlingTeam = teamMap[innings.bowlingTeamId] ??
        TeamModel(id: innings.bowlingTeamId, name: 'Bowling Team', shortName: 'BWL');

    final isInningsFinished = innings.completed || match.isCompleted || scoringState.isLocked;
    final isNoBowlerActive = scoringState.currentBowlerId == null && !isInningsFinished;
    final canChangeOpeners = innings.balls == 0 && innings.runs == 0 && innings.wickets == 0 && !isInningsFinished;

    final battingSquad = innings.battingTeamId == match.teamAId
        ? match.teamAPlayingVI.map((id) => playerMap[id] ?? PlayerModel(id: id, teamId: '', name: 'Player $id')).toList()
        : match.teamBPlayingVI.map((id) => playerMap[id] ?? PlayerModel(id: id, teamId: '', name: 'Player $id')).toList();

    final bowlingSquad = innings.bowlingTeamId == match.teamAId
        ? match.teamAPlayingVI.map((id) => playerMap[id] ?? PlayerModel(id: id, teamId: '', name: 'Bowler $id')).toList()
        : match.teamBPlayingVI.map((id) => playerMap[id] ?? PlayerModel(id: id, teamId: '', name: 'Bowler $id')).toList();

    final striker = scoringState.strikerId != null
        ? playerMap[scoringState.strikerId] ?? PlayerModel(id: scoringState.strikerId!, teamId: '', name: 'Striker')
        : (battingSquad.isNotEmpty ? battingSquad[0] : const PlayerModel(id: 's1', teamId: '', name: 'Striker'));

    final nonStriker = scoringState.nonStrikerId != null
        ? playerMap[scoringState.nonStrikerId] ?? PlayerModel(id: scoringState.nonStrikerId!, teamId: '', name: 'Non-Striker')
        : (battingSquad.length > 1 ? battingSquad[1] : const PlayerModel(id: 's2', teamId: '', name: 'Non-Striker'));

    final bowler = scoringState.currentBowlerId != null
        ? playerMap[scoringState.currentBowlerId] ?? PlayerModel(id: scoringState.currentBowlerId!, teamId: '', name: 'Bowler')
        : null;

    // Check if bowler needs selection at end of over or if sync error occurs
    ref.listen<ScoringState>(liveScoringControllerProvider(widget.matchId), (prev, current) {
      final isFinished = current.isLocked || current.innings.completed || current.match.isCompleted;
      final justTriggered = prev?.isNeedBowlerSelection != true && current.isNeedBowlerSelection == true;
      final bowlerBecameNull = prev?.currentBowlerId != null && current.currentBowlerId == null;

      if ((justTriggered || bowlerBecameNull) && current.currentBowlerId == null && !isFinished) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isBowlerModalOpen) {
            _openBowlerSelectModal(bowlingSquad, current.previousBowlerId, match.isFinal);
          }
        });
      }
      if (current.lastSyncError != null && current.lastSyncError != prev?.lastSyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firebase Sync Error: ${current.lastSyncError}'),
            backgroundColor: AppColors.wicket,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    final strikerScore = scoringState.battingScores[striker.id];
    final nonStrikerScore = scoringState.battingScores[nonStriker.id];
    final bowlerScore = bowler != null ? scoringState.bowlingScores[bowler.id] : null;

    final isChasing = innings.inningsNumber == 2 && scoringState.firstInningsTotalRuns != null;
    final target = isChasing ? scoringState.firstInningsTotalRuns! + 1 : null;

    final runsNeeded = (isChasing && target != null) ? (target - innings.runs) : null;
    final ballsRemaining = match.maxBalls - innings.balls;
    final rrr = (runsNeeded != null) ? CricketCalculator.calculateRRR(runsNeeded, ballsRemaining) : null;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'SCORER CONSOLE • INN ${innings.inningsNumber}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(width: 8),
            if (scoringState.isSyncing)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent),
              )
            else if (scoringState.lastSyncError != null)
              const Tooltip(
                message: 'Firestore Sync Error',
                child: Icon(Icons.cloud_off_rounded, color: AppColors.wicket, size: 16),
              )
            else
              const Tooltip(
                message: 'Synced to Firebase',
                child: Icon(Icons.cloud_done_rounded, color: AppColors.accent, size: 16),
              ),
          ],
        ),
        actions: [
          // Swap Striker button
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: AppColors.accentCyan),
            tooltip: 'Swap Strike',
            onPressed: isInningsFinished
                ? null
                : () {
                    _triggerHaptic();
                    ref.read(liveScoringControllerProvider(widget.matchId).notifier).swapStriker();
                  },
          ),
          // Undo Button
          IconButton(
            icon: Icon(
              Icons.undo_rounded,
              color: scoringState.canUndo ? AppColors.gold : AppColors.textMuted,
            ),
            tooltip: 'Undo Last Ball',
            onPressed: scoringState.canUndo
                ? () {
                    _triggerHaptic();
                    ref.read(liveScoringControllerProvider(widget.matchId).notifier).undoLastDelivery();
                  }
                : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Scoreboard Bar with CRR, RRR, Target Equation
            _buildScoreBanner(innings, match, isChasing, target, rrr),

            // 2. Recent Deliveries Strip
            _buildRecentDeliveries(innings.recentBalls),

            // 3. Middle Area: Batsmen & Bowler Cards
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    _buildBatsmenSection(
                      striker,
                      nonStriker,
                      strikerScore,
                      nonStrikerScore,
                      battingSquad,
                      bowlingSquad,
                      battingTeam,
                      bowlingTeam,
                      canChangeOpeners,
                    ),
                    const SizedBox(height: 10),
                    _buildBowlerSection(
                      bowler,
                      bowlerScore,
                      bowlingSquad,
                      scoringState.previousBowlerId,
                      match.isFinal,
                      isNoBowlerActive,
                      innings.balls,
                      isInningsFinished,
                    ),
                    if (isInningsFinished) ...[
                      const SizedBox(height: 16),
                      _buildInningsFinishedCard(innings, match, scoringState),
                    ],
                  ],
                ),
              ),
            ),

            // 4. Bottom Scoring Keypad (Disabled if locked or no bowler selected)
            _buildKeypad(
              striker,
              nonStriker,
              battingSquad,
              bowler,
              innings.wickets,
              isInningsFinished || scoringState.currentBowlerId == null,
              isNoBowlerActive,
              bowlingSquad,
              scoringState.previousBowlerId,
              match.isFinal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBanner(InningsModel innings, MatchModel match, bool isChasing, int? target, double? rrr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Total Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${innings.runs}/${innings.wickets}',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${innings.oversString}/${match.maxOvers}.0 ov)',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (isChasing && target != null)
                Text(
                  CricketCalculator.targetEquation(
                    target: target,
                    currentRuns: innings.runs,
                    maxBalls: match.maxBalls,
                    ballsBowled: innings.balls,
                  ),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.accentCyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),

          // Rates & Extras
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'CRR: ${innings.crr.toStringAsFixed(2)}${rrr != null ? " • RRR: ${rrr.toStringAsFixed(2)}" : ""}',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
              Text(
                'Extras: ${innings.totalExtras} (Wd ${innings.wides}, Nb ${innings.noBalls})',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDeliveries(List<String> recentBalls) {
    final displayedBalls = recentBalls.reversed.toList();
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.background,
      child: Row(
        children: [
          Text(
            'THIS OVER:',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: displayedBalls.isEmpty
                ? Text('No balls bowled yet', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: displayedBalls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final ball = displayedBalls[index];
                      final color = AppColors.getDeliveryColor(ball);
                      return Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          border: Border.all(color: color, width: 1.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            ball,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

   Widget _buildBatsmenSection(
    PlayerModel striker,
    PlayerModel nonStriker,
    BattingScore? strikerScore,
    BattingScore? nonStrikerScore,
    List<PlayerModel> battingSquad,
    List<PlayerModel> bowlingSquad,
    TeamModel battingTeam,
    TeamModel bowlingTeam,
    bool canChangeOpeners,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          if (canChangeOpeners)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'OPENING BATSMEN',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      final res = await showDialog<OpeningPlayersResult>(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => OpeningPlayersDialog(
                          title: 'CHANGE OPENERS & BOWLER',
                          battingTeam: battingTeam,
                          bowlingTeam: bowlingTeam,
                          battingSquad: battingSquad,
                          bowlingSquad: bowlingSquad,
                          initialStrikerId: striker.id,
                          initialNonStrikerId: nonStriker.id,
                        ),
                      );
                      if (res != null) {
                        ref.read(liveScoringControllerProvider(widget.matchId).notifier).setOpeners(
                              strikerId: res.strikerId,
                              nonStrikerId: res.nonStrikerId,
                              bowlerId: res.bowlerId,
                            );
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_rounded, size: 13, color: AppColors.accentCyan),
                          const SizedBox(width: 4),
                          Text(
                            'Change Openers',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentCyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildBatsmanRow(striker, strikerScore, isStriker: true),
          const Divider(height: 1, color: Colors.white10),
          _buildBatsmanRow(nonStriker, nonStrikerScore, isStriker: false),
        ],
      ),
    );
  }

  Widget _buildBatsmanRow(PlayerModel player, BattingScore? score, {required bool isStriker}) {
    final runs = score?.runs ?? 0;
    final balls = score?.balls ?? 0;
    final fours = score?.fours ?? 0;
    final sixes = score?.sixes ?? 0;
    final sr = score?.strikeRate ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          if (isStriker)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sports_cricket, size: 12, color: Colors.black),
            )
          else
            const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: isStriker ? FontWeight.bold : FontWeight.w600,
                    color: isStriker ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                Text(
                  '4s: $fours • 6s: $sixes • SR: ${sr.toStringAsFixed(1)}',
                  style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            '$runs',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isStriker ? AppColors.accent : AppColors.textPrimary,
            ),
          ),
          Text(
            ' ($balls)',
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildBowlerSection(
    PlayerModel? bowler,
    BowlingScore? bowlerScore,
    List<PlayerModel> bowlingSquad,
    String? previousBowlerId,
    bool isFinalMatch,
    bool isNoBowlerActive,
    int currentBalls,
    bool isInningsFinished,
  ) {
    final runs = bowlerScore?.runs ?? 0;
    final overs = bowlerScore?.oversString ?? '0.0';
    final wickets = bowlerScore?.wickets ?? 0;
    final economy = bowlerScore?.economy ?? 0.0;
    final maidens = bowlerScore?.maidens ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNoBowlerActive ? AppColors.accent : Colors.white.withValues(alpha: 0.08),
          width: isNoBowlerActive ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sports_baseball, size: 12, color: Colors.black),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bowler?.name ?? 'No Bowler Selected',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: bowler != null ? AppColors.textPrimary : AppColors.accent,
                      ),
                    ),
                    if (bowler != null)
                      Text(
                        'O: $overs • M: $maidens • R: $runs • W: $wickets • Econ: ${economy.toStringAsFixed(1)}',
                        style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
                      )
                    else
                      Text(
                        'Select bowler to unlock keypad scoring',
                        style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              if (!isInningsFinished)
                if (currentBalls > 0 && currentBalls % 6 != 0 && bowler != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Mid-Over',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isNoBowlerActive ? AppColors.accent : AppColors.surfaceLight,
                      foregroundColor: isNoBowlerActive ? Colors.black : AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _openBowlerSelectModal(bowlingSquad, previousBowlerId, isFinalMatch),
                    child: Text(
                      bowler == null ? 'SELECT' : 'CHANGE',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInningsFinishedCard(InningsModel innings, MatchModel match, ScoringState state) {
    final isFirstInnings = innings.inningsNumber == 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent),
      ),
      child: Column(
        children: [
          Text(
            isFirstInnings ? '🏁 1ST INNINGS COMPLETED' : '🏆 MATCH COMPLETED',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFirstInnings
                ? 'Target for 2nd Innings: ${innings.runs + 1} runs (${match.maxOvers}.0 overs)'
                : (match.resultText ?? 'Match Finished'),
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (isFirstInnings) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
              onPressed: () async {
                final allTeams = ref.read(teamsProvider).value ?? [];
                final teamMap = {for (var t in allTeams) t.id: t};
                final allPlayers = ref.read(playersProvider).value ?? [];
                final playerMap = {for (var p in allPlayers) p.id: p};

                final nextBattingTeamId = innings.bowlingTeamId;
                final nextBowlingTeamId = innings.battingTeamId;

                final nextBattingTeam = teamMap[nextBattingTeamId] ??
                    TeamModel(id: nextBattingTeamId, name: 'Batting Team', shortName: 'BAT');
                final nextBowlingTeam = teamMap[nextBowlingTeamId] ??
                    TeamModel(id: nextBowlingTeamId, name: 'Bowling Team', shortName: 'BWL');

                final nextBattingSquadIds = nextBattingTeamId == match.teamAId ? match.teamAPlayingVI : match.teamBPlayingVI;
                final nextBowlingSquadIds = nextBowlingTeamId == match.teamAId ? match.teamAPlayingVI : match.teamBPlayingVI;

                final nextBattingSquad = nextBattingSquadIds
                    .map((id) => playerMap[id] ?? PlayerModel(id: id, teamId: nextBattingTeamId, name: 'Player $id'))
                    .toList();
                final nextBowlingSquad = nextBowlingSquadIds
                    .map((id) => playerMap[id] ?? PlayerModel(id: id, teamId: nextBowlingTeamId, name: 'Player $id'))
                    .toList();

                final openingResult = await showDialog<OpeningPlayersResult>(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => OpeningPlayersDialog(
                    title: 'START 2ND INNINGS',
                    battingTeam: nextBattingTeam,
                    bowlingTeam: nextBowlingTeam,
                    battingSquad: nextBattingSquad,
                    bowlingSquad: nextBowlingSquad,
                  ),
                );

                if (openingResult == null) return;

                ref.read(liveScoringControllerProvider(widget.matchId).notifier).startSecondInnings(
                      battingTeamId: nextBattingTeamId,
                      bowlingTeamId: nextBowlingTeamId,
                      strikerId: openingResult.strikerId,
                      nonStrikerId: openingResult.nonStrikerId,
                      bowlerId: openingResult.bowlerId,
                    );
              },
              child: const Text('START 2ND INNINGS'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKeypad(
    PlayerModel striker,
    PlayerModel nonStriker,
    List<PlayerModel> battingSquad,
    PlayerModel? currentBowler,
    int currentWickets,
    bool isLocked,
    bool isNoBowlerSelected,
    List<PlayerModel> bowlingSquad,
    String? previousBowlerId,
    bool isFinalMatch,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mandatory Next Bowler Prompt Banner if Bowler unselected
          if (isNoBowlerSelected) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sports_baseball, color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Over completed! Select next bowler to continue.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () => _openBowlerSelectModal(bowlingSquad, previousBowlerId, isFinalMatch),
                    child: Text(
                      'SELECT',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Extras Bar (WD, NB, BYE, LB, PENALTY)
          Row(
            children: [
              _buildExtraBtn('WD', _openWideModal, isLocked),
              const SizedBox(width: 6),
              _buildExtraBtn('NB', _openNoBallModal, isLocked),
              const SizedBox(width: 6),
              _buildExtraBtn('BYE +1', () => _onExtraTapped(ExtraType.bye, 1), isLocked),
              const SizedBox(width: 6),
              _buildExtraBtn('LB +1', () => _onExtraTapped(ExtraType.legBye, 1), isLocked),
              const SizedBox(width: 6),
              _buildExtraBtn('PENALTY', _openPenaltyModal, isLocked),
            ],
          ),
          const SizedBox(height: 10),

          // Quick-tap Scoring Keypad (0, 1, 2, 3, 4, 6, WICKET)
          Row(
            children: [
              _buildRunBtn('0', 0, isLocked),
              const SizedBox(width: 8),
              _buildRunBtn('1', 1, isLocked),
              const SizedBox(width: 8),
              _buildRunBtn('2', 2, isLocked),
              const SizedBox(width: 8),
              _buildRunBtn('3', 3, isLocked),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildBoundaryBtn('4 (FOUR)', 4, AppColors.fourRuns, isLocked),
              const SizedBox(width: 8),
              _buildBoundaryBtn('6 (SIX)', 6, AppColors.sixRuns, isLocked),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLocked ? AppColors.surfaceLight : AppColors.wicket,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isLocked
                      ? null
                      : () {
                          if (currentBowler == null) {
                            _openBowlerSelectModal(bowlingSquad, previousBowlerId, isFinalMatch);
                            return;
                          }
                          _openWicketModal(
                            striker,
                            nonStriker,
                            battingSquad,
                            currentBowler,
                            currentWickets,
                          );
                        },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cancel_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text('WICKET', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRunBtn(String label, int runs, bool isLocked) {
    return Expanded(
      child: Material(
        color: isLocked ? AppColors.surfaceLight : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isLocked ? null : () => _onBallTapped(runs),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isLocked ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoundaryBtn(String label, int runs, Color color, bool isLocked) {
    return Expanded(
      flex: 2,
      child: Material(
        color: isLocked ? AppColors.surfaceLight : color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isLocked ? null : () => _onBallTapped(runs),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLocked ? Colors.transparent : color,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: isLocked ? AppColors.textMuted : color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtraBtn(String label, VoidCallback onTap, bool isLocked) {
    return Expanded(
      child: Material(
        color: isLocked ? AppColors.surfaceLight : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: isLocked ? null : onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isLocked ? AppColors.textMuted : AppColors.accentCyan,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
