import 'package:flutter/material.dart';
import 'app_restarter.dart';
import '../config/app_theme.dart';

/// Custom title bar for Windows desktop.
/// NOTE: To use DragToMoveArea and WindowCaption, add `window_manager` to pubspec.yaml.
/// Currently unused — kept as a stub to avoid compilation errors.
class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: ColoredBox(
        color: Colors.black,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                // Drag-to-move placeholder (requires window_manager)
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.psychology_rounded, color: AppTheme.accentIndigo, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'DeepTutor',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: InkWell(
                onTap: () => AppRestarter.restartApp(context),
                hoverColor: Colors.white.withValues(alpha: 0.2),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
