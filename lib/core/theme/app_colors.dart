import 'package:flutter/material.dart';

/// Application color palette
class AppColors {
  AppColors._();

  // Primary colors
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFFBBDEFB);

  // Secondary colors
  static const Color secondary = Color(0xFF00BCD4);
  static const Color secondaryDark = Color(0xFF0097A7);

  // Accent colors
  static const Color accent = Color(0xFFFF9800);

  // Highlight colors for annotations
  static const Color highlightYellow = Color(0xFFFFEB3B);
  static const Color highlightGreen = Color(0xFF8BC34A);
  static const Color highlightBlue = Color(0xFF03A9F4);
  static const Color highlightPink = Color(0xFFE91E63);
  static const Color highlightOrange = Color(0xFFFF9800);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Neutral colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFBDBDBD);

  // Dark mode colors
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);

  /// Get highlight color by index
  static Color getHighlightColor(int index) {
    final colors = [
      highlightYellow,
      highlightGreen,
      highlightBlue,
      highlightPink,
      highlightOrange,
    ];
    return colors[index % colors.length];
  }

  /// Get all highlight colors
  static List<Color> get highlightColors => [
        highlightYellow,
        highlightGreen,
        highlightBlue,
        highlightPink,
        highlightOrange,
      ];
}
