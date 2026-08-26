import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../match_management/providers/tournament_providers.dart';
import '../../auth/presentation/login_screen.dart';

class ScorerPinAuthDialog extends ConsumerStatefulWidget {
  final String tournamentId;
  final String tournamentName;

  const ScorerPinAuthDialog({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  ConsumerState<ScorerPinAuthDialog> createState() => _ScorerPinAuthDialogState();
}

class _ScorerPinAuthDialogState extends ConsumerState<ScorerPinAuthDialog> {
  final _pinController = TextEditingController();
  bool _isError = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _verifyPin() {
    final enteredPin = _pinController.text.trim();
    if (enteredPin.length < 4) {
      setState(() {
        _isError = true;
        _errorMessage = 'Please enter a 4-digit PIN';
      });
      return;
    }

    final activeTournamentAsync = ref.read(activeTournamentProvider);
    final tournament = activeTournamentAsync.value;

    final expectedPin = tournament?.scorerPin ?? '1234';

    if (enteredPin == expectedPin) {
      // Unlock session
      final currentMap = Map<String, bool>.from(ref.read(scorerPinSessionProvider));
      currentMap[widget.tournamentId] = true;
      ref.read(scorerPinSessionProvider.notifier).state = currentMap;

      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ground Scorer access unlocked for ${widget.tournamentName}!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.cardBackground,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _isError = true;
        _errorMessage = 'Incorrect Scorer PIN. Please ask tournament organizer.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pin_rounded, color: AppColors.accent, size: 32),
            ),
            const SizedBox(height: 16),

            // Title & Subtitle
            Text(
              'Ground Scorer Access',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.tournamentName,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the 4-digit matchday Ground PIN to unlock live scoring console.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),

            // 4-Digit PIN Input Field
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              obscureText: true,
              style: GoogleFonts.outfit(
                fontSize: 24,
                letterSpacing: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.accent,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                hintStyle: GoogleFonts.outfit(
                  fontSize: 24,
                  letterSpacing: 12,
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.accent, width: 2),
                ),
              ),
              onSubmitted: (_) => _verifyPin(),
            ),

            if (_isError) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.wicket,
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Unlock Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _verifyPin,
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: Text(
                  'UNLOCK LIVE SCORING',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Organizer Account Link
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              icon: const Icon(Icons.manage_accounts_rounded, size: 16, color: AppColors.accentCyan),
              label: Text(
                'Organizer / Admin Email Login',
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.accentCyan),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
