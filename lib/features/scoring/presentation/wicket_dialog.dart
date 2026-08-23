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
  final PlayerModel currentBowler;
  final bool isLastPossibleWicket; // 5th dismissal = ALL OUT

  const WicketDialog({
    super.key,
    required this.striker,
    required this.nonStriker,
    required this.availableNextBatsmen,
    required this.bowlingSquad,
    required this.currentBowler,
    required this.isLastPossibleWicket,
  });

  @override
  State<WicketDialog> createState() => _WicketDialogState();
}

class _WicketDialogState extends State<WicketDialog> {
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
    _outBatsmanId = widget.striker.id;

    if (widget.availableNextBatsmen.isNotEmpty && !widget.isLastPossibleWicket) {
      _incomingBatsmanId = widget.availableNextBatsmen.first.id;
    }

    if (widget.bowlingSquad.isNotEmpty) {
      // Default catcher to first fielder or bowler
      _selectedCatcherId = widget.bowlingSquad.first.id;
      _selectedRunOutFielderId = widget.bowlingSquad.first.id;

      // Find designated wicketkeeper if any
      final wk = widget.bowlingSquad.where((p) => p.role.toUpperCase() == 'WICKET_KEEPER').firstOrNull;
      _selectedStumperId = wk?.id ?? widget.bowlingSquad.first.id;
    }
  }

  PlayerModel? _findPlayer(String? id) {
    if (id == null) return null;
    try {
      return widget.bowlingSquad.firstWhere((p) => p.id == id);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunOut = _selectedWicketType == WicketType.runOutStriker ||
        _selectedWicketType == WicketType.runOutNonStriker;
    final isCaught = _selectedWicketType == WicketType.caught;
    final isStumped = _selectedWicketType == WicketType.stumped;

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
                            ? '5th Wicket - Team will be ALL OUT'
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
            const SizedBox(height: 18),

            // 1. Select Out Batsman
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

            // 2. Dismissal Type Grid
            Text(
              'Method of Dismissal:',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildWicketTypeChip(WicketType.bowled, 'Bowled'),
                _buildWicketTypeChip(WicketType.caught, 'Caught'),
                _buildWicketTypeChip(WicketType.lbw, 'LBW'),
                _buildWicketTypeChip(WicketType.stumped, 'Stumped'),
                _buildWicketTypeChip(WicketType.hitWicket, 'Hit Wicket'),
                _buildWicketTypeChip(
                  _outBatsmanId == widget.striker.id
                      ? WicketType.runOutStriker
                      : WicketType.runOutNonStriker,
                  'Run Out',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Conditional: CAUGHT BY (Catcher / Fielder dropdown)
            if (isCaught && widget.bowlingSquad.isNotEmpty) ...[
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
                    value: _selectedCatcherId ?? widget.bowlingSquad.first.id,
                    items: widget.bowlingSquad.map((player) {
                      final isBowler = player.id == widget.currentBowler.id;
                      final isWK = player.role.toUpperCase() == 'WICKET_KEEPER';
                      final label = isBowler
                          ? '🎯 ${player.name} (Bowler — Caught & Bowled)'
                          : '🧤 ${player.name}${isWK ? " (WK)" : ""}';

                      return DropdownMenuItem<String>(
                        value: player.id,
                        child: Text(
                          label,
                          style: GoogleFonts.outfit(
                            color: isBowler ? AppColors.accent : AppColors.textPrimary,
                            fontWeight: isBowler ? FontWeight.bold : FontWeight.normal,
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

            // 4. Conditional: STUMPED BY (Wicketkeeper dropdown)
            if (isStumped && widget.bowlingSquad.isNotEmpty) ...[
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
                    value: _selectedStumperId ?? widget.bowlingSquad.first.id,
                    items: widget.bowlingSquad.map((player) {
                      final isWK = player.role.toUpperCase() == 'WICKET_KEEPER';
                      return DropdownMenuItem<String>(
                        value: player.id,
                        child: Text(
                          '🧤 ${player.name}${isWK ? " (Wicketkeeper)" : ""}',
                          style: GoogleFonts.outfit(
                            color: isWK ? AppColors.gold : AppColors.textPrimary,
                            fontWeight: isWK ? FontWeight.bold : FontWeight.normal,
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

            // 5. Conditional: RUN OUT (Fielder dropdown & Runs completed)
            if (isRunOut) ...[
              if (widget.bowlingSquad.isNotEmpty) ...[
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
                      value: _selectedRunOutFielderId ?? widget.bowlingSquad.first.id,
                      items: widget.bowlingSquad.map((player) {
                        return DropdownMenuItem<String>(
                          value: player.id,
                          child: Text(
                            '🏃 ${player.name}',
                            style: GoogleFonts.outfit(
                              color: AppColors.textPrimary,
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

            // 6. Incoming Batsman Selector (If not 5th wicket / all out)
            if (!widget.isLastPossibleWicket && widget.availableNextBatsmen.isNotEmpty) ...[
              Text(
                'Next Batsman to Crease:',
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

            // 7. Live Scorecard Dismissal Preview Banner
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
                      final input = BallDeliveryInput(
                        runsOffBat: _runsCompleted,
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
      label: Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppColors.wicket.withValues(alpha: 0.25),
      side: BorderSide(color: isSelected ? AppColors.wicket : Colors.white.withValues(alpha: 0.08)),
      onSelected: (_) => setState(() => _selectedWicketType = type),
    );
  }
}
