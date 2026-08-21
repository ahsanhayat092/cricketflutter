import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../models/ball_event.dart';
import '../models/player_model.dart';

class WicketDialog extends StatefulWidget {
  final PlayerModel striker;
  final PlayerModel nonStriker;
  final List<PlayerModel> availableNextBatsmen;
  final PlayerModel currentBowler;
  final bool isLastPossibleWicket; // 5th dismissal = ALL OUT

  const WicketDialog({
    super.key,
    required this.striker,
    required this.nonStriker,
    required this.availableNextBatsmen,
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
  int _runsCompleted = 0; // For run outs

  @override
  void initState() {
    super.initState();
    _outBatsmanId = widget.striker.id;
    if (widget.availableNextBatsmen.isNotEmpty && !widget.isLastPossibleWicket) {
      _incomingBatsmanId = widget.availableNextBatsmen.first.id;
    }
  }

  String _buildDismissalDescription() {
    final bowlerName = widget.currentBowler.name;
    switch (_selectedWicketType) {
      case WicketType.bowled:
        return 'b $bowlerName';
      case WicketType.caught:
        return 'c Fielder b $bowlerName';
      case WicketType.runOutStriker:
      case WicketType.runOutNonStriker:
        return 'run out';
      case WicketType.stumped:
        return 'st Keeper b $bowlerName';
      case WicketType.lbw:
        return 'lbw b $bowlerName';
      case WicketType.hitWicket:
        return 'hit wicket b $bowlerName';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunOut = _selectedWicketType == WicketType.runOutStriker ||
        _selectedWicketType == WicketType.runOutNonStriker;

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

            // 3. Run Out Runs Completed
            if (isRunOut) ...[
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

            // 4. Incoming Batsman Selector (If not 5th wicket / all out)
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
              const SizedBox(height: 20),
            ],

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
