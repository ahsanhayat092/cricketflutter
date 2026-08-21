import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../scoring/models/team_model.dart';

class TossResult {
  final String winnerTeamId;
  final String decision; // "BAT" | "BOWL"

  const TossResult({required this.winnerTeamId, required this.decision});
}

class TossModal extends StatefulWidget {
  final TeamModel teamA;
  final TeamModel teamB;

  const TossModal({super.key, required this.teamA, required this.teamB});

  @override
  State<TossModal> createState() => _TossModalState();
}

class _TossModalState extends State<TossModal> {
  late String _winnerTeamId;
  String _decision = 'BAT'; // "BAT" | "BOWL"

  @override
  void initState() {
    super.initState();
    _winnerTeamId = widget.teamA.id;
  }

  @override
  Widget build(BuildContext context) {
    final winnerTeam = _winnerTeamId == widget.teamA.id ? widget.teamA : widget.teamB;

    return Dialog(
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
                    color: AppColors.gold.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.monetization_on_rounded, color: AppColors.gold, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'MATCH TOSS',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.white12),

            // 1. Toss Winner
            Text(
              'TOSS WON BY',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildTeamChoice(widget.teamA)),
                const SizedBox(width: 10),
                Expanded(child: _buildTeamChoice(widget.teamB)),
              ],
            ),

            const SizedBox(height: 20),

            // 2. Decision
            Text(
              'ELECTED TO',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildDecisionChoice('BAT FIRST', 'BAT', Icons.sports_cricket)),
                const SizedBox(width: 10),
                Expanded(child: _buildDecisionChoice('BOWL FIRST', 'BOWL', Icons.sports_baseball)),
              ],
            ),

            const SizedBox(height: 20),

            // Summary text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '📢 ${winnerTeam.name} won the toss and elected to ${_decision == "BAT" ? "Bat" : "Bowl"} first.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        TossResult(winnerTeamId: _winnerTeamId, decision: _decision),
                      );
                    },
                    child: const Text('CONFIRM TOSS'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamChoice(TeamModel team) {
    final isSelected = _winnerTeamId == team.id;
    return InkWell(
      onTap: () => setState(() => _winnerTeamId = team.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.18) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.white10,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          team.shortName,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.accent : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildDecisionChoice(String label, String value, IconData icon) {
    final isSelected = _decision == value;
    return InkWell(
      onTap: () => setState(() => _decision = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentCyan.withOpacity(0.18) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accentCyan : Colors.white10,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.accentCyan : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.accentCyan : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
