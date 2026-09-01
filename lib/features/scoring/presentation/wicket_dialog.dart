import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/dismissal_helper.dart';
import '../models/ball_event.dart';
import '../models/player_model.dart';

class WicketDialog extends StatefulWidget {
  final PlayerModel striker;
  final PlayerModel nonStriker;
  final List<PlayerModel> availableNextBatsmen;
  final List<PlayerModel> bowlingSquad;
  final List<PlayerModel>? fieldingSquad; // All squad members of fielding team (Starters + Reserves)
  final Set<String>? playingVIIds; // Set of Playing VI IDs
  final PlayerModel currentBowler;
  final bool isLastPossibleWicket; // 6th dismissal = ALL OUT
  final BallContext initialBallContext;

  const WicketDialog({
    super.key,
    required this.striker,
    required this.nonStriker,
    required this.availableNextBatsmen,
    required this.bowlingSquad,
    this.fieldingSquad,
    this.playingVIIds,
    required this.currentBowler,
    required this.isLastPossibleWicket,
    this.initialBallContext = BallContext.normal,
  });

  @override
  State<WicketDialog> createState() => _WicketDialogState();
}

class _WicketDialogState extends State<WicketDialog> {
  late BallContext _ballContext;
  WicketType _selectedWicketType = WicketType.bowled;
  late String _outBatsmanId;
  String? _incomingBatsmanId;
  String? _selectedCatcherId;
  String? _selectedRunOutFielderId;
  String? _selectedStumperId;
  int _runsCompleted = 0; // For run outs

  @override
  void initState() {
    super.initState();
    _ballContext = widget.initialBallContext;
    _outBatsmanId = widget.striker.id;

    if (widget.availableNextBatsmen.isNotEmpty && !widget.isLastPossibleWicket) {
      _incomingBatsmanId = widget.availableNextBatsmen.first.id;
    }

    final fielders = _effectiveFieldingSquad;
    if (fielders.isNotEmpty) {
      // Default catcher to first fielder or bowler
      _selectedCatcherId = fielders.first.id;
      _selectedRunOutFielderId = fielders.first.id;

      // Find designated wicketkeeper if any
      final wk = fielders.where((p) => p.role.toUpperCase() == 'WICKET_KEEPER' || p.role.toLowerCase().contains('keeper')).firstOrNull;
      _selectedStumperId = wk?.id ?? fielders.first.id;
    }

    _syncWicketTypeWithContext();
  }

  List<PlayerModel> get _effectiveFieldingSquad =>
      (widget.fieldingSquad != null && widget.fieldingSquad!.isNotEmpty)
          ? widget.fieldingSquad!
          : widget.bowlingSquad;

  bool _isPlayerReserve(PlayerModel player) {
    if (widget.playingVIIds != null && widget.playingVIIds!.isNotEmpty) {
      return !widget.playingVIIds!.contains(player.id);
    }
    if (!player.isPlayingVI) return true;
    return player.designation?.toLowerCase().contains('reserve') ?? false;
  }

  void _syncWicketTypeWithContext() {
    final available = getAvailableDismissals(_ballContext);
    final currentLabel = _getWicketTypeLabel(_selectedWicketType);
    if (!available.contains(currentLabel)) {
      if (available.contains('Run Out')) {
        _selectedWicketType = _outBatsmanId == widget.striker.id
            ? WicketType.runOutStriker
            : WicketType.runOutNonStriker;
      } else if (available.contains('Stumped')) {
        _selectedWicketType = WicketType.stumped;
      } else if (available.isNotEmpty) {
        _selectedWicketType = _getWicketTypeFromLabel(available.first);
      }
    }
  }

  String _getWicketTypeLabel(WicketType type) {
    switch (type) {
      case WicketType.bowled:
        return 'Bowled';
      case WicketType.caught:
        return 'Caught';
      case WicketType.lbw:
        return 'LBW';
      case WicketType.stumped:
        return 'Stumped';
      case WicketType.hitWicket:
        return 'Hit Wicket';
      case WicketType.retiredHurt:
        return 'Retired Hurt';
      case WicketType.runOutStriker:
      case WicketType.runOutNonStriker:
        return 'Run Out';
    }
  }

  WicketType _getWicketTypeFromLabel(String label) {
    switch (label) {
      case 'Bowled':
        return WicketType.bowled;
      case 'Caught':
        return WicketType.caught;
      case 'LBW':
        return WicketType.lbw;
      case 'Stumped':
        return WicketType.stumped;
      case 'Hit Wicket':
        return WicketType.hitWicket;
      case 'Retired Hurt':
        return WicketType.retiredHurt;
      case 'Run Out':
      default:
        return _outBatsmanId == widget.striker.id
            ? WicketType.runOutStriker
            : WicketType.runOutNonStriker;
    }
  }

  PlayerModel? _findPlayer(String? id) {
    if (id == null) return null;
    try {
      return _effectiveFieldingSquad.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  String _buildDismissalDescription() {
    final bowlerName = widget.currentBowler.name;
    switch (_selectedWicketType) {
      case WicketType.bowled:
        return formatDismissalText(
          dismissalType: 'bowled',
          bowlerName: bowlerName,
        );

      case WicketType.caught:
        final isBowler = _selectedCatcherId == widget.currentBowler.id;
        final catcher = _findPlayer(_selectedCatcherId);
        return formatDismissalText(
          dismissalType: 'caught',
          bowlerName: bowlerName,
          catcherName: catcher?.name,
          isCaughtAndBowled: isBowler,
        );

      case WicketType.lbw:
        return formatDismissalText(
          dismissalType: 'lbw',
          bowlerName: bowlerName,
        );

      case WicketType.stumped:
        final stumper = _findPlayer(_selectedStumperId);
        return formatDismissalText(
          dismissalType: 'stumped',
          bowlerName: bowlerName,
          catcherName: stumper?.name,
        );

      case WicketType.runOutStriker:
      case WicketType.runOutNonStriker:
        final fielder = _findPlayer(_selectedRunOutFielderId);
        return formatDismissalText(
          dismissalType: 'run out',
          bowlerName: bowlerName,
          catcherName: fielder?.name,
        );

      case WicketType.hitWicket:
        return formatDismissalText(
          dismissalType: 'hit wicket',
          bowlerName: bowlerName,
        );

      case WicketType.retiredHurt:
        return formatDismissalText(
          dismissalType: 'retired hurt',
          bowlerName: bowlerName,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunOut = _selectedWicketType == WicketType.runOutStriker ||
        _selectedWicketType == WicketType.runOutNonStriker;
    final isCaught = _selectedWicketType == WicketType.caught;
    final isStumped = _selectedWicketType == WicketType.stumped;
    final availableDismissals = getAvailableDismissals(_ballContext);

    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.wicket.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cancel_rounded, color: AppColors.wicket, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FALL OF WICKET',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.isLastPossibleWicket
                            ? '6th Wicket - Team will be ALL OUT'
                            : 'Select dismissal method & incoming batsman',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: widget.isLastPossibleWicket ? AppColors.wicket : AppColors.textMuted,
                          fontWeight: widget.isLastPossibleWicket ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. Delivery Context Selector (Enforcing Cricket Laws)
            Text(
              'Delivery Context (Rules Enforcement):',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildContextChip(BallContext.normal, 'Normal Ball'),
                  const SizedBox(width: 6),
                  _buildContextChip(BallContext.noBall, 'No Ball (Nb+1)'),
                  const SizedBox(width: 6),
                  _buildContextChip(BallContext.wide, 'Wide (Wd+1)'),
                  const SizedBox(width: 6),
                  _buildContextChip(BallContext.bye, 'Bye'),
                  const SizedBox(width: 6),
                  _buildContextChip(BallContext.legBye, 'Leg Bye'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Select Out Batsman
            Text(
              'Batsman Dismissed:',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildBatsmanChoice(
                    player: widget.striker,
                    isStriker: true,
                    isSelected: _outBatsmanId == widget.striker.id,
                    onTap: () => setState(() {
                      _outBatsmanId = widget.striker.id;
                      if (_selectedWicketType == WicketType.runOutNonStriker) {
                        _selectedWicketType = WicketType.runOutStriker;
                      }
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildBatsmanChoice(
                    player: widget.nonStriker,
                    isStriker: false,
                    isSelected: _outBatsmanId == widget.nonStriker.id,
                    onTap: () => setState(() {
                      _outBatsmanId = widget.nonStriker.id;
                      if (_selectedWicketType != WicketType.runOutNonStriker &&
                          _selectedWicketType != WicketType.runOutStriker) {
                        _selectedWicketType = WicketType.runOutNonStriker;
                      }
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Dismissal Type Grid (Dynamically filtered by BallContext)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Method of Dismissal:',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                if (_ballContext != BallContext.normal)
                  Text(
                    'Enforcing ${_contextRulesNote(_ballContext)}',
                    style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.accent),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (availableDismissals.contains('Bowled'))
                  _buildWicketTypeChip(WicketType.bowled, 'Bowled'),
                if (availableDismissals.contains('Caught'))
                  _buildWicketTypeChip(WicketType.caught, 'Caught'),
                if (availableDismissals.contains('LBW'))
                  _buildWicketTypeChip(WicketType.lbw, 'LBW'),
                if (availableDismissals.contains('Stumped'))
                  _buildWicketTypeChip(WicketType.stumped, 'Stumped'),
                if (availableDismissals.contains('Hit Wicket'))
                  _buildWicketTypeChip(WicketType.hitWicket, 'Hit Wicket'),
                if (availableDismissals.contains('Run Out'))
                  _buildWicketTypeChip(
                    _outBatsmanId == widget.striker.id
                        ? WicketType.runOutStriker
                        : WicketType.runOutNonStriker,
                    'Run Out',
                  ),
                if (availableDismissals.contains('Retired Hurt'))
                  _buildWicketTypeChip(WicketType.retiredHurt, 'Retired Hurt'),
              ],
            ),
            const SizedBox(height: 16),

            // 4. Conditional: CAUGHT BY (Fielder dropdown)
            if (isCaught && _effectiveFieldingSquad.isNotEmpty) ...[
              Text(
                '🧤 Caught By (Catcher / Fielder):',
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
                    value: _selectedCatcherId ?? _effectiveFieldingSquad.first.id,
                    items: _effectiveFieldingSquad.map((player) {
                      final isBowler = player.id == widget.currentBowler.id;
                      final isWK = player.role.toUpperCase() == 'WICKET_KEEPER' || player.role.toLowerCase().contains('keeper');
                      final isReserve = _isPlayerReserve(player);

                      String label;
                      if (isBowler) {
                        label = '🎯 ${player.name} (Bowler — Caught & Bowled)';
                      } else if (isReserve) {
                        label = '🛡️ ${player.name} (Reserve Fielder)';
                      } else {
                        label = '🧤 ${player.name}${isWK ? " (WK)" : ""}';
                      }

                      return DropdownMenuItem<String>(
                        value: player.id,
                        child: Text(
                          label,
                          style: GoogleFonts.outfit(
                            color: isBowler
                                ? AppColors.accent
                                : (isReserve ? AppColors.accentCyan : AppColors.textPrimary),
                            fontWeight: (isBowler || isReserve) ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCatcherId = val),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 5. Conditional: STUMPED BY (Wicketkeeper dropdown)
            if (isStumped && _effectiveFieldingSquad.isNotEmpty) ...[
              Text(
                '🧤 Stumped By (Wicketkeeper / Fielder):',
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
                    value: _selectedStumperId ?? _effectiveFieldingSquad.first.id,
                    items: _effectiveFieldingSquad.map((player) {
                      final isWK = player.role.toUpperCase() == 'WICKET_KEEPER' || player.role.toLowerCase().contains('keeper');
                      final isReserve = _isPlayerReserve(player);

                      String label;
                      if (isWK) {
                        label = '🧤 ${player.name} (Wicketkeeper)';
                      } else if (isReserve) {
                        label = '🛡️ ${player.name} (Reserve Fielder)';
                      } else {
                        label = '🧤 ${player.name}';
                      }

                      return DropdownMenuItem<String>(
                        value: player.id,
                        child: Text(
                          label,
                          style: GoogleFonts.outfit(
                            color: isWK
                                ? AppColors.gold
                                : (isReserve ? AppColors.accentCyan : AppColors.textPrimary),
                            fontWeight: (isWK || isReserve) ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedStumperId = val),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 6. Conditional: RUN OUT (Fielder dropdown & Runs completed)
            if (isRunOut) ...[
              if (_effectiveFieldingSquad.isNotEmpty) ...[
                Text(
                  '🏃 Run Out By (Fielder / Thrower):',
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
                      value: _selectedRunOutFielderId ?? _effectiveFieldingSquad.first.id,
                      items: _effectiveFieldingSquad.map((player) {
                        final isBowler = player.id == widget.currentBowler.id;
                        final isReserve = _isPlayerReserve(player);

                        String label;
                        if (isBowler) {
                          label = '🎯 ${player.name} (Bowler)';
                        } else if (isReserve) {
                          label = '🛡️ ${player.name} (Reserve Fielder)';
                        } else {
                          label = '🏃 ${player.name}';
                        }

                        return DropdownMenuItem<String>(
                          value: player.id,
                          child: Text(
                            label,
                            style: GoogleFonts.outfit(
                              color: isReserve ? AppColors.accentCyan : AppColors.textPrimary,
                              fontWeight: isReserve ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedRunOutFielderId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'Runs completed before Run Out:',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (int i = 0; i <= 3; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Text('$i'),
                          selected: _runsCompleted == i,
                          selectedColor: AppColors.accent,
                          onSelected: (_) => setState(() => _runsCompleted = i),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // 7. Incoming Batsman Selector (If not last wicket / all out)
            if (!widget.isLastPossibleWicket && widget.availableNextBatsmen.isNotEmpty) ...[
              Text(
                widget.availableNextBatsmen.length == 1
                    ? 'Incoming Batsman (Last Man Standing):'
                    : 'Next Batsman to Crease:',
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
                    value: _incomingBatsmanId,
                    items: widget.availableNextBatsmen.map((player) {
                      return DropdownMenuItem<String>(
                        value: player.id,
                        child: Text(
                          '${player.name} (${player.role})',
                          style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _incomingBatsmanId = val),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 8. Live Scorecard Dismissal Preview Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.wicket.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.wicket.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_outlined, size: 16, color: AppColors.wicket),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scorecard: ${_buildDismissalDescription()}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('CANCEL', style: GoogleFonts.outfit(color: AppColors.textMuted)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.wicket,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      ExtraType extraType = ExtraType.none;
                      int extraRuns = 0;

                      if (_ballContext == BallContext.noBall) {
                        extraType = ExtraType.noBall;
                        extraRuns = 1;
                      } else if (_ballContext == BallContext.wide) {
                        extraType = ExtraType.wide;
                        extraRuns = 1;
                      } else if (_ballContext == BallContext.bye) {
                        extraType = ExtraType.bye;
                        extraRuns = 1;
                      } else if (_ballContext == BallContext.legBye) {
                        extraType = ExtraType.legBye;
                        extraRuns = 1;
                      }

                      final input = BallDeliveryInput(
                        runsOffBat: isRunOut ? _runsCompleted : 0,
                        extraType: extraType,
                        extraRuns: extraRuns,
                        isWicket: true,
                        wicketType: _selectedWicketType,
                        outBatsmanId: _outBatsmanId,
                        newBatsmanId: widget.isLastPossibleWicket ? null : _incomingBatsmanId,
                        dismissalDescription: _buildDismissalDescription(),
                      );
                      Navigator.pop(context, input);
                    },
                    child: Text(
                      'CONFIRM WICKET',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextChip(BallContext context, String label) {
    final isSelected = _ballContext == context;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.accent,
      side: BorderSide(color: isSelected ? AppColors.accent : Colors.white.withValues(alpha: 0.08)),
      onSelected: (_) {
        setState(() {
          _ballContext = context;
          _syncWicketTypeWithContext();
        });
      },
    );
  }

  String _contextRulesNote(BallContext ctx) {
    switch (ctx) {
      case BallContext.noBall:
        return 'No-Ball (Only Run Out)';
      case BallContext.freeHit:
        return 'Free Hit (Only Run Out)';
      case BallContext.wide:
        return 'Wide (Only Stumped / Run Out)';
      case BallContext.bye:
        return 'Bye (Only Run Out)';
      case BallContext.legBye:
        return 'Leg Bye (Only Run Out)';
      case BallContext.normal:
        return 'Standard Laws';
    }
  }

  Widget _buildBatsmanChoice({
    required PlayerModel player,
    required bool isStriker,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.wicket.withValues(alpha: 0.15) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.wicket : Colors.white.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isStriker ? Icons.sports_cricket : Icons.person_outline,
                  size: 14,
                  color: isSelected ? AppColors.wicket : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  isStriker ? 'STRIKER' : 'NON-STRIKER',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.wicket : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWicketTypeChip(WicketType type, String label) {
    final isSelected = _selectedWicketType == type;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.wicket.withValues(alpha: 0.25),
      side: BorderSide(color: isSelected ? AppColors.wicket : Colors.white.withValues(alpha: 0.08)),
      onSelected: (_) => setState(() => _selectedWicketType = type),
    );
  }
}
