import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../models/player_model.dart';
import '../models/bowling_score.dart';
import '../models/match_model.dart';
import '../engine/cricket_scoring_engine.dart';

class BowlerSelectDialog extends StatefulWidget {
  final List<PlayerModel> bowlingSquad;
  final String? previousBowlerId;
  final bool isFinalMatch;
  final int maxOverPerBowler;
  final Map<String, BowlingScore> bowlingScores;
  final String title;

  const BowlerSelectDialog({
    super.key,
    required this.bowlingSquad,
    required this.previousBowlerId,
    required this.isFinalMatch,
    this.maxOverPerBowler = 1,
    required this.bowlingScores,
    this.title = 'SELECT MANDATORY NEXT BOWLER',
  });

  @override
  State<BowlerSelectDialog> createState() => _BowlerSelectDialogState();
}

class _BowlerSelectDialogState extends State<BowlerSelectDialog> {
  String? _selectedBowlerId;

  String get _subtitle {
    if (widget.maxOverPerBowler > 1) {
      return 'Max ${widget.maxOverPerBowler} overs per bowler (Consecutive guard active)';
    }
    if (widget.isFinalMatch) {
      return 'Final Match: Special quota active (Consecutive guard active)';
    }
    return 'Max 1 over per bowler (Consecutive guard active)';
  }

  @override
  void initState() {
    super.initState();
    // Auto-select first eligible bowler if available
    for (var bowler in widget.bowlingSquad) {
      final eligible = CricketScoringEngine.canBowlerBowlNextOver(
        bowlerId: bowler.id,
        previousBowlerId: widget.previousBowlerId,
        isFinalMatch: widget.isFinalMatch,
        bowlingScores: widget.bowlingScores,
        maxOverPerBowler: widget.maxOverPerBowler,
      );
      if (eligible) {
        _selectedBowlerId = bowler.id;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Mandatory selection: cannot be dismissed via back button
      child: Dialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sports_baseball, color: AppColors.accent, size: 24),
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
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _subtitle,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: Colors.white12),

              // Bowler List
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.bowlingSquad.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final bowler = widget.bowlingSquad[index];
                    final canBowl = CricketScoringEngine.canBowlerBowlNextOver(
                      bowlerId: bowler.id,
                      previousBowlerId: widget.previousBowlerId,
                      isFinalMatch: widget.isFinalMatch,
                      bowlingScores: widget.bowlingScores,
                      maxOverPerBowler: widget.maxOverPerBowler,
                    );

                    final ineligibilityReason = CricketScoringEngine.getBowlerIneligibilityReason(
                      bowlerId: bowler.id,
                      previousBowlerId: widget.previousBowlerId,
                      isFinalMatch: widget.isFinalMatch,
                      bowlingScores: widget.bowlingScores,
                      maxOverPerBowler: widget.maxOverPerBowler,
                    );

                    final score = widget.bowlingScores[bowler.id];
                    final oversStr = score?.oversString ?? '0.0';
                    final runs = score?.runs ?? 0;
                    final wickets = score?.wickets ?? 0;

                    final stage = widget.isFinalMatch ? MatchStage.finalMatch : MatchStage.league;
                    final maxBalls = CricketScoringEngine.getBowlerMaxBalls(
                      bowlerId: bowler.id,
                      stage: stage,
                      bowlingScores: widget.bowlingScores.values.toList(),
                      maxOverPerBowler: widget.maxOverPerBowler,
                    );
                    final maxOvers = maxBalls ~/ 6;

                    final isSelected = _selectedBowlerId == bowler.id;

                    return InkWell(
                      onTap: canBowl
                          ? () => setState(() => _selectedBowlerId = bowler.id)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Opacity(
                        opacity: canBowl ? 1.0 : 0.45,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accent.withValues(alpha: 0.15)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.accent : Colors.white.withValues(alpha: 0.06),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  '${bowler.jerseyNumber ?? index + 1}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            bowler.name,
                                            style: GoogleFonts.outfit(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '$oversStr / $maxOvers.0 ov',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: canBowl ? AppColors.accent : AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (ineligibilityReason != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          ineligibilityReason,
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: AppColors.wicket,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )
                                    else
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'Figures: $oversStr O - $runs R - $wickets W',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (canBowl)
                                Radio<String>(
                                  value: bowler.id,
                                  groupValue: _selectedBowlerId,
                                  activeColor: AppColors.accent,
                                  onChanged: (val) => setState(() => _selectedBowlerId = val),
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.block, color: AppColors.textMuted, size: 20),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _selectedBowlerId == null
                    ? null
                    : () => Navigator.pop(context, _selectedBowlerId),
                child: Text(
                  'CONFIRM BOWLER',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
