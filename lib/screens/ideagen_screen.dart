import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../config/app_theme.dart';
import '../providers/api_provider.dart';
import '../services/pdf_export_service.dart';

class IdeagenScreen extends ConsumerStatefulWidget {
  const IdeagenScreen({super.key});

  @override
  ConsumerState<IdeagenScreen> createState() => _IdeagenScreenState();
}

class _IdeagenScreenState extends ConsumerState<IdeagenScreen> {
  final _topicController = TextEditingController();
  final _contextController = TextEditingController();
  bool _isGenerating = false;
  bool _isExporting = false;
  String _result = '';

  @override
  void dispose() {
    _topicController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _generateIdeas() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _result = '';
    });

    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.generateIdeas(
        topic: topic,
        context: _contextController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _result = result;
          _isGenerating = false;
        });
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _downloadResult() async {
    if (_result.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final topic = _topicController.text.trim();
      final path = await PdfExportService.exportAsFile(
        title: 'Ideas_${topic.isEmpty ? "Generated" : topic}',
        content: _result,
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

  void _copyResult() {
    if (_result.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _result));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Idea Generator'),
        actions: [
          if (_result.isNotEmpty) ...[
            IconButton(
              onPressed: _copyResult,
              icon: const Icon(Icons.copy_rounded, color: AppTheme.accentCyan),
              tooltip: 'Copy all',
            ),
            IconButton(
              onPressed: _isExporting ? null : _downloadResult,
              icon: _isExporting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.accentGreen),
                    )
                  : const Icon(Icons.download_rounded,
                      color: AppTheme.accentGreen),
              tooltip: 'Download PDF',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _topicController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter topic for brainstorming...',
                    prefixIcon: const Icon(Icons.lightbulb_rounded,
                        color: AppTheme.textTertiary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contextController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Additional context (optional)...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateIdeas,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentPink,
                    ),
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                        _isGenerating ? 'Generating...' : 'Generate Ideas'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _result.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lightbulb_rounded,
                            size: 64,
                            color:
                                AppTheme.accentPink.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text(
                          'No ideas generated yet',
                          style: TextStyle(
                              color: AppTheme.textTertiary, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter a topic and let AI brainstorm',
                          style: TextStyle(
                              color: AppTheme.textTertiary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : SelectionArea(
                    child: Markdown(
                      data: _result,
                      selectable: true,
                      padding: const EdgeInsets.all(16),
                      styleSheet: AppTheme.markdownStyle,
                    ).animate().fadeIn(duration: 400.ms),
                  ),
          ),
        ],
      ),
    );
  }
}
