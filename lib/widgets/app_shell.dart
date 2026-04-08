import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_sidebar.dart';

/// Maps routes → human-readable titles shown on the mobile AppBar.
const _routeTitles = {
  '/': 'DeepTutor',
  '/solver': 'Deep Solve',
  '/knowledge': 'Knowledge',
  '/questions': 'Quiz Gen',
  '/research': 'Deep Research',
  '/ideagen': 'Idea Gen',
  '/notebook': 'Notebook',
  '/settings': 'Settings',
  '/todo': 'Study Planner',
  '/predict': 'Exam Predict',
};

/// Shell that wraps every screen with navigation.
/// - Mobile (<600px): sliding Drawer + top AppBar with back/hamburger button
/// - Desktop: fixed side panel
class AppShell extends StatelessWidget {
  final String currentRoute;
  final Widget child;

  const AppShell({
    super.key,
    required this.currentRoute,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          final isHome = currentRoute == '/';
          final title = _routeTitles[currentRoute] ?? 'DeepTutor';

          return Scaffold(
            // ── Sliding sidebar drawer ──
            drawer: Drawer(
              width: 280,
              child: AppSidebar(
                currentRoute: currentRoute,
                onNavigated: () => Navigator.of(context).pop(),
              ),
            ),
            // ── Mobile top AppBar ──
            appBar: AppBar(
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: isHome
                  ? Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu_rounded),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                        tooltip: 'Open menu',
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                      tooltip: 'Back',
                    ),
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            body: child,
          );
        } else {
          // ── Desktop: fixed sidebar ──
          return Scaffold(
            body: Row(
              children: [
                AppSidebar(currentRoute: currentRoute),
                Expanded(child: child),
              ],
            ),
          );
        }
      },
    );
  }
}
