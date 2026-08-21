import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'features/match_management/presentation/fixtures_screen.dart';
import 'features/standings/presentation/standings_screen.dart';
import 'features/live_viewer/presentation/live_match_hub_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/providers/auth_provider.dart';

class MainNavigationApp extends ConsumerStatefulWidget {
  const MainNavigationApp({super.key});

  @override
  ConsumerState<MainNavigationApp> createState() => _MainNavigationAppState();
}

class _MainNavigationAppState extends ConsumerState<MainNavigationApp> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAuthenticatedScorer = user.canScore;

    final screens = [
      const FixturesScreen(),
      LiveMatchHubScreen(
        onExploreFixtures: () => setState(() => _currentIndex = 0),
      ),
      const StandingsScreen(),
      const LoginScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.primary,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textMuted,
          selectedLabelStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.sports_cricket_rounded),
              label: 'Fixtures',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.stream_rounded),
              label: 'Live Match',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard_rounded),
              label: 'Standings',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isAuthenticatedScorer
                        ? (user.isAdmin ? Icons.admin_panel_settings : Icons.verified_user)
                        : Icons.account_circle_outlined,
                  ),
                  if (isAuthenticatedScorer)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: user.isAdmin ? AppColors.gold : AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              label: isAuthenticatedScorer
                  ? (user.isAdmin ? 'Admin Hub' : 'Scorer Hub')
                  : 'Scorer Login',
            ),
          ],
        ),
      ),
    );
  }
}
