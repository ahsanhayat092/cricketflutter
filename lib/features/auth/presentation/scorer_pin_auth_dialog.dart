import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../scoring/models/tournament_model.dart';
import '../../match_management/providers/tournament_providers.dart';
import 'login_screen.dart';

class ScorerPinAuthDialog extends ConsumerStatefulWidget {
  final String? initialTournamentId;
  final String? initialTournamentName;
  final String? customPrompt;

  const ScorerPinAuthDialog({
    super.key,
    this.initialTournamentId,
    this.initialTournamentName,
    this.customPrompt,
  });

  @override
  ConsumerState<ScorerPinAuthDialog> createState() => _ScorerPinAuthDialogState();
}

class _ScorerPinAuthDialogState extends ConsumerState<ScorerPinAuthDialog> {
  final _pinController = TextEditingController();
  String? _selectedTournamentId;
  bool _isError = false;
  String _errorMessage = '';
  int _remainingAttempts = 5;
  bool _isLockedOut = false;
  Duration _remainingLockout = Duration.zero;
  Timer? _lockoutTimer;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _selectedTournamentId = widget.initialTournamentId ?? 'main';
    _checkLockoutStatus();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkLockoutStatus() async {
    if (_selectedTournamentId == null) return;
    final securityService = ref.read(scorerSecurityServiceProvider);
    final isLocked = await securityService.isTournamentLockedOut(_selectedTournamentId!);
    final remaining = await securityService.getRemainingLockout(_selectedTournamentId!);
    final failed = await securityService.getFailedAttempts(_selectedTournamentId!);

    if (mounted) {
      setState(() {
        _isLockedOut = isLocked;
        _remainingLockout = remaining;
        _remainingAttempts = (5 - failed).clamp(0, 5);
        if (_isLockedOut) {
          _isError = true;
          _errorMessage =
              'Entry locked for ${_formatDuration(_remainingLockout)} due to 5 failed attempts.';
          _startLockoutCountdown();
        } else if (failed > 0) {
          _isError = true;
          _errorMessage = '$_remainingAttempts attempt${_remainingAttempts == 1 ? '' : 's'} remaining.';
        } else {
          _isError = false;
          _errorMessage = '';
        }
      });
    }
  }

  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingLockout.inSeconds <= 1) {
        timer.cancel();
        _checkLockoutStatus();
      } else {
        setState(() {
          _remainingLockout = _remainingLockout - const Duration(seconds: 1);
          _errorMessage =
              'Entry locked for ${_formatDuration(_remainingLockout)} due to 5 failed attempts.';
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  Future<void> _verifyPin(TournamentModel tournament) async {
    if (_isLockedOut || _isVerifying) return;

    final enteredPin = _pinController.text.trim();
    if (enteredPin.length < 4) {
      setState(() {
        _isError = true;
        _errorMessage = 'Please enter a 4-digit PIN';
      });
      return;
    }

    setState(() => _isVerifying = true);

    final securityService = ref.read(scorerSecurityServiceProvider);
    final result = await securityService.verifyTournamentPin(
      tournament: tournament,
      enteredPin: enteredPin,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (result.isSuccess) {
      // 1. Update StateNotifier for unlocked tournaments
      await ref.read(unlockedTournamentsProvider.notifier).unlockTournament(tournament.id);

      // 2. Set active tournament context to this tournament
      ref.read(activeTournamentIdProvider.notifier).state = tournament.id;

      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scoring unlocked for ${tournament.name}!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.cardBackground,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (result.isLockedOut) {
      setState(() {
        _isLockedOut = true;
        _remainingLockout = result.remainingLockout;
        _isError = true;
        _errorMessage = result.errorMessage ?? 'Entry locked due to 5 failed attempts.';
      });
      _startLockoutCountdown();
    } else {
      setState(() {
        _isError = true;
        _remainingAttempts = result.remainingAttempts;
        _errorMessage = result.errorMessage ?? 'Incorrect PIN';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTournamentsAsync = ref.watch(allTournamentsProvider);

    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: allTournamentsAsync.when(
          data: (tournaments) {
            if (tournaments.isEmpty) {
              return const Center(child: Text('No tournaments available'));
            }

            final selectedTournament = tournaments.firstWhere(
              (t) => t.id == _selectedTournamentId,
              orElse: () => tournaments.first,
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isLockedOut
                        ? AppColors.wicket.withValues(alpha: 0.15)
                        : AppColors.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isLockedOut ? Icons.lock_clock_rounded : Icons.pin_rounded,
                    color: _isLockedOut ? AppColors.wicket : AppColors.accent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Ground Scorer Entry',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // 1. Explicit Tournament Dropdown Selector (Eliminates PIN collision)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedTournament.id,
                      isExpanded: true,
                      dropdownColor: AppColors.surfaceLight,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.accent),
                      items: tournaments.map((t) {
                        return DropdownMenuItem<String>(
                          value: t.id,
                          child: Row(
                            children: [
                              const Icon(Icons.emoji_events_rounded, color: AppColors.accent, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (newId) {
                        if (newId != null && newId != _selectedTournamentId) {
                          setState(() {
                            _selectedTournamentId = newId;
                            _pinController.clear();
                            _isError = false;
                            _errorMessage = '';
                          });
                          _checkLockoutStatus();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Subtitle Instruction
                Text(
                  _isLockedOut
                      ? 'Too many incorrect attempts. Please wait for the lockout countdown.'
                      : (widget.customPrompt ??
                          'Enter the 4-digit Scorer PIN for ${selectedTournament.name} to unlock this live scoring console.'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: _isLockedOut ? AppColors.wicket : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),

                // 4-Digit PIN Input Field
                TextField(
                  controller: _pinController,
                  enabled: !_isLockedOut && !_isVerifying,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  obscureText: true,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    letterSpacing: 12,
                    fontWeight: FontWeight.w900,
                    color: _isLockedOut ? AppColors.textMuted : AppColors.accent,
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
                  onSubmitted: (_) => _verifyPin(selectedTournament),
                ),

                if (_isError) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.wicket.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isLockedOut ? Icons.timer_outlined : Icons.warning_amber_rounded,
                          color: AppColors.wicket,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.wicket,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Unlock Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLockedOut || _isVerifying
                        ? null
                        : () => _verifyPin(selectedTournament),
                    icon: _isVerifying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.lock_open_rounded, size: 18),
                    label: Text(
                      _isLockedOut
                          ? 'LOCKED (${_formatDuration(_remainingLockout)})'
                          : 'UNLOCK SCORING',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isLockedOut ? AppColors.surfaceLight : AppColors.accent,
                      foregroundColor: _isLockedOut ? AppColors.textMuted : Colors.black,
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
                    'Official Scorer / Organizer Login',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.accentCyan),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
