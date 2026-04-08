import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Single source of truth for context-aware theme colors.
/// Import this in every screen/widget instead of defining local ThemeHelper.
extension ThemeHelper on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get scaffoldBg => isDark ? AppTheme.darkPrimary : AppTheme.primary;
  Color get surfaceColor => isDark ? AppTheme.darkSurface : AppTheme.surface;
  Color get surfaceColorDark => isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0);
  Color get cardColor => isDark ? AppTheme.darkCard : AppTheme.card;
  Color get cardBorder => isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder;
  Color get textPri => isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
  Color get textSec => isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
  Color get textTer => isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary;
}
