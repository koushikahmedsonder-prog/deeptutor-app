import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_theme.dart';
import '../config/models_config.dart';
import '../providers/settings_provider.dart';
import '../providers/chat_provider.dart';
import '../services/document_service.dart';
import '../widgets/antigravity_card.dart';
import '../widgets/particle_background.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/camera_capture_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _isListening = false;
  bool _useWebSearch = true; // Web Search is now ON by default
  PickedDocument? _attachment;
  late AnimationController _micPulseController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _micPulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleVoiceInput() {
    setState(() {
      _isListening = !_isListening;
    });
    if (_isListening) {
      _micPulseController.repeat(reverse: true);
      HapticFeedback.mediumImpact();
      // TODO: Integrate speech_to_text package
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🎤 Voice input — coming soon!'),
          backgroundColor: AppTheme.cardDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isListening = false);
          _micPulseController.stop();
          _micPulseController.reset();
        }
      });
    } else {
      _micPulseController.stop();
      _micPulseController.reset();
    }
  }

  void _removeAttachment() {
    setState(() => _attachment = null);
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Add Attachment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Photo',
                  color: AppTheme.accentGreen,
                  onTap: () async {
                    Navigator.pop(context);
                    final doc = await DocumentService().pickImage();
                    if (doc != null && mounted) {
                      setState(() => _attachment = doc);
                    }
                  },
                ),
                _buildAttachOption(
                  icon: Icons.description_rounded,
                  label: 'Document',
                  color: AppTheme.accentIndigo,
                  onTap: () async {
                    Navigator.pop(context);
                    final doc = await DocumentService().pickDocument();
                    if (doc != null && mounted) {
                      setState(() => _attachment = doc);
                    }
                  },
                ),
                _buildAttachOption(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'PDF',
                  color: AppTheme.accentOrange,
                  onTap: () async {
                    Navigator.pop(context);
                    final doc = await DocumentService().pickDocument();
                    if (doc != null && mounted) {
                      setState(() => _attachment = doc);
                    }
                  },
                ),
                _buildAttachOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: AppTheme.accentCyan,
                  onTap: () async {
                    Navigator.pop(context);
                    final doc = await showCameraCapture(context);
                    if (doc != null && mounted) setState(() => _attachment = doc);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showModelChooser() {
    final settings = ref.read(settingsProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.smart_toy_rounded,
                        color: AppTheme.accentIndigo, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Choose Model',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: availableModels.length,
                  itemBuilder: (context, index) {
                    final model = availableModels[index];
                    final isSelected =
                        index == settings.selectedModelIndex;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () {
                          ref
                              .read(settingsProvider.notifier)
                              .setModel(index);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: isSelected
                                ? AppTheme.accentIndigo
                                    .withValues(alpha: 0.15)
                                : AppTheme.cardDark,
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.accentIndigo
                                      .withValues(alpha: 0.5)
                                  : AppTheme.cardBorder,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  color: _getProviderColor(
                                          model.provider)
                                      .withValues(alpha: 0.15),
                                ),
                                child: Icon(
                                  _getProviderIcon(model.provider),
                                  color: _getProviderColor(
                                      model.provider),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      model.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? AppTheme.accentIndigo
                                            : AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      model.description,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.accentIndigo,
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getProviderColor(AIProvider provider) {
    return switch (provider) {
      AIProvider.gemini => AppTheme.accentCyan,
      AIProvider.openai => AppTheme.accentGreen,
      AIProvider.anthropic => AppTheme.accentOrange,
      AIProvider.deepseek => AppTheme.accentIndigo,
      AIProvider.groq => AppTheme.accentPink,
    };
  }

  IconData _getProviderIcon(AIProvider provider) {
    return switch (provider) {
      AIProvider.gemini => Icons.auto_awesome_rounded,
      AIProvider.openai => Icons.bolt_rounded,
      AIProvider.anthropic => Icons.psychology_rounded,
      AIProvider.deepseek => Icons.water_drop_rounded,
      AIProvider.groq => Icons.speed_rounded,
    };
  }

  void _handleSend() {
    final text = _messageController.text.trim();
    if (text.isEmpty && _attachment == null) return;

    final attachment = _attachment;
    final useSearch = _useWebSearch;
    _messageController.clear();
    setState(() {
      _attachment = null;
      // Web search state left unchanged so it remains toggled ON/OFF
    });

    // Stay on Home screen and let it turn into a chat terminal
    ref.read(chatProvider.notifier).sendGeneralQuestion(
      text.isEmpty ? "Explain this document/image" : text,
      attachment: attachment,
      useWebSearch: useSearch,
    );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final chatState = ref.watch(chatProvider);
    final currentModel = settings.selectedModel;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (chatState.messages.isNotEmpty) {
      _scrollToBottom();
    }

    final modules = [
      _ModuleData(
        title: 'AI Solver',
        subtitle: 'Ask questions, get answers',
        icon: Icons.psychology_rounded,
        color: AppTheme.accentIndigo,
        route: '/solver',
      ),
      _ModuleData(
        title: 'Knowledge Base',
        subtitle: 'Upload & manage docs',
        icon: Icons.library_books_rounded,
        color: AppTheme.accentViolet,
        route: '/knowledge',
      ),
      _ModuleData(
        title: 'Scan Document',
        subtitle: 'Camera & file upload',
        icon: Icons.document_scanner_rounded,
        color: AppTheme.accentCyan,
        route: '/camera',
      ),
      _ModuleData(
        title: 'Question Gen',
        subtitle: 'Generate practice quizzes',
        icon: Icons.quiz_rounded,
        color: AppTheme.accentGreen,
        route: '/questions',
      ),
      _ModuleData(
        title: 'Deep Research',
        subtitle: 'In-depth exploration',
        icon: Icons.biotech_rounded,
        color: AppTheme.accentOrange,
        route: '/research',
      ),
      _ModuleData(
        title: 'Idea Generator',
        subtitle: 'Brainstorm concepts',
        icon: Icons.lightbulb_rounded,
        color: AppTheme.accentPink,
        route: '/ideagen',
      ),
      _ModuleData(
        title: 'Notebook',
        subtitle: 'Saved notes & sessions',
        icon: Icons.note_alt_rounded,
        color: const Color(0xFF26C6DA),
        route: '/notebook',
      ),
      _ModuleData(
        title: 'Study Planner',
        subtitle: 'Tasks, Qs & progress',
        icon: Icons.checklist_rounded,
        color: AppTheme.accentPink,
        route: '/todo',
      ),
      _ModuleData(
        title: 'Settings',
        subtitle: 'API keys & config',
        icon: Icons.settings_rounded,
        color: AppTheme.textSecondary,
        route: '/settings',
      ),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: ParticleBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Chat Header ──
              if (chatState.messages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => ref.read(chatProvider.notifier).clearChat(),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: AppTheme.accentCyan, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'DeepTutor AI',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear_all_rounded, color: AppTheme.accentPink),
                        tooltip: 'Clear Chat',
                        onPressed: () => ref.read(chatProvider.notifier).clearChat(),
                      ),
                    ],
                  ),
                ),

              // ── Scrollable content ──
              Expanded(
                child: chatState.messages.isEmpty
                  ? CustomScrollView(
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DeepTutor',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  'AI-Powered Learning Assistant',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .slideX(begin: -0.1, end: 0, duration: 600.ms),
                      ),
                    ),

                    // Module Grid
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 1.3,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final m = modules[index];
                            return AntigravityCard(
                              title: m.title,
                              subtitle: m.subtitle,
                              icon: m.icon,
                              accentColor: m.color,
                              index: index,
                              onTap: () => context.push(m.route),
                            );
                          },
                          childCount: modules.length,
                        ),
                      ),
                    ),
                  ]
                )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      return ChatBubble(message: chatState.messages[index], index: index);
                    },
                  ),
              ),

              // ── Bottom Input Bar ──
              Container(
                padding: EdgeInsets.fromLTRB(
                  12, 10, 12, bottomPadding + 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark.withValues(alpha: 0.95),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Attachment Preview
                    if (_attachment != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8, left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _attachment!.icon,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _attachment!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _removeAttachment,
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.2, end: 0),
                    ],
                    // Input row
                    Row(
                      children: [
                        // Attach button (+)
                        _InputBarButton(
                          icon: Icons.add_rounded,
                          onTap: _showAttachmentOptions,
                          tooltip: 'Add attachment',
                        ),
                        const SizedBox(width: 4),

                        // Camera button — opens live camera preview on all platforms
                        _InputBarButton(
                          icon: Icons.camera_alt_rounded,
                          onTap: () async {
                            final doc = await showCameraCapture(context);
                            if (doc != null && mounted) {
                              setState(() => _attachment = doc);
                            }
                          },
                          tooltip: 'Take Photo',
                        ),
                        const SizedBox(width: 4),

                        // Web Search Tool indicator
                        _InputBarButton(
                          icon: Icons.travel_explore_rounded,
                          isActive: _useWebSearch,
                          onTap: () {
                            setState(() {
                              _useWebSearch = !_useWebSearch;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_useWebSearch ? '🌐 Web Search Enabled' : '🌐 Web Search Disabled'),
                                backgroundColor: _useWebSearch ? AppTheme.accentCyan : AppTheme.surfaceDark,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            _messageFocusNode.requestFocus();
                          },
                          tooltip: 'Toggle Web Search',
                        ),
                        const SizedBox(width: 4),

                        // Text Input
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.cardDark,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppTheme.cardBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    focusNode: _messageFocusNode,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Ask anything...',
                                      hintStyle: TextStyle(
                                        color: AppTheme.textTertiary,
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      isDense: true,
                                    ),
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _handleSend(),
                                  ),
                                ),

                                // Voice input button
                                GestureDetector(
                                  onTap: _toggleVoiceInput,
                                  child: AnimatedBuilder(
                                    animation: _micPulseController,
                                    builder: (context, child) {
                                      return Container(
                                        margin:
                                            const EdgeInsets.only(right: 4),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _isListening
                                              ? AppTheme.accentPink
                                                  .withValues(
                                                    alpha: 0.15 +
                                                        _micPulseController
                                                                .value *
                                                            0.15,
                                                  )
                                              : Colors.transparent,
                                        ),
                                        child: Icon(
                                          _isListening
                                              ? Icons.mic_rounded
                                              : Icons.mic_none_rounded,
                                          color: _isListening
                                              ? AppTheme.accentPink
                                              : AppTheme.textTertiary,
                                          size: 20,
                                        ),
                                      );
                                    },
                                  ),
                                ),

                                // Send button
                                GestureDetector(
                                  onTap: _handleSend,
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: AppTheme.primaryGradient,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_upward_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Model chooser bar
                    GestureDetector(
                      onTap: _showModelChooser,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: AppTheme.cardDark,
                          border: Border.all(
                            color: _getProviderColor(currentModel.provider)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getProviderIcon(currentModel.provider),
                              color:
                                  _getProviderColor(currentModel.provider),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              currentModel.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _getProviderColor(
                                    currentModel.provider),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color:
                                  _getProviderColor(currentModel.provider),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    )
                        .animate(delay: 500.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.3, end: 0),
                  ],
                ),
              )
                  .animate(delay: 400.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.5, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small circular button for the input bar ──
class _InputBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool isActive;

  const _InputBarButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppTheme.accentCyan.withValues(alpha: 0.15) : AppTheme.cardDark,
            border: Border.all(
              color: isActive ? AppTheme.accentCyan.withValues(alpha: 0.5) : AppTheme.cardBorder,
            ),
          ),
          child: Icon(
            icon, 
            color: isActive ? AppTheme.accentCyan : AppTheme.textSecondary, 
            size: 16,
          ),
        ),
      ),
    );
  }
}

class _ModuleData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const _ModuleData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}
