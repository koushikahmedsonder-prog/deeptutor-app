import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// A standardized action chip/button used across all DeepTutor screens.
///
/// Supports loading state, icon, accent color, and tooltip.
/// Replaces the duplicated button patterns in solver, research, and notebook.
class ActionChipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isActive;
  final String? tooltip;
  final bool compact;

  const ActionChipButton({
    super.key,
    required this.label,
    required this.icon,
    this.color = AppTheme.accentIndigo,
    this.onTap,
    this.isLoading = false,
    this.isActive = false,
    this.tooltip,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final chip = GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.2)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.6)
                : color.withValues(alpha: 0.2),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: compact ? 14 : 16,
                height: compact ? 14 : 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(
                icon,
                size: compact ? 14 : 16,
                color: color,
              ),
            SizedBox(width: compact ? 6 : 8),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: chip);
    }
    return chip;
  }
}

/// A standardized toggle button for features like Web Search.
class ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onToggle;
  final Color activeColor;
  final Color inactiveColor;

  const ToggleChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onToggle,
    this.activeColor = AppTheme.accentCyan,
    this.inactiveColor = AppTheme.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.15)
              : AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.5)
                : AppTheme.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? activeColor : inactiveColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
