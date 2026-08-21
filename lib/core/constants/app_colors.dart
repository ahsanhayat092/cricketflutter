import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand Colors
  static const Color primary = Color(0xFF0F172A); // Dark Slate
  static const Color secondary = Color(0xFF1E293B);
  static const Color surface = Color(0xFF1E293B);
  static const Color background = Color(0xFF0B0F19);
  static const Color surfaceLight = Color(0xFF2B3548);
  static const Color cardBackground = Color(0xFF1A2234);

  // Accent Colors
  static const Color accent = Color(0xFF00E676); // Neon Green
  static const Color accentCyan = Color(0xFF00E5FF); // Electric Cyan
  static const Color gold = Color(0xFFFFD700);

  // Cricket Delivery Badge Colors
  static const Color dotBall = Color(0xFF475569);
  static const Color singleRun = Color(0xFF3B82F6); // Blue
  static const Color twoRuns = Color(0xFF6366F1); // Indigo
  static const Color threeRuns = Color(0xFF8B5CF6); // Purple
  static const Color fourRuns = Color(0xFFF59E0B); // Amber / Orange
  static const Color sixRuns = Color(0xFF10B981); // Emerald Green
  static const Color wicket = Color(0xFFEF4444); // Crimson Red
  static const Color extra = Color(0xFFEC4899); // Pink

  // Status Colors
  static const Color liveRed = Color(0xFFFF334B);
  static const Color completedGreen = Color(0xFF10B981);
  static const Color upcomingBlue = Color(0xFF38BDF8);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Helper for delivery ball colors
  static Color getDeliveryColor(String ball) {
    final b = ball.trim().toUpperCase();
    if (b == 'W' || b.startsWith('W+') || b.contains('W')) return wicket;
    if (b == '6') return sixRuns;
    if (b == '4') return fourRuns;
    if (b == '0' || b == '•') return dotBall;
    if (b == '1') return singleRun;
    if (b == '2') return twoRuns;
    if (b == '3') return threeRuns;
    if (b.contains('WD') || b.contains('NB') || b.contains('LB') || b.contains('B')) {
      return extra;
    }
    return singleRun;
  }
}
