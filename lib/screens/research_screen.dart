import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/app_theme.dart';
import '../utils/theme_helper.dart';
import '../providers/api_provider.dart';
import '../services/document_service.dart';
import '../widgets/rich_content_renderer.dart';
import '../widgets/language_selector.dart';
import '../widgets/export_sheet.dart';



class ResearchScreen extends ConsumerStatefulWidget {
  const ResearchScreen({super.key});

  @override
  ConsumerState<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends ConsumerState<ResearchScreen> {
  final _topicController = TextEditingController();
  final _docService = DocumentService();
  String _selectedPreset = 'auto';
  bool _isResearching = false;
  String _result = '';
  PickedDocument? _attachment;

  final List<Map<String, dynamic>> _presets = [
    {'value': 'quick', 'label': 'Quick', 'icon': Icons.bolt_rounded, 'color': AppTheme.accentGreen},
    {'value': 'medium', 'label': 'Medium', 'icon': Icons.speed_rounded, 'color': AppTheme.accentOrange},
    {'value': 'deep', 'label': 'Deep', 'icon': Icons.biotech_rounded, 'color': AppTheme.accentViolet},
    {'value': 'auto', 'label': 'Auto', 'icon': Icons.auto_awesome_rounded, 'color': AppTheme.accentIndigo},
  ];

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
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

  Future<void> _startResearch() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty && _attachment == null) return;

    setState(() {
      _isResearching = true;
      _result = '';
    });

    try {
      final api = ref.read(apiServiceProvider);

      // If there's an attachment, read its content and include it
      String researchTopic = topic;
      if (_attachment != null) {
        if (_attachment!.type == DocumentType.image) {
          // For images, use the callLLM with attachment directly
          final result = await api.callLLM(
            prompt: 'Conduct thorough research based on this image.${topic.isNotEmpty ? " Focus on: $topic" : ""}\n\nProvide a comprehensive research report with:\n- Executive Summary\n- Detailed analysis with sections\n- Key Findings\n- References',
            systemInstruction: 'You are a deep research agent. Produce structured, academic-quality research reports.',
            attachment: _attachment,
          );
          if (mounted) {
            setState(() { _result = result; _isResearching = false; });
          }
          return;
        }

        // For text/PDF/doc, read content and append to research topic
        final content = await _attachment!.readContent();
        if (content.isNotEmpty && !content.startsWith('[')) {
          researchTopic = topic.isNotEmpty
              ? '$topic\n\nUse the following document content as source material:\n\n$content'
              : 'Research and analyze the following document content:\n\n$content';
        }
      }

      final result = await api.deepResearch(
        topic: researchTopic,
        preset: _selectedPreset,
      );

      if (mounted) {
        setState(() { _result = result; _isResearching = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResearching = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _copyResult() {
    if (_result.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _result));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📋 Copied to clipboard'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Deep Research'),
        actions: [
          const LanguageSelector(),
          const SizedBox(width: 8),
          if (_result.isNotEmpty) ...[
            IconButton(
              onPressed: _copyResult,
              icon: Icon(Icons.copy_rounded, color: AppTheme.accentCyan),
              tooltip: 'Copy all',
            ),
            IconButton(
              icon: Icon(Icons.auto_awesome_rounded, color: AppTheme.accentGreen),
              tooltip: 'Export AI Assets (Slides, Mind Map, etc.)',
              onPressed: () {
                final topic = _topicController.text.trim();
                final title = topic.isEmpty ? 'Deep Research' : topic;
                showExportSheet(context, ref.read(apiServiceProvider), title, _result);
              },
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Topic input with attach button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _topicController,
                          style: TextStyle(color: context.textPri),
                          maxLines: 2,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: _attachment != null
                                ? 'Add research focus (optional)...'
                                : 'Enter research topic...',
                            prefixIcon: Icon(Icons.search_rounded, color: context.textTer),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // Attach button
                      GestureDetector(
                        onTap: _showAttachOptions,
                        child: Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: _attachment != null
                                ? AppTheme.accentIndigo.withValues(alpha: 0.15)
                                : AppTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _attachment != null
                                  ? AppTheme.accentIndigo.withValues(alpha: 0.5)
                                  : AppTheme.cardBorder,
                            ),
                          ),
                          child: Icon(
                            Icons.attach_file_rounded,
                            color: _attachment != null ? AppTheme.accentIndigo : AppTheme.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Attachment preview
                  if (_attachment != null) ...[
                    SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentIndigo.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.accentIndigo.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          if (_attachment!.type == DocumentType.image && _attachment!.bytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(_attachment!.bytes!, width: 36, height: 36, fit: BoxFit.cover),
                            )
                          else
                            Text(_attachment!.icon, style: TextStyle(fontSize: 22)),
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
                    ).animate().fadeIn(duration: 200.ms),
                  ],

                  SizedBox(height: 14),
                  // Depth presets
                  Row(
                    children: _presets.map((p) {
                      final isSelected = _selectedPreset == p['value'];
                      final color = p['color'] as Color;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedPreset = p['value'] as String),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? color : AppTheme.cardBorder),
                              ),
                              child: Column(
                                children: [
                                  Icon(p['icon'] as IconData, size: 20,
                                      color: isSelected ? color : AppTheme.textTertiary),
                                  SizedBox(height: 4),
                                  Text(p['label'] as String,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                        color: isSelected ? color : AppTheme.textTertiary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 14),
                  // Start button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isResearching ? null : _startResearch,
                      icon: _isResearching
                          ? SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: context.textPri))
                          : Icon(Icons.biotech_rounded),
                      label: Text(_isResearching ? 'Researching...' : 'Start Research'),
                    ),
                  ),
                ],
              ),
            ),
            
            // Result View
            _result.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.biotech_rounded, size: 64,
                              color: AppTheme.accentOrange.withValues(alpha: 0.3)),
                          SizedBox(height: 16),
                          Text('Enter a topic or attach a file',
                            style: TextStyle(color: context.textTer, fontSize: 16)),
                          SizedBox(height: 6),
                          Text('Upload PDFs, docs, or images for AI-powered research',
                            style: TextStyle(color: context.textTer, fontSize: 13),
                            textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: RichContentRenderer(
                      content: _result,
                      selectable: true,
                    ).animate().fadeIn(duration: 400.ms),
                  ),
          ],
        ),
      ),
    );
  }
}
