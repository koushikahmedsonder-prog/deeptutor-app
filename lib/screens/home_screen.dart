import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_theme.dart';
import '../config/models_config.dart';
import '../providers/chat_provider.dart';
import '../services/document_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/language_selector.dart';
import '../widgets/export_sheet.dart';
import '../providers/api_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  PickedDocument? _attachment;
  bool _useWebSearch = true;
  bool _useCode = false;
  bool _useReason = false;
  LLMModel? _selectedModel;

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
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

  void _makeExport(String label) {
    final text = _messageController.text.trim();
    final chatState = ref.read(chatProvider);

    if (text.isNotEmpty) {
      // Use typed text as the topic for generation
      showExportSheet(context, ref.read(apiServiceProvider), text, text);
    } else if (chatState.messages.isNotEmpty) {
      // Use existing chat history
      final buffer = StringBuffer();
      buffer.writeln('# Chat Transcript\n');
      for (final m in chatState.messages) {
        buffer.writeln(m.isUser ? '## You:' : '## AI:');
        buffer.writeln('${m.content}\n---');
      }
      showExportSheet(context, ref.read(apiServiceProvider), 'Chat - $label', buffer.toString());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type a topic first or start a chat!')),
      );
    }
  }

  void _handleSend() {
    final text = _messageController.text.trim();
    if (text.isEmpty && _attachment == null) return;

    final attachment = _attachment;
    _messageController.clear();
    setState(() => _attachment = null);

    ref.read(chatProvider.notifier).sendGeneralQuestion(
      text.isEmpty ? "Explain this document" : text,
      attachment: attachment,
      useWebSearch: _useWebSearch,
      useCode: _useCode,
      useReason: _useReason,
      modelOverride: _selectedModel,
    );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final isChatActive = chatState.messages.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Theme-aware colors
    final scaffoldBg = isDark ? AppTheme.darkPrimary : AppTheme.primary;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.surface;
    final borderColor = isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder;
    final textPri = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final textSec = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final textTer = isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary;
    final chipBg = isDark ? const Color(0xFF262626) : const Color(0xFFF3F4F6);

    if (isChatActive) {
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // ── Main Content Area ──
          if (!isChatActive)
            Center(
              child: Padding(
                // Push text into visual center, accounting for the
                // floating input bar (~120px) at the bottom
                padding: const EdgeInsets.only(bottom: 120),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Ask anything — I\'m here to help you understand.',
                    style: TextStyle(
                      fontSize: 18,
                      color: textTer,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 600.ms),
                ),
              ),
            )
          else
            Column(
              children: [
                // ── Chat Header Bar ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: borderColor, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Spacer(),
                      const LanguageSelector(),
                      IconButton(
                        icon: Icon(Icons.clear_all_rounded, size: 20, color: textTer),
                        onPressed: () => ref.read(chatProvider.notifier).clearChat(),
                        tooltip: 'Clear Chat',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.only(left: isMobile ? 8 : 24, right: isMobile ? 8 : 24, top: 16, bottom: 130),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      return ChatBubble(message: chatState.messages[index], index: index);
                    },
                  ),
                ),
              ],
            ),

          // ── Bottom Input Area ──
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: EdgeInsets.fromLTRB(isMobile ? 12 : 24, 0, isMobile ? 12 : 24, isMobile ? 12 : 24),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_attachment != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 12, right: 12, bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: scaffoldBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_attachment!.icon, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 150),
                                  child: Text(_attachment!.name, 
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textPri)),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => setState(() => _attachment = null),
                                  child: Icon(Icons.close_rounded, size: 16, color: textTer),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Text Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      style: TextStyle(color: textPri, fontSize: 16),
                      maxLines: 5,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      decoration: InputDecoration(
                        hintText: 'How can I help you today?',
                        hintStyle: TextStyle(color: textTer, fontSize: 16),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  
                  // Bottom Toolbar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Row(
                      children: [
                        // Chat Model Selector
                        PopupMenuButton<LLMModel?>(
                          initialValue: _selectedModel,
                          tooltip: 'Select AI Model',
                          offset: const Offset(0, -300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: surfaceColor,
                          onSelected: (LLMModel? model) {
                            setState(() {
                              _selectedModel = model;
                            });
                          },
                          itemBuilder: (BuildContext context) {
                            return [
                              PopupMenuItem<LLMModel?>(
                                value: null,
                                child: Text('Auto (Default)', style: TextStyle(color: textPri)),
                              ),
                              const PopupMenuDivider(),
                              ...availableModels.map((model) => PopupMenuItem<LLMModel?>(
                                    value: model,
                                    child: Row(
                                      children: [
                                        Text(model.providerName, style: TextStyle(color: textSec, fontSize: 12, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        Flexible(child: Text(model.name, style: TextStyle(color: textPri), overflow: TextOverflow.ellipsis)),
                                        if (model.isFree) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.star, size: 12, color: AppTheme.accentOrange),
                                        ],
                                      ],
                                    ),
                                  )),
                            ];
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: chipBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, size: 14, color: textSec),
                                const SizedBox(width: 6),
                                Text(_selectedModel?.name ?? 'Chat', style: TextStyle(color: textSec, fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(width: 2),
                                Icon(Icons.keyboard_arrow_up_rounded, size: 14, color: textSec),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Feature pills — use Expanded + Wrap to prevent overflow on mobile
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildToolPill('Web', _useWebSearch, () => setState(() => _useWebSearch = !_useWebSearch), textTer),
                                const SizedBox(width: 6),
                                _buildToolPill('Code', _useCode, () => setState(() => _useCode = !_useCode), textTer),
                                const SizedBox(width: 6),
                                _buildToolPill('Reason', _useReason, () => setState(() => _useReason = !_useReason), textTer),
                                const SizedBox(width: 6),
                                _buildToolPill('PPTX', false, () => _makeExport('PPTX'), textTer, isAction: true),
                                const SizedBox(width: 6),
                                _buildToolPill('Slides', false, () => _makeExport('Slides'), textTer, isAction: true),
                                const SizedBox(width: 6),
                                _buildToolPill('Mind Map', false, () => _makeExport('Mind Map'), textTer, isAction: true),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Send Button
                        GestureDetector(
                          onTap: _handleSend,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.accentOrange.withValues(alpha: 0.15),
                            ),
                            child: const Icon(
                              Icons.arrow_upward_rounded,
                              color: AppTheme.accentOrange,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolPill(String label, bool isActive, VoidCallback onTap, Color inactiveColor, {bool isAction = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accentIndigo.withValues(alpha: 0.1) : (isAction ? AppTheme.accentOrange.withValues(alpha: 0.05) : Colors.transparent),
          borderRadius: BorderRadius.circular(4),
          border: isAction ? Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.3)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppTheme.accentIndigo : (isAction ? AppTheme.accentOrange : inactiveColor),
            fontSize: 13,
            fontWeight: (isActive || isAction) ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
