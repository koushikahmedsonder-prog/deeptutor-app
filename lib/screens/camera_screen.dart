import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../config/app_theme.dart';
import '../providers/api_provider.dart';
import '../providers/knowledge_provider.dart';
import '../widgets/doc_upload_sheet.dart';
import '../services/document_service.dart';
import '../services/pdf_export_service.dart';

class CameraScreen extends ConsumerStatefulWidget {
  final PickedDocument? initialDocument;

  const CameraScreen({super.key, this.initialDocument});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  PickedDocument? _pickedDocument;
  String? _selectedKb;
  bool _isUploading = false;
  bool _isAnalyzing = false;
  bool _isExporting = false;
  String _extractedText = '';
  String _analysisResult = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialDocument != null) {
      _pickedDocument = widget.initialDocument;
      // Start text extraction automatically on init
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _extractText(_pickedDocument!);
      });
    }
  }

  void _pickDocument() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DocUploadSheet(
        onDocumentPicked: (doc) {
          setState(() {
            _pickedDocument = doc;
            _extractedText = '';
            _analysisResult = '';
          });
          _extractText(doc);
        },
      ),
    );
  }

  Future<void> _extractText(PickedDocument doc) async {
    setState(() => _isAnalyzing = true);
    try {
      final content = await doc.readContent();
      setState(() {
        _extractedText = content;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _extractedText = 'Could not read file: $e';
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _analyzeWithAI() async {
    if (_extractedText.isEmpty || _extractedText.startsWith('[Could')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No readable text to analyze')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.analyzeDocument(
        _extractedText.length > 8000
            ? _extractedText.substring(0, 8000)
            : _extractedText,
        _pickedDocument?.name ?? 'document',
      );
      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis error: $e')),
        );
      }
    }
  }

  Future<void> _downloadResult(bool asDoc) async {
    final contentToExport = _analysisResult.isNotEmpty
        ? _analysisResult
        : _extractedText;

    if (contentToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No content to download')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final title =
          'Scan_${_pickedDocument?.name ?? 'Document'}';
      final path = asDoc
          ? await PdfExportService.exportAsDoc(title: title, content: contentToExport)
          : await PdfExportService.exportAsFile(title: title, content: contentToExport);

      if (mounted) {
        setState(() => _isExporting = false);
        if (path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${asDoc ? "DOC" : "PDF"} saved: $path'),
              backgroundColor: Colors.green.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Could not save ${asDoc ? "DOC" : "PDF"}')),
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

  Future<void> _uploadToKB() async {
    if (_pickedDocument == null || _selectedKb == null) return;

    setState(() => _isUploading = true);

    try {
      bool success;
      if (_extractedText.isNotEmpty) {
        success = await ref
            .read(knowledgeProvider.notifier)
            .uploadDocumentContent(
                _selectedKb!, _pickedDocument!.name, _extractedText);
      } else {
        success = await ref
            .read(knowledgeProvider.notifier)
            .uploadPickedDocument(_selectedKb!, _pickedDocument!);
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ "${_pickedDocument!.name}" added to $_selectedKb!'),
              backgroundColor: Colors.green.shade800,
            ),
          );
          setState(() {
            _pickedDocument = null;
            _extractedText = '';
            _analysisResult = '';
            _isUploading = false;
          });
        } else {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Upload failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Upload failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kbState = ref.watch(knowledgeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Document'),
        actions: [
          if (_extractedText.isNotEmpty || _analysisResult.isNotEmpty) ...[
            IconButton(
              onPressed: () {
                final text = _analysisResult.isNotEmpty ? _analysisResult : _extractedText;
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('📋 Copied to clipboard'), duration: Duration(seconds: 2)),
                );
              },
              icon: const Icon(Icons.copy_rounded, color: AppTheme.accentCyan),
              tooltip: 'Copy all',
            ),
            _isExporting
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.accentGreen),
                    ),
                  )
                : PopupMenuButton<String>(
                    icon: const Icon(Icons.download_rounded, color: AppTheme.accentGreen),
                    tooltip: 'Download Scanned Content',
                    color: AppTheme.surface,
                    onSelected: (action) {
                      if (action == 'pdf') {
                        _downloadResult(false);
                      } else if (action == 'doc') _downloadResult(true);
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'pdf', child: Row(children: [
                        Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Download as PDF', style: TextStyle(color: AppTheme.textPrimary)),
                      ])),
                      const PopupMenuItem(value: 'doc', child: Row(children: [
                        Icon(Icons.description_rounded, size: 18, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text('Download as DOC', style: TextStyle(color: AppTheme.textPrimary)),
                      ])),
                    ],
                  ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Document preview area
            GestureDetector(
              onTap: _pickDocument,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _pickedDocument != null
                        ? AppTheme.accentCyan.withOpacity(0.6)
                        : AppTheme.accentIndigo.withOpacity(0.3),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: _pickedDocument == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.accentCyan.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.document_scanner_rounded,
                              size: 48,
                              color: AppTheme.accentCyan,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Tap to Pick a Document',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'PDF • TXT • MD • DOC • Images',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 600.ms)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.accentIndigo
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _pickedDocument!.icon,
                              style: const TextStyle(fontSize: 36),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _pickedDocument!.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _pickedDocument!.sizeFormatted,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _pickDocument,
                            icon: const Icon(Icons.swap_horiz_rounded,
                                size: 18),
                            label: const Text('Change',
                                style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms),
              ),
            ),

            const SizedBox(height: 16),

            // Loading indicator
            if (_isAnalyzing && _extractedText.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: const Column(
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accentCyan,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Reading document...',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

            // Extracted text preview
            if (_extractedText.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.text_snippet_rounded,
                            size: 18, color: AppTheme.accentGreen),
                        const SizedBox(width: 8),
                        const Text(
                          'Extracted Content',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_extractedText.split(' ').length} words',
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _extractedText.length > 2000
                              ? '${_extractedText.substring(0, 2000)}...'
                              : _extractedText,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

            if (_extractedText.isNotEmpty) const SizedBox(height: 12),

            // Analyze with AI button — filled bright style for visibility
            if (_pickedDocument != null && _extractedText.isNotEmpty)
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _analyzeWithAI,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.auto_awesome_rounded, color: Colors.black),
                  label: Text(
                      _isAnalyzing ? 'Analyzing...' : 'Analyze with AI',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCyan,
                    disabledBackgroundColor: AppTheme.accentCyan.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms),

            // AI Analysis Result
            if (_analysisResult.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accentCyan.withValues(alpha: 0.05),
                      AppTheme.accentIndigo.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.accentCyan.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics_rounded,
                            size: 18, color: AppTheme.accentCyan),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'AI Analysis',
                            style: TextStyle(
                              color: AppTheme.accentCyan,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        // Download button inline
                        PopupMenuButton<String>(
                          icon: _isExporting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.accentGreen,
                                  ),
                                )
                              : const Icon(Icons.download_rounded,
                                  size: 20, color: AppTheme.accentGreen),
                          tooltip: 'Download result',
                          color: AppTheme.surface,
                          enabled: !_isExporting,
                          onSelected: (action) {
                            if (action == 'pdf') {
                              _downloadResult(false);
                            } else if (action == 'doc') _downloadResult(true);
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'pdf', child: Row(children: [
                              Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('Download as PDF', style: TextStyle(color: AppTheme.textPrimary)),
                            ])),
                            const PopupMenuItem(value: 'doc', child: Row(children: [
                              Icon(Icons.description_rounded, size: 18, color: Colors.blueAccent),
                              SizedBox(width: 8),
                              Text('Download as DOC', style: TextStyle(color: AppTheme.textPrimary)),
                            ])),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SelectionArea(
                      child: MarkdownBody(
                        data: _analysisResult,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          h1: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          h2: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          listBullet: const TextStyle(
                              color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
            ],

            const SizedBox(height: 20),

            // KB Selector
            if (_pickedDocument != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accentIndigo.withOpacity(0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Save to Knowledge Base...',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    value: (_selectedKb != null && kbState.knowledgeBases.any((kb) => kb['name']?.toString() == _selectedKb)) 
                        ? _selectedKb 
                        : null,
                    dropdownColor: AppTheme.card,
                    icon: const Icon(Icons.arrow_drop_down, color: AppTheme.accentIndigo),
                    items: kbState.knowledgeBases.fold<Map<String, Map<String, dynamic>>>({}, (map, kb) {
                      final name = kb['name']?.toString() ?? 'Unknown';
                      if (!map.containsKey(name)) {
                        map[name] = kb;
                      }
                      return map;
                    }).values.map((kb) {
                      final name =
                          kb['name']?.toString() ?? 'Unknown';
                      return DropdownMenuItem(
                        value: name,
                        child: Text(name,
                            style: const TextStyle(
                                color: AppTheme.textPrimary)),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedKb = val),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Upload button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      (_pickedDocument != null &&
                              _selectedKb != null &&
                              !_isUploading)
                          ? _uploadToKB
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_rounded),
                            SizedBox(width: 10),
                            Text('Save to Knowledge Base',
                                style: TextStyle(fontSize: 15)),
                          ],
                        ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
