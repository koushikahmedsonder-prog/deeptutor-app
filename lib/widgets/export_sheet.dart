import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../services/export_service.dart';
import '../services/export_content_service.dart';
import '../utils/theme_helper.dart';

/// Show the "Export As" bottom sheet for a piece of text content.
/// Provide [title] as the document/note name and [content] as the full text.
Future<void> showExportSheet(
    BuildContext context, ApiService api, String title, String content) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ExportSheet(api: api, title: title, content: content),
  );
}

class _ExportSheet extends StatefulWidget {
  final ApiService api;
  final String title;
  final String content;

  const _ExportSheet({
    required this.api,
    required this.title,
    required this.content,
  });

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  bool _isLoading = false;
  String _loadingLabel = '';

  Future<void> _handle(String type) async {
    final ctx = context;
    setState(() {
      _isLoading = true;
      _loadingLabel = switch (type) {
        'pptx' => '📊 Building Slides...',
        'pdf' => '📄 Generating PDF...',
        'flashcards' => '🃏 Making Flashcards...',
        'mindmap' => '🧠 Mapping Ideas...',
        _ => '⏳ Working...',
      };
    });

    try {
      final aiType = type == 'pptx' ? 'slides' : type;
      final data = await ExportContentService.generateExportContent(
        content: widget.content,
        exportType: aiType,
        api: widget.api,
      );

      Navigator.of(ctx).pop();

      switch (type) {
        case 'pptx':
          await ExportService.exportAsPptx(
            title: data['title']?.toString() ?? widget.title,
            slides: ExportContentService.slidesFromJson(data),
          );
          break;
        case 'pdf':
          await ExportService.exportAsPdf(
            title: data['title']?.toString() ?? widget.title,
            slides: ExportContentService.slidesFromJson(data),
          );
          break;
        case 'flashcards':
          await ExportService.exportFlashcards(
            title: data['title']?.toString() ?? widget.title,
            flashcards: ExportContentService.flashcardsFromJson(data),
          );
          break;
        case 'mindmap':
          final mindMap = ExportContentService.mindMapFromJson(data);
          await ExportService.exportMindMap(
            title: mindMap.centralTopic,
            mindMap: mindMap,
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.textTer,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          if (_isLoading) ...[
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.accentIndigo),
                  const SizedBox(height: 16),
                  Text(_loadingLabel,
                      style: TextStyle(color: context.textPri, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('AI is structuring your content…',
                      style: TextStyle(color: context.textSec, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ] else ...[
            Text('Export "${widget.title}" As',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.textPri)),
            const SizedBox(height: 6),
            Text('AI will structure your content and generate the chosen format.',
                style: TextStyle(color: context.textSec, fontSize: 13)),
            const SizedBox(height: 20),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ExportTile(
                  icon: '📊',
                  label: 'Slides',
                  sub: 'PPTX',
                  color: Colors.orange,
                  onTap: () => _handle('pptx'),
                ),
                _ExportTile(
                  icon: '📄',
                  label: 'PDF',
                  sub: 'Report',
                  color: Colors.redAccent,
                  onTap: () => _handle('pdf'),
                ),
                _ExportTile(
                  icon: '🃏',
                  label: 'Flash',
                  sub: 'Cards',
                  color: Colors.purple,
                  onTap: () => _handle('flashcards'),
                ),
                _ExportTile(
                  icon: '🧠',
                  label: 'Mind',
                  sub: 'Map',
                  color: Colors.teal,
                  onTap: () => _handle('mindmap'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  final String icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  const _ExportTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            Text(sub,
                style: TextStyle(color: color.withValues(alpha: 0.75), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
