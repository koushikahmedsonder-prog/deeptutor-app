import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/app_theme.dart';
import '../utils/theme_helper.dart';
import '../providers/solver_provider.dart';

import '../providers/knowledge_provider.dart';
import '../providers/api_provider.dart';
import '../services/document_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/language_selector.dart';
import '../widgets/export_sheet.dart';
class SolverScreen extends ConsumerStatefulWidget {
  const SolverScreen({super.key});

  @override
  ConsumerState<SolverScreen> createState() => _SolverScreenState();
}

class _SolverScreenState extends ConsumerState<SolverScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _docService = DocumentService();
  bool _useWebSearch = true;
  PickedDocument? _attachment;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickFile() async {
    final doc = await _docService.pickDocument();
    if (doc != null) {
      setState(() => _attachment = doc);
    }
  }

  Future<void> _takePhoto() async {
    final doc = await _docService.takePhoto();
    if (doc != null) {
      setState(() => _attachment = doc);
    }
  }

  void _removeAttachment() => setState(() => _attachment = null);

  void _showAttachOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentIndigo.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.file_open_rounded, color: AppTheme.accentIndigo),
                ),
                title: Text('Upload File', style: TextStyle(color: context.textPri)),
                subtitle: Text('PDF, Doc, TXT, Image', style: TextStyle(color: context.textTer, fontSize: 12)),
                onTap: () { Navigator.pop(ctx); _pickFile(); },
              ),
              if (_docService.isCameraAvailable)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.camera_alt_rounded, color: AppTheme.accentCyan),
                  ),
                  title: Text('Take Photo', style: TextStyle(color: context.textPri)),
                  subtitle: Text('Capture with camera', style: TextStyle(color: context.textTer, fontSize: 12)),
                  onTap: () { Navigator.pop(ctx); _takePhoto(); },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachment == null) return;

    final kb = ref.read(knowledgeProvider).selectedKb;
    final useSearch = _useWebSearch;
    final attachment = _attachment;

    final promptText = text.isNotEmpty ? text : 'Analyze this ${attachment?.name ?? "file"}';

    ref.read(solverProvider.notifier).sendSolverQuestion(
      promptText,
      kbName: kb,
      attachment: attachment,
      useWebSearch: useSearch,
    );
    _controller.clear();
    setState(() => _attachment = null);
    _scrollToBottom();
  }



  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(solverProvider);
    final kbState = ref.watch(knowledgeProvider);

    if (chatState.messages.isNotEmpty) {
      _scrollToBottom();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;

    final textTer = isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.surface;
    final borderColor = isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder;
    final scaffoldBg = isDark ? AppTheme.darkPrimary : AppTheme.primary;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Column(
        children: [
          // ── Header Bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: [
                Icon(Icons.psychology_rounded, size: 22, color: AppTheme.accentViolet),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Deep Solve',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textPri),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const LanguageSelector(),
                if (chatState.messages.isNotEmpty) ...[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final buffer = StringBuffer();
                      for (final msg in chatState.messages) {
                        buffer.writeln(msg.isUser ? 'You: ${msg.content}' : 'AI: ${msg.content}');
                        buffer.writeln();
                      }
                      Clipboard.setData(ClipboardData(text: buffer.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('📋 Copied to clipboard'), duration: Duration(seconds: 2)),
                      );
                    },
                    icon: Icon(Icons.copy_rounded, color: AppTheme.accentCyan, size: 20),
                    tooltip: 'Copy all',
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.auto_awesome_rounded, color: AppTheme.accentGreen, size: 20),
                    tooltip: 'Export AI Assets',
                    onPressed: () {
                      final buffer = StringBuffer();
                      for (final msg in chatState.messages) {
                        buffer.writeln(msg.isUser ? '## You\n' : '## AI Solver\n');
                        buffer.writeln(msg.content);
                        buffer.writeln('\n---\n');
                      }
                      showExportSheet(context, ref.read(apiServiceProvider), 'Deep Solve Session', buffer.toString());
                    },
                  ),
                ],
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: textTer),
                  onPressed: () => ref.read(solverProvider.notifier).clearChat(),
                  tooltip: 'Clear',
                ),
              ],
            ),
          ),
          // KB Selector
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.cardBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: Text(
                  kbState.knowledgeBases.isEmpty
                      ? 'No KBs yet — ask general questions'
                      : 'Select Knowledge Base (optional)',
                  style: TextStyle(color: context.textTer),
                ),
                value: (kbState.selectedKb != null && kbState.knowledgeBases.any((kb) => kb['name']?.toString() == kbState.selectedKb)) 
                    ? kbState.selectedKb 
                    : null,
                dropdownColor: context.surfaceColor,
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text('None (General mode)',
                        style: TextStyle(color: context.textSec)),
                  ),
                  ...kbState.knowledgeBases.fold<Map<String, Map<String, dynamic>>>({}, (map, kb) {
                    final name = kb['name']?.toString() ?? 'Unknown';
                    // Deduplicate by name to prevent "2 or more items" error
                    if (!map.containsKey(name)) {
                      map[name] = kb;
                    }
                    return map;
                  }).values.map((kb) {
                    final name = kb['name']?.toString() ?? 'Unknown';
                    final docCount = kb['doc_count'] ?? 0;
                    return DropdownMenuItem(
                      value: name,
                      child: Row(
                        children: [
                          Icon(Icons.folder_rounded, size: 16, color: AppTheme.accentViolet),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(name, style: TextStyle(color: context.textPri)),
                          ),
                          Text('$docCount docs', style: TextStyle(color: context.textTer, fontSize: 12)),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (val) => ref.read(knowledgeProvider.notifier).selectKnowledgeBase(val),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms),

          // Messages
          Expanded(
            child: chatState.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.psychology_rounded, size: 64,
                            color: AppTheme.accentIndigo.withValues(alpha: 0.3)),
                        SizedBox(height: 16),
                        Text('Ask a question to get started',
                          style: TextStyle(color: context.textTer, fontSize: 16)),
                        SizedBox(height: 8),
                        Text(
                          kbState.knowledgeBases.isEmpty
                              ? 'You can ask general questions, or create a KB first'
                              : 'Select a Knowledge Base for context-aware answers',
                          style: TextStyle(color: context.textTer, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ).animate().fadeIn(duration: 600.ms),
                  )
                : SelectionArea(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: 8),
                      itemCount: chatState.messages.length,
                      itemBuilder: (context, index) {
                        final msg = chatState.messages[index];
                        return ChatBubble(message: msg, index: index);
                      },
                    ),
                  ),
          ),

          // Attachment preview
          if (_attachment != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accentIndigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentIndigo.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  if (_attachment!.type == DocumentType.image && _attachment!.bytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_attachment!.bytes!, width: 40, height: 40, fit: BoxFit.cover),
                    )
                  else
                    Text(_attachment!.icon, style: TextStyle(fontSize: 24)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_attachment!.name,
                          style: TextStyle(color: context.textPri, fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(_attachment!.sizeFormatted,
                          style: TextStyle(color: context.textTer, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: context.textSec),
                    onPressed: _removeAttachment,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.3, end: 0),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(top: BorderSide(color: context.cardBorder)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Attach button
                  Tooltip(
                    message: 'Attach File',
                    child: GestureDetector(
                      onTap: _showAttachOptions,
                      child: Container(
                        width: 44, height: 44,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _attachment != null
                              ? AppTheme.accentIndigo.withValues(alpha: 0.15)
                              : context.surfaceColor,
                          border: Border.all(
                            color: _attachment != null
                                ? AppTheme.accentIndigo.withValues(alpha: 0.5)
                                : AppTheme.cardBorder,
                          ),
                        ),
                        child: Icon(
                          Icons.attach_file_rounded,
                          color: _attachment != null ? AppTheme.accentIndigo : AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  // Web search toggle
                  Tooltip(
                    message: 'Toggle Web Search',
                    child: GestureDetector(
                      onTap: () => setState(() => _useWebSearch = !_useWebSearch),
                      child: Container(
                        width: 44, height: 44,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _useWebSearch ? AppTheme.accentCyan.withValues(alpha: 0.15) : context.surfaceColor,
                          border: Border.all(
                            color: _useWebSearch ? AppTheme.accentCyan.withValues(alpha: 0.5) : AppTheme.cardBorder,
                          ),
                        ),
                        child: Icon(
                          Icons.travel_explore_rounded,
                          color: _useWebSearch ? AppTheme.accentCyan : AppTheme.textSecondary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 3,
                      minLines: 1,
                      style: TextStyle(color: context.textPri),
                      decoration: InputDecoration(
                        filled: true, fillColor: context.scaffoldBg, hintText: _attachment != null ? 'Ask about this file...' : 'Ask a question...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: context.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: context.cardBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: chatState.isLoading ? null : _sendMessage,
                      icon: chatState.isLoading
                          ? SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: context.textPri),
                            )
                          : Icon(Icons.send_rounded, color: context.textPri),
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
}
