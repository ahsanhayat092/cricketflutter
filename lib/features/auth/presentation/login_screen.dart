import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../../scoring/presentation/scorer_console_screen.dart';
import '../../match_management/presentation/fixtures_screen.dart';
import '../../match_management/providers/tournament_providers.dart';
import 'scorer_pin_auth_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  int _mainAuthTab = 0; // 0: Ground Scorer PIN, 1: Official Account
  bool _isSignUpMode = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _selectedRole = 'scorer'; // 'scorer' | 'admin'
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isSignUpMode) {
        await ref.read(currentUserProvider.notifier).signUpWithEmail(
              email,
              password,
              role: _selectedRole,
            );
      } else {
        await ref.read(currentUserProvider.notifier).signInWithEmail(
              email,
              password,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isSignUpMode
                  ? 'Account created and logged in successfully!'
                  : 'Welcome back! Logged in as match official.',
            ),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFriendlyErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Authentication error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(currentUserProvider.notifier).signInWithGoogle();
      if (mounted) {
        final user = ref.read(currentUserProvider);
        if (user.canScore) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logged in with Google as ${user.email.isNotEmpty ? user.email : "Official"}'),
              backgroundColor: AppColors.accent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFriendlyErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Google Sign-In error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getFriendlyErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No registered account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Please verify your credentials.';
      case 'email-already-in-use':
        return 'An account already exists for this email address.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Authentication failed ($code). Please try again.';
    }
  }

  void _handleQuickDemoLogin(String role) {
    setState(() => _isLoading = true);
    if (role == 'admin') {
      ref.read(currentUserProvider.notifier).setDemoUser(
            email: 'admin@wasacricket.com',
            role: 'admin',
          );
    } else if (role == 'scorer') {
      ref.read(currentUserProvider.notifier).setDemoUser(
            email: 'scorer@wasacricket.com',
            role: 'scorer',
          );
    } else {
      ref.read(currentUserProvider.notifier).logout();
    }
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          role == 'public'
              ? 'Switched to Public View Mode (Read-Only)'
              : 'Logged in as ${role.toUpperCase()} (Quick Access)',
        ),
        backgroundColor: role == 'public' ? AppColors.surfaceLight : AppColors.accent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address to reset password.'),
          backgroundColor: AppColors.wicket,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await ref.read(currentUserProvider.notifier).sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send reset email: $e'),
            backgroundColor: AppColors.wicket,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final unlockedTournaments = ref.watch(unlockedTournamentsProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Brand Emblem
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentCyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sports_cricket,
                    size: 38,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'CRICKET SCORER ACCESS',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Multi-Tenant Scoring & Match Control',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // 2-Way Tab Bar: Ground Scorer PIN vs Official Account
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _mainAuthTab = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _mainAuthTab == 0 ? AppColors.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.pin_rounded,
                                size: 16,
                                color: _mainAuthTab == 0 ? Colors.black : AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Matchday PIN (${unlockedTournaments.length})',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _mainAuthTab == 0 ? Colors.black : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _mainAuthTab = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _mainAuthTab == 1 ? AppColors.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_circle_outlined,
                                size: 16,
                                color: _mainAuthTab == 1 ? Colors.black : AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                user.canScore ? 'Official Portal' : 'Official Login',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _mainAuthTab == 1 ? Colors.black : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // TAB 0: Ground Scorer PIN Section
              if (_mainAuthTab == 0)
                _buildMatchdayPinSection()
              // TAB 1: Official Account Section
              else if (user.canScore)
                _buildAuthenticatedPortal(user)
              else
                _buildPublicLoginForm(),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // MATCHDAY PIN SECTION (Scoped Tournament Unlocks)
  // -------------------------------------------------------------
  Widget _buildMatchdayPinSection() {
    final allTournamentsAsync = ref.watch(allTournamentsProvider);
    final unlockedIds = ref.watch(unlockedTournamentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action Button: Enter Tournament PIN
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const ScorerPinAuthDialog(),
              );
            },
            icon: const Icon(Icons.pin_rounded, size: 20),
            label: Text(
              'ENTER 4-DIGIT SCORER PIN',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Unlocked Tournaments Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Unlocked Tournaments (${unlockedIds.length})',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (unlockedIds.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await ref.read(unlockedTournamentsProvider.notifier).clearAll();
                },
                child: Text(
                  'Lock All',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.wicket),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (unlockedIds.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 36, color: AppColors.textMuted),
                const SizedBox(height: 10),
                Text(
                  'No Tournaments Unlocked',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ground Scorers can select a tournament and enter its 4-digit PIN above to score matches.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          )
        else
          allTournamentsAsync.when(
            data: (tournaments) {
              final unlockedList = tournaments.where((t) => unlockedIds.contains(t.id)).toList();

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: unlockedList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final tour = unlockedList[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.sports_cricket, color: Colors.black, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tour.name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${tour.oversPerSide} Overs • ${tour.venueName}',
                                    style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Lock Tournament',
                              onPressed: () async {
                                await ref.read(unlockedTournamentsProvider.notifier).lockTournament(tour.id);
                              },
                              icon: const Icon(Icons.lock_rounded, size: 18, color: AppColors.wicket),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.surfaceLight,
                                  foregroundColor: AppColors.accentCyan,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  ref.read(activeTournamentIdProvider.notifier).state = tour.id;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const FixturesScreen()),
                                  );
                                },
                                icon: const Icon(Icons.scoreboard_outlined, size: 16),
                                label: Text(
                                  'Score Matches',
                                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
      ],
    );
  }

  // -------------------------------------------------------------
  // AUTHENTICATED PORTAL (When logged in as Scorer or Admin)
  // -------------------------------------------------------------
  Widget _buildAuthenticatedPortal(dynamic user) {
    final isAdmin = user.isAdmin;
    final badgeColor = isAdmin ? AppColors.gold : AppColors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Profile Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: badgeColor.withValues(alpha: 0.12),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: badgeColor,
                    child: Icon(
                      isAdmin ? Icons.admin_panel_settings : Icons.verified_user,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: badgeColor, width: 1),
                          ),
                          child: Text(
                            isAdmin ? 'TOURNAMENT ADMIN' : 'OFFICIAL SCORER',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: badgeColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          user.email.isNotEmpty ? user.email : 'Official Match Official',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'UID: ${user.uid.length > 14 ? "${user.uid.substring(0, 14)}..." : user.uid}',
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
              const Divider(height: 1, color: Colors.white10),
              const SizedBox(height: 14),

              // Permissions Checklist
              Row(
                children: [
                  _buildPermissionBadge(Icons.check_circle, 'Live Scoring', AppColors.accent),
                  const SizedBox(width: 8),
                  _buildPermissionBadge(Icons.check_circle, 'Lineup / Toss', AppColors.accentCyan),
                  const SizedBox(width: 8),
                  _buildPermissionBadge(Icons.check_circle, 'Undo & Overs', AppColors.gold),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        Text(
          'Quick Scorer Actions',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // Action Buttons
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.sports_cricket, size: 20),
          label: Text(
            'OPEN LIVE MATCH SCORER CONSOLE',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ScorerConsoleScreen(matchId: 'match-1'),
              ),
            );
          },
        ),
        const SizedBox(height: 10),

        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentCyan,
            side: const BorderSide(color: AppColors.accentCyan),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.groups_rounded, size: 20),
          label: Text(
            'MANAGE FIXTURES & LINEUPS',
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FixturesScreen()),
            );
          },
        ),

        const SizedBox(height: 28),

        // Sign Out Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.wicket,
            side: BorderSide(color: AppColors.wicket.withValues(alpha: 0.6)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: Text(
            'Sign Out (Switch to Public View Mode)',
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          onPressed: () async {
            await ref.read(currentUserProvider.notifier).logout();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out. You are now in Public Viewer mode.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildPermissionBadge(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // PUBLIC / GUEST LOGIN FORM
  // -------------------------------------------------------------
  Widget _buildPublicLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mode Toggle (Sign In vs Register Scorer)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _isSignUpMode = false;
                      _errorMessage = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isSignUpMode ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Scorer Sign In',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: !_isSignUpMode ? Colors.black : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _isSignUpMode = true;
                      _errorMessage = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isSignUpMode ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Register Scorer',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _isSignUpMode ? Colors.black : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Error Banner
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.wicket.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.wicket, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.wicket, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Role Selector (During Sign Up)
          if (_isSignUpMode) ...[
            Text(
              'Select Official Role:',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildRoleChoice(
                    title: 'Match Scorer',
                    role: 'scorer',
                    icon: Icons.edit_note_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildRoleChoice(
                    title: 'Tournament Admin',
                    role: 'admin',
                    icon: Icons.admin_panel_settings_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.outfit(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Official Email Address',
              hintText: 'scorer@wasacricket.com',
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.accentCyan),
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Please enter an email';
              if (!val.contains('@')) return 'Please enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: GoogleFonts.outfit(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.accentCyan),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textMuted,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Please enter a password';
              if (val.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),

          if (!_isSignUpMode)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _handleForgotPassword,
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.accentCyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 16),

          // Submit Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            onPressed: _isLoading ? null : _submitAuth,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : Text(
                    _isSignUpMode ? 'CREATE SCORER ACCOUNT' : 'SIGN IN TO SCORER CONSOLE',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),

          const SizedBox(height: 16),

          // OR Divider
          Row(
            children: [
              const Expanded(child: Divider(color: Colors.white10)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Colors.white10)),
            ],
          ),
          const SizedBox(height: 16),

          // Google Sign In Button
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppColors.cardBackground,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGoogleLogo(),
                const SizedBox(width: 12),
                Text(
                  'Sign in with Google',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Fast 1-Tap Scorer & Admin Credentials (For easy field testing)
          Row(
            children: [
              const Expanded(child: Divider(color: Colors.white10)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '1-Tap Demo / Field Testing Access',
                  style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
              const Expanded(child: Divider(color: Colors.white10)),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildQuickLoginBtn(
                  title: 'Scorer Demo',
                  subtitle: 'Ball-by-ball scoring',
                  icon: Icons.sports_cricket,
                  color: AppColors.accent,
                  onTap: () => _handleQuickDemoLogin('scorer'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickLoginBtn(
                  title: 'Admin Demo',
                  subtitle: 'Lineup & tournament',
                  icon: Icons.admin_panel_settings,
                  color: AppColors.gold,
                  onTap: () => _handleQuickDemoLogin('admin'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Public Mode Reassurance Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.accentCyan, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Public Spectator Notice',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Public viewers have full real-time access to live scoreboards, match wheels, tournament fixtures & standings without needing to log in. Only official scorers need to authenticate to input match data.',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleLogo() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        'G',
        style: GoogleFonts.outfit(
          color: const Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildRoleChoice({
    required String title,
    required String role,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLoginBtn({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
