import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/app_theme.dart';
import '../providers/chat_provider.dart';
import '../providers/knowledge_provider.dart';
import '../services/document_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/chat_bubble.dart';

class SolverScreen extends ConsumerStatefulWidget {
  const SolverScreen({super.key});

  @override
  ConsumerState<SolverScreen> createState() => _SolverScreenState();
}

class _SolverScreenState extends ConsumerState<SolverScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _docService = DocumentService();
  bool _isExporting = false;
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
          duration: const Duration(milliseconds: 300),
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
      backgroundColor: AppTheme.surfaceDark,
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
                  child: const Icon(Icons.file_open_rounded, color: AppTheme.accentIndigo),
                ),
                title: const Text('Upload File', style: TextStyle(color: AppTheme.textPrimary)),
                subtitle: const Text('PDF, Doc, TXT, Image', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
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
                    child: const Icon(Icons.camera_alt_rounded, color: AppTheme.accentCyan),
                  ),
                  title: const Text('Take Photo', style: TextStyle(color: AppTheme.textPrimary)),
                  subtitle: const Text('Capture with camera', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
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

    if (kb == null || kb.isEmpty) {
      ref.read(chatProvider.notifier).sendGeneralQuestion(promptText, attachment: attachment, useWebSearch: useSearch);
    } else {
      ref.read(chatProvider.notifier).sendQuestion(kb, promptText, attachment: attachment, useWebSearch: useSearch);
    }
    _controller.clear();
    setState(() => _attachment = null);
    _scrollToBottom();
  }

  Future<void> _downloadChat() async {
    final chatState = ref.read(chatProvider);
    if (chatState.messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messages to download')),
      );
      return;
    }

    setState(() => _isExporting = true);

    final buffer = StringBuffer();
    for (final msg in chatState.messages) {
      if (msg.isUser) {
        buffer.writeln('## 🧑 You\n');
        buffer.writeln(msg.content);
        buffer.writeln();
      } else {
        buffer.writeln('## 🤖 AI Solver\n');
        buffer.writeln(msg.content);
        buffer.writeln();
      }
      buffer.writeln('---\n');
    }

    try {
      final path = await PdfExportService.exportAsFile(
        title: 'AI_Solver_Chat',
        content: buffer.toString(),
      );

      if (mounted) {
        setState(() => _isExporting = false);
        if (path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ PDF saved: $path'),
              backgroundColor: Colors.green.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Could not save file')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final kbState = ref.watch(knowledgeProvider);

    if (chatState.messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Solver'),
        actions: [
          if (chatState.messages.isNotEmpty)
            IconButton(
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
              icon: const Icon(Icons.copy_rounded, color: AppTheme.accentCyan),
              tooltip: 'Copy all',
            ),
          if (chatState.messages.isNotEmpty)
            IconButton(
              onPressed: _isExporting ? null : _downloadChat,
              icon: _isExporting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentGreen),
                    )
                  : const Icon(Icons.download_rounded, color: AppTheme.accentGreen),
              tooltip: 'Download chat',
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => ref.read(chatProvider.notifier).clearChat(),
          ),
        ],
      ),
      body: Column(
        children: [
          // KB Selector
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: Text(
                  kbState.knowledgeBases.isEmpty
                      ? 'No KBs yet — ask general questions'
                      : 'Select Knowledge Base (optional)',
                  style: const TextStyle(color: AppTheme.textTertiary),
                ),
                value: kbState.selectedKb,
                dropdownColor: AppTheme.surfaceDark,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('None (General mode)',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  ...kbState.knowledgeBases.map((kb) {
                    final name = kb['name']?.toString() ?? 'Unknown';
                    final docCount = kb['doc_count'] ?? 0;
                    return DropdownMenuItem(
                      value: name,
                      child: Row(
                        children: [
                          const Icon(Icons.folder_rounded, size: 16, color: AppTheme.accentViolet),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(name, style: const TextStyle(color: AppTheme.textPrimary)),
                          ),
                          Text('$docCount docs', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
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
                        const SizedBox(height: 16),
                        const Text('Ask a question to get started',
                          style: TextStyle(color: AppTheme.textTertiary, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          kbState.knowledgeBases.isEmpty
                              ? 'You can ask general questions, or create a KB first'
                              : 'Select a Knowledge Base for context-aware answers',
                          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ).animate().fadeIn(duration: 600.ms),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatState.messages[index];
                      return ChatBubble(message: msg, index: index);
                    },
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
                    Text(_attachment!.icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_attachment!.name,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(_attachment!.sizeFormatted,
                          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                    onPressed: _removeAttachment,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.3, end: 0),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceDark,
              border: Border(top: BorderSide(color: AppTheme.cardBorder)),
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
                              : AppTheme.cardDark,
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
                          color: _useWebSearch ? AppTheme.accentCyan.withValues(alpha: 0.15) : AppTheme.cardDark,
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
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: _attachment != null ? 'Ask about this file...' : 'Ask a question...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.cardBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: chatState.isLoading ? null : _sendMessage,
                      icon: chatState.isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
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
