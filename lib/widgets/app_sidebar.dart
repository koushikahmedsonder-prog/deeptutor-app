import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_theme.dart';
import '../services/storage_service.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/language_selector.dart';

class AppSidebar extends ConsumerStatefulWidget {
  final String currentRoute;
  final VoidCallback? onNavigated;
  const AppSidebar({super.key, required this.currentRoute, this.onNavigated});

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  List<ChatSession> _todaySessions = [];
  List<ChatSession> _olderSessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    final all = StorageService.getAllSessions();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));

    _todaySessions = all.where((s) => s.updatedAt.isAfter(today)).toList();
    _olderSessions = all
        .where((s) => s.updatedAt.isBefore(today) && s.updatedAt.isAfter(weekAgo))
        .toList();
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant AppSidebar old) {
    super.didUpdateWidget(old);
    _loadSessions();
  }

  void _newChat(BuildContext context) {
    ref.read(chatProvider.notifier).clearChat();
    if (widget.currentRoute != '/') {
      context.go('/');
    }
    widget.onNavigated?.call();
  }

  void _openSession(BuildContext context, ChatSession session) async {
    ref.read(chatProvider.notifier).loadSession(session.id);
    if (!context.mounted) return;
    if (widget.currentRoute != '/') {
      context.go('/');
    }
    widget.onNavigated?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to chatProvider changes and reload sessions only when necessary
    // Avoids expensive Hive reads on every frame rebuild
    ref.listen(chatProvider, (previous, next) {
      if (previous?.id != next.id || previous?.messages.length != next.messages.length || (!previous!.isLoading && next.isLoading)) {
        _loadSessions();
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = isDark ? AppTheme.darkSidebar : const Color(0xFFF8F6F2);
    final sidebarBorder = isDark ? AppTheme.darkSidebarBorder : const Color(0xFFE8E4DE);
    final hoverColor = isDark ? const Color(0xFF252525) : const Color(0xFFEDE9E3);
    final textPri = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final textSec = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final textTer = isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: sidebarBorder, width: 1)),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Brand Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 12, 8),
            child: Row(
              children: [
                const Text('🌿', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('DeepTutor', style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: textPri, letterSpacing: -0.3,
                  )),
                ),
                IconButton(
                  icon: Icon(Icons.edit_square, size: 18, color: textTer),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _newChat(context),
                  tooltip: 'New Chat',
                ),
              ],
            ),
          ),

          // ── + New Chat ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: InkWell(
              onTap: () => _newChat(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 18, color: textSec),
                    const SizedBox(width: 10),
                    Text('New chat', style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: textSec,
                    )),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // ── Module Navigation ──
          _buildNavItem(context, 'Chat', Icons.chat_bubble_outline_rounded, '/', textPri, textSec, hoverColor),
          _buildNavItem(context, 'Deep Solve', Icons.psychology_outlined, '/solver', textPri, textSec, hoverColor),
          _buildNavItem(context, 'Quiz Gen', Icons.quiz_outlined, '/questions', textPri, textSec, hoverColor),
          _buildNavItem(context, 'Deep Research', Icons.biotech_outlined, '/research', textPri, textSec, hoverColor),

          // ── Chat History ──
          if (_todaySessions.isNotEmpty) ...[
            _buildSectionLabel('TODAY', textTer),
            ..._todaySessions.take(5).map((s) => _buildSessionItem(context, s, textPri, textSec, textTer, hoverColor)),
          ],
          if (_olderSessions.isNotEmpty) ...[
            _buildSectionLabel('LAST 7 DAYS', textTer),
            ..._olderSessions.take(5).map((s) => _buildSessionItem(context, s, textPri, textSec, textTer, hoverColor)),
          ],

          // ── Bottom Links ──
          Divider(color: sidebarBorder, height: 1),
          const SizedBox(height: 8),
          _buildNavItem(context, 'Knowledge', Icons.library_books_outlined, '/knowledge', textPri, textSec, hoverColor),
          _buildNavItem(context, 'Study Planner', Icons.checklist_rounded, '/todo', textPri, textSec, hoverColor),
          _buildNavItem(context, 'Exam Predict', Icons.insights_rounded, '/predict', textPri, textSec, hoverColor),

          Divider(color: sidebarBorder, height: 1),

          // ── Settings + Dark Mode + Language ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _buildNavItem(context, 'Settings', Icons.settings_outlined, '/settings', textPri, textSec, hoverColor),
                ),
                const LanguageSelector(),
                IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    size: 18,
                    color: textSec,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => ref.read(settingsProvider.notifier).toggleDarkMode(),
                  tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          
          // ── Donate Button ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: InkWell(
              onTap: () => _showDonateDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  children: [
                    const Icon(Icons.favorite_rounded, size: 18, color: Colors.pinkAccent),
                    const SizedBox(width: 10),
                    const Text('Donate', style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.pinkAccent,
                    )),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showDonateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.volunteer_activism_rounded, color: Colors.pinkAccent),
            SizedBox(width: 10),
            Text('Support DeepTutor'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thank you for using DeepTutor! If you find this app helpful, '
              'you can support the continued development to help us build more features.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.pinkAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Colors.pinkAccent, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bkash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.pinkAccent)),
                        Text('01710976003', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFCD535).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCD535).withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.currency_bitcoin_rounded, color: Color(0xFFF3BA2F), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Binance Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF3BA2F))),
                        Text('koushikahmed104@gmail.com', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 12, 4),
      child: Text(label, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: color, letterSpacing: 0.5,
      )),
    );
  }

  Widget _buildNavItem(BuildContext context, String label, IconData icon, String route,
      Color textPri, Color textSec, Color hoverColor) {
    final isActive = widget.currentRoute == route;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: InkWell(
        onTap: () {
          if (widget.currentRoute != route) context.go(route);
          widget.onNavigated?.call();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isActive ? hoverColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isActive ? textPri : textSec),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? textPri : textSec,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionItem(BuildContext context, ChatSession session,
      Color textPri, Color textSec, Color textTer, Color hoverColor) {
    final activeId = StorageService.getActiveSessionId();
    final isActive = session.id == activeId && widget.currentRoute == '/';
    final title = session.title.replaceAll('\n', ' ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: InkWell(
        onTap: () => _openSession(context, session),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? hoverColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? AppTheme.accentGreen : textTer.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? textPri : textSec,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
