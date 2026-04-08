import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../providers/settings_provider.dart';

/// A simple EN / বাং toggle button. Tap to switch between English and Bengali.
class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isBangla = settings.preferredLanguage == 'Bengali';

    return GestureDetector(
      onTap: () {
        final next = isBangla ? 'English' : 'Bengali';
        ref.read(settingsProvider.notifier).setPreferredLanguage(next);
        // Use rootNavigator context to safely show snackbar anywhere
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(
            content: Text('AI will respond in $next'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isBangla
              ? AppTheme.accentCyan.withValues(alpha: 0.18)
              : AppTheme.accentCyan.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.accentCyan.withValues(alpha: isBangla ? 0.6 : 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 14, color: AppTheme.accentCyan),
            const SizedBox(width: 5),
            Text(
              isBangla ? 'বাং' : 'EN',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentCyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
