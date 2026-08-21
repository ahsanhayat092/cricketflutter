import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../models/ball_event.dart';

class NoBallDialog extends StatefulWidget {
  const NoBallDialog({super.key});

  @override
  State<NoBallDialog> createState() => _NoBallDialogState();
}

class _NoBallDialogState extends State<NoBallDialog> {
  int _runsOffBat = 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
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
                    color: AppColors.accentCyan.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.accentCyan, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NO BALL DETAILS',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Select runs scored off the No Ball (+1 automatic extra)',
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
            const SizedBox(height: 18),

            Text(
              'Runs Scored by Batsman:',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),

            // Runs off bat grid
            Row(
              children: [
                _buildRunOption(0, '0 (Nb+1)'),
                const SizedBox(width: 6),
                _buildRunOption(1, '1 (Nb+2)'),
                const SizedBox(width: 6),
                _buildRunOption(2, '2 (Nb+3)'),
                const SizedBox(width: 6),
                _buildRunOption(3, '3 (Nb+4)'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildBoundaryOption(4, '4 (FOUR • Nb+5)', AppColors.fourRuns),
                const SizedBox(width: 8),
                _buildBoundaryOption(6, '6 (SIX • Nb+7)', AppColors.sixRuns),
              ],
            ),
            const SizedBox(height: 20),

            // Summary Text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Runs for this ball:',
                    style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  Text(
                    '${1 + _runsOffBat} Runs',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action buttons
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
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(
                        context,
                        BallDeliveryInput(
                          runsOffBat: _runsOffBat,
                          extraType: ExtraType.noBall,
                          extraRuns: 1, // Standard 1 no ball run
                        ),
                      );
                    },
                    child: Text(
                      'RECORD NO BALL',
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

  Widget _buildRunOption(int runs, String label) {
    final isSelected = _runsOffBat == runs;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _runsOffBat = runs),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.accent : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Center(
            child: Text(
              '$runs',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.black : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoundaryOption(int runs, String label, Color color) {
    final isSelected = _runsOffBat == runs;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _runsOffBat = runs),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.3) : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: isSelected ? color : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
