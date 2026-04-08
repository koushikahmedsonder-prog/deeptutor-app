import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// A reusable glassmorphism container used across DeepTutor screens.
///
/// Provides consistent card styling with customizable accent color,
/// border radius, gradient intensity, and padding.
///
/// Usage:
/// ```dart
/// GlassContainer(
///   accentColor: AppTheme.accentCyan,
///   child: Text('Content'),
/// )
/// ```
class GlassContainer extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double opacity;
  final VoidCallback? onTap;
  final bool showBorder;

  const GlassContainer({
    super.key,
    required this.child,
    this.accentColor,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    this.opacity = 0.06,
    this.onTap,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppTheme.accentIndigo;

    final container = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: opacity),
            AppTheme.card,
          ],
        ),
        border: showBorder
            ? Border.all(
                color: accent.withValues(alpha: 0.2),
                width: 1,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: container);
    }
    return container;
  }
}

/// A section header with consistent styling across all screens.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = color ?? AppTheme.accentCyan;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: accentColor),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
