import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';

class OpeningPlayersResult {
  final String strikerId;
  final String nonStrikerId;
  final String bowlerId;

  const OpeningPlayersResult({
    required this.strikerId,
    required this.nonStrikerId,
    required this.bowlerId,
  });
}

class OpeningPlayersDialog extends StatefulWidget {
  final String title;
  final TeamModel battingTeam;
  final TeamModel bowlingTeam;
  final List<PlayerModel> battingSquad;
  final List<PlayerModel> bowlingSquad;
  final String? initialStrikerId;
  final String? initialNonStrikerId;
  final String? initialBowlerId;

  const OpeningPlayersDialog({
    super.key,
    this.title = 'SELECT OPENING PLAYERS',
    required this.battingTeam,
    required this.bowlingTeam,
    required this.battingSquad,
    required this.bowlingSquad,
    this.initialStrikerId,
    this.initialNonStrikerId,
    this.initialBowlerId,
  });

  @override
  State<OpeningPlayersDialog> createState() => _OpeningPlayersDialogState();
}

class _OpeningPlayersDialogState extends State<OpeningPlayersDialog> {
  String? _selectedStrikerId;
  String? _selectedNonStrikerId;
  String? _selectedBowlerId;

  @override
  void initState() {
    super.initState();

    // Default striker
    if (widget.initialStrikerId != null &&
        widget.battingSquad.any((p) => p.id == widget.initialStrikerId)) {
      _selectedStrikerId = widget.initialStrikerId;
    } else if (widget.battingSquad.isNotEmpty) {
      _selectedStrikerId = widget.battingSquad[0].id;
    }

    // Default non-striker (must be different from striker)
    if (widget.initialNonStrikerId != null &&
        widget.battingSquad.any((p) => p.id == widget.initialNonStrikerId) &&
        widget.initialNonStrikerId != _selectedStrikerId) {
      _selectedNonStrikerId = widget.initialNonStrikerId;
    } else if (widget.battingSquad.length > 1) {
      _selectedNonStrikerId = widget.battingSquad
          .firstWhere((p) => p.id != _selectedStrikerId, orElse: () => widget.battingSquad[1])
          .id;
    }

    // Default bowler
    if (widget.initialBowlerId != null &&
        widget.bowlingSquad.any((p) => p.id == widget.initialBowlerId)) {
      _selectedBowlerId = widget.initialBowlerId;
    } else if (widget.bowlingSquad.isNotEmpty) {
      _selectedBowlerId = widget.bowlingSquad[0].id;
    }
  }

  void _swapOpeners() {
    setState(() {
      final temp = _selectedStrikerId;
      _selectedStrikerId = _selectedNonStrikerId;
      _selectedNonStrikerId = temp;
    });
  }

  PlayerModel? _findPlayer(List<PlayerModel> squad, String? id) {
    if (id == null) return null;
    try {
      return squad.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  void _openPlayerPicker({
    required String title,
    required List<PlayerModel> squad,
    required String? currentSelectedId,
    String? disabledId,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: squad.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (ctx, idx) {
                    final player = squad[idx];
                    final isSelected = player.id == currentSelectedId;
                    final isDisabled = player.id == disabledId;

                    return ListTile(
                      enabled: !isDisabled,
                      onTap: isDisabled
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              onSelected(player.id);
                            },
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: isSelected
                            ? AppColors.accent
                            : (isDisabled ? AppColors.surfaceLight : AppColors.surface),
                        child: Text(
                          player.name.isNotEmpty ? player.name[0] : 'P',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.black : (isDisabled ? AppColors.textMuted : AppColors.textPrimary),
                          ),
                        ),
                      ),
                      title: Text(
                        player.name,
                        style: GoogleFonts.outfit(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isDisabled
                              ? AppColors.textMuted
                              : (isSelected ? AppColors.accent : AppColors.textPrimary),
                        ),
                      ),
                      subtitle: Text(
                        isDisabled ? 'Already selected at other end' : player.role,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: isDisabled ? AppColors.wicket : AppColors.textMuted,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.accent)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final striker = _findPlayer(widget.battingSquad, _selectedStrikerId);
    final nonStriker = _findPlayer(widget.battingSquad, _selectedNonStrikerId);
    final bowler = _findPlayer(widget.bowlingSquad, _selectedBowlerId);

    final isValid = _selectedStrikerId != null &&
        _selectedNonStrikerId != null &&
        _selectedBowlerId != null &&
        _selectedStrikerId != _selectedNonStrikerId;

    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sports_cricket_rounded,
                      color: AppColors.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Choose opening batsmen & 1st over bowler',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // BATTING TEAM SECTION
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.sports, size: 14, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Text(
                              'BATTING • ${widget.battingTeam.name.toUpperCase()}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.accent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        if (_selectedStrikerId != null && _selectedNonStrikerId != null)
                          InkWell(
                            onTap: _swapOpeners,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.accentCyan),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Swap Strike',
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
                    const SizedBox(height: 12),

                    // 1. Striker
                    Text(
                      'STRIKER (Facing 1st Ball)',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildPlayerCardTile(
                      player: striker,
                      placeholder: 'Select Opening Striker',
                      activeColor: AppColors.accent,
                      icon: Icons.sports_cricket_rounded,
                      onTap: () {
                        _openPlayerPicker(
                          title: 'Select Striker (Facing 1st Ball)',
                          squad: widget.battingSquad,
                          currentSelectedId: _selectedStrikerId,
                          disabledId: _selectedNonStrikerId,
                          onSelected: (id) => setState(() => _selectedStrikerId = id),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // 2. Non-Striker
                    Text(
                      'NON-STRIKER (Runner End)',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildPlayerCardTile(
                      player: nonStriker,
                      placeholder: 'Select Opening Non-Striker',
                      activeColor: AppColors.accentCyan,
                      icon: Icons.person_rounded,
                      onTap: () {
                        _openPlayerPicker(
                          title: 'Select Non-Striker (Runner End)',
                          squad: widget.battingSquad,
                          currentSelectedId: _selectedNonStrikerId,
                          disabledId: _selectedStrikerId,
                          onSelected: (id) => setState(() => _selectedNonStrikerId = id),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // BOWLING TEAM SECTION
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sports_baseball_rounded, size: 14, color: AppColors.gold),
                        const SizedBox(width: 6),
                        Text(
                          'BOWLING • ${widget.bowlingTeam.name.toUpperCase()}',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.gold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 3. Opening Bowler
                    Text(
                      'OPENING BOWLER (1st Over)',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildPlayerCardTile(
                      player: bowler,
                      placeholder: 'Select Opening Bowler',
                      activeColor: AppColors.gold,
                      icon: Icons.sports_baseball_rounded,
                      onTap: () {
                        _openPlayerPicker(
                          title: 'Select Opening Bowler (1st Over)',
                          squad: widget.bowlingSquad,
                          currentSelectedId: _selectedBowlerId,
                          onSelected: (id) => setState(() => _selectedBowlerId = id),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      onPressed: () => Navigator.pop(context, null),
                      child: Text(
                        'CANCEL',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isValid ? AppColors.accent : AppColors.surfaceLight,
                        foregroundColor: isValid ? Colors.black : AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: isValid ? 2 : 0,
                      ),
                      onPressed: isValid
                          ? () {
                              Navigator.pop(
                                context,
                                OpeningPlayersResult(
                                  strikerId: _selectedStrikerId!,
                                  nonStrikerId: _selectedNonStrikerId!,
                                  bowlerId: _selectedBowlerId!,
                                ),
                              );
                            }
                          : null,
                      child: Text(
                        'CONFIRM & START',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCardTile({
    required PlayerModel? player,
    required String placeholder,
    required Color activeColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSelected = player != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor.withValues(alpha: 0.6) : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withValues(alpha: 0.15) : AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? activeColor : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isSelected
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.name,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          player.role,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      placeholder,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isSelected ? activeColor : AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
