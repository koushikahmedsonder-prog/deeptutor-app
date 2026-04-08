import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/app_theme.dart';
import '../utils/theme_helper.dart';
import '../providers/knowledge_provider.dart';
import '../providers/api_provider.dart';
import '../services/deeptutor_prompts.dart';
import '../services/pdf_export_service.dart';
import '../widgets/doc_upload_sheet.dart';
import '../widgets/rich_content_renderer.dart';
import '../services/document_service.dart';
import '../widgets/export_sheet.dart';

class KnowledgeScreen extends ConsumerStatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  ConsumerState<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends ConsumerState<KnowledgeScreen> {
  int _activeTabIndex = 0; // 0: Knowledge Bases, 1: Notebooks

  // Notebook State
  List<Map<String, dynamic>> _notebooks = [];
  List<Map<String, dynamic>> _notes = [];
  String? _selectedNotebookId;
  bool _nbSearching = false;
  final _nbSearchController = TextEditingController();
  String? _nbTagFilter;
  bool _showInstructions = true;
  String _kbNameText = ''; // Manual text tracking for Windows desktop compatibility

  // Controllers
  final _kbNameController = TextEditingController();
  final _nbNameController = TextEditingController();

  void _makeFromNotebook(String title, List<Map<String, dynamic>> notes) {
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No notes available in this folder!')));
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('# Notebook Export\n');
    for (final note in notes) {
      if (note['content'] != null) {
        buffer.writeln('${note['content']}');
        buffer.writeln('\n---\n');
      }
    }
    showExportSheet(context, ref.read(apiServiceProvider), 'Notebook - $title', buffer.toString());
  }
  final _nbDescController = TextEditingController();

  static const List<Map<String, dynamic>> _availableTags = [
    {'name': 'Study', 'color': 0xFF6C63FF},
    {'name': 'Research', 'color': 0xFFF59E0B},
    {'name': 'Ideas', 'color': 0xFFEC4899},
    {'name': 'Summary', 'color': 0xFF10B981},
    {'name': 'Quiz', 'color': 0xFF06B6D4},
    {'name': 'Other', 'color': 0xFF8B5CF6},
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(knowledgeProvider.notifier).loadKnowledgeBases());
    _loadNotebookData();
    _nbSearchController.addListener(_rebuildNotes);
  }

  @override
  void dispose() {
    _kbNameController.dispose();
    _nbNameController.dispose();
    _nbDescController.dispose();
    _nbSearchController.dispose();
    super.dispose();
  }

  // ── Notebook Data Management ──

  Future<void> _loadNotebookData() async {
    final prefs = await SharedPreferences.getInstance();

    final nbJson = prefs.getStringList('notebook_folders') ?? [];
    if (nbJson.isEmpty) {
      final defaultNb = {
        'id': 'default',
        'name': 'My Notes',
        'description': 'General study materials',
        'created': DateTime.now().millisecondsSinceEpoch,
      };
      _notebooks = [defaultNb];
      await prefs.setStringList('notebook_folders', [jsonEncode(defaultNb)]);
    } else {
      _notebooks = nbJson.map((n) => jsonDecode(n) as Map<String, dynamic>).toList();
    }

    final notesJson = prefs.getStringList('notes') ?? [];
    _notes = notesJson.map((n) {
      final note = jsonDecode(n) as Map<String, dynamic>;
      if (!note.containsKey('notebookId')) note['notebookId'] = 'default';
      return note;
    }).toList()
      ..sort((a, b) {
        final aPinned = a['pinned'] == true ? 1 : 0;
        final bPinned = b['pinned'] == true ? 1 : 0;
        if (aPinned != bPinned) return bPinned - aPinned;
        return (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0);
      });

    if (_notebooks.isNotEmpty && _selectedNotebookId == null) {
      _selectedNotebookId = _notebooks.first['id'] as String?;
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveNotebookData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('notebook_folders', _notebooks.map((n) => jsonEncode(n)).toList());
    await prefs.setStringList('notes', _notes.map((n) => jsonEncode(n)).toList());
  }

  void _rebuildNotes() => setState(() {});

  void _createNotebook() {
    final name = _nbNameController.text.trim();
    if (name.isEmpty) return;
    final nb = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'description': _nbDescController.text.trim(),
      'created': DateTime.now().millisecondsSinceEpoch,
    };
    setState(() {
      _notebooks.add(nb);
      _selectedNotebookId = nb['id'] as String?;
    });
    _nbNameController.clear();
    _nbDescController.clear();
    _saveNotebookData();
  }

  List<Map<String, dynamic>> _getNotesForNotebook(String nbId) {
    final query = _nbSearchController.text.toLowerCase();
    return _notes.where((n) {
      if (n['notebookId'] != nbId) return false;
      if (_nbTagFilter != null && n['tag'] != _nbTagFilter) return false;
      if (query.isNotEmpty) {
        return (n['title']?.toString().toLowerCase().contains(query) ?? false) ||
            (n['content']?.toString().toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();
  }

  // ── Knowledge Base Management ──

  Future<void> _createKnowledgeBase() async {
    // Use manually tracked text (workaround for Windows InAppWebView text input issue)
    final name = (_kbNameText.isNotEmpty ? _kbNameText : _kbNameController.text).trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please enter a knowledge base name')),
      );
      return;
    }
    try {
      final success = await ref.read(knowledgeProvider.notifier).createKnowledgeBase(name);
      if (mounted) {
        if (success) {
          _kbNameController.clear();
          _kbNameText = '';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ "$name" created!')));
        } else {
          final error = ref.read(knowledgeProvider).error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Failed: ${error ?? "Unknown error"}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  void _uploadToKB(String kbName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DocUploadSheet(
        onDocumentPicked: (doc) async {
          final content = await doc.readContent();
          final success = await ref
              .read(knowledgeProvider.notifier)
              .uploadDocumentContent(kbName, doc.name, content);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(success ? '✅ "${doc.name}" added to $kbName!' : '❌ Upload failed')),
            );
          }
        },
      ),
    );
  }

  // ── Note CRUD ──

  void _showAddNote({Map<String, dynamic>? existingNote, String? nbId}) {
    final titleCtrl = TextEditingController(text: existingNote?['title'] ?? '');
    final contentCtrl = TextEditingController(text: existingNote?['content'] ?? '');
    String? noteTag = existingNote?['tag'];
    String? linkedKb = existingNote?['linkedKb'];
    final targetNbId = nbId ?? _selectedNotebookId ?? 'default';
    final kbs = ref.read(knowledgeProvider).knowledgeBases;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: context.textTer, borderRadius: BorderRadius.circular(2)))),
                Text(existingNote != null ? 'Edit Note' : 'New Note',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: context.textPri)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  style: TextStyle(color: context.textPri, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Note title',
                    prefixIcon: const Icon(Icons.title_rounded, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  style: TextStyle(color: context.textPri, height: 1.5),
                  maxLines: 10,
                  minLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Write your note here...\n\nTips:\n• Use **bold**, *italic* markdown\n• Add bullet points with - item\n• Use # Heading for structure',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Tag', style: TextStyle(color: context.textSec, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _availableTags.map((tag) {
                    final isSelected = noteTag == tag['name'];
                    final color = Color(tag['color'] as int);
                    return FilterChip(
                      label: Text(tag['name'] as String),
                      selected: isSelected,
                      selectedColor: color.withValues(alpha: 0.25),
                      backgroundColor: context.cardColor,
                      checkmarkColor: color,
                      labelStyle: TextStyle(color: isSelected ? color : context.textSec, fontSize: 13),
                      side: BorderSide(color: isSelected ? color : context.cardBorder),
                      onSelected: (selected) => setSheet(() => noteTag = selected ? tag['name'] as String : null),
                    );
                  }).toList(),
                ),
                if (kbs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Connect Knowledge Base', style: TextStyle(color: context.textSec, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: linkedKb,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                    dropdownColor: context.surfaceColor,
                    hint: const Text('Select a KB to link context...'),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('None', style: TextStyle(color: Colors.grey))),
                      ...kbs.map((kb) => DropdownMenuItem<String>(
                        value: kb['name'] as String,
                        child: Text(kb['name'] as String, style: TextStyle(color: context.textPri)),
                      )),
                    ],
                    onChanged: (val) => setSheet(() => linkedKb = val),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final doc = await DocumentService().pickDocument();
                      if (doc != null) {
                        String content = await doc.readContent();
                        if (content.length > 8000) {
                           content = '${content.substring(0, 8000)}\n\n[...Text truncated to avoid lag. Connect a KB for full document context...]';
                        }
                        setSheet(() {
                          final currentText = contentCtrl.text;
                          contentCtrl.text = currentText.isNotEmpty 
                              ? '$currentText\n\n--- Source: ${doc.name} ---\n$content'
                              : '--- Source: ${doc.name} ---\n$content';
                        });
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                  label: const Text('Extract Text from File'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textPri,
                    side: BorderSide(color: context.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    onPressed: () {
                      if (titleCtrl.text.trim().isNotEmpty) {
                        final note = {
                          'title': titleCtrl.text.trim(),
                          'content': contentCtrl.text.trim(),
                          'tag': noteTag,
                          'linkedKb': linkedKb,
                          'timestamp': existingNote?['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
                          'notebookId': targetNbId,
                          'pinned': existingNote?['pinned'] ?? false,
                        };
                        setState(() {
                          if (existingNote != null) {
                            final idx = _notes.indexWhere((n) => n['timestamp'] == existingNote['timestamp']);
                            if (idx >= 0) _notes[idx] = note;
                          } else {
                            _notes.insert(0, note);
                          }
                          _notes.sort((a, b) {
                            final aPinned = a['pinned'] == true ? 1 : 0;
                            final bPinned = b['pinned'] == true ? 1 : 0;
                            if (aPinned != bPinned) return bPinned - aPinned;
                            return (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0);
                          });
                        });
                        _saveNotebookData();
                        Navigator.pop(ctx);
                      }
                    },
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Save Note'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentIndigo),
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteNote(Map<String, dynamic> note) {
    final idx = _notes.indexOf(note);
    if (idx < 0) return;
    setState(() => _notes.removeAt(idx));
    _saveNotebookData();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      showCloseIcon: true,
      content: Text('Deleted "${note['title']}"'),
      action: SnackBarAction(label: 'Undo', onPressed: () {
        setState(() => _notes.insert(idx, note));
        _saveNotebookData();
      }),
    ));
  }

  Future<void> _deleteNotebook(String nbId, String nbName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: context.cardBorder)),
        title: Text('Delete Notebook', style: TextStyle(color: context.textPri)),
        content: Text('Are you sure you want to delete "$nbName"? All notes inside will be permanently deleted.', style: TextStyle(color: context.textSec)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: context.textSec))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      )
    );
    if (confirm != true) return;

    setState(() {
      _notebooks.removeWhere((n) => n['id'] == nbId);
      _notes.removeWhere((n) => n['notebook_id'] == nbId);
      if (_selectedNotebookId == nbId) {
        _selectedNotebookId = _notebooks.isNotEmpty ? _notebooks.first['id'] : null;
      }
    });
    _saveNotebookData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notebook deleted')));
    }
  }

  void _togglePin(Map<String, dynamic> note) {
    setState(() {
      note['pinned'] = !(note['pinned'] ?? false);
      _notes.sort((a, b) {
        final aPinned = a['pinned'] == true ? 1 : 0;
        final bPinned = b['pinned'] == true ? 1 : 0;
        if (aPinned != bPinned) return bPinned - aPinned;
        return (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0);
      });
    });
    _saveNotebookData();
  }

  void _copyNote(Map<String, dynamic> note) {
    Clipboard.setData(ClipboardData(text: '${note['title'] ?? ''}\n\n${note['content'] ?? ''}'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📋 Copied to clipboard'), duration: Duration(seconds: 2)));
  }

  Future<void> _downloadNote(Map<String, dynamic> note, bool asDoc) async {
    final title = note['title'] ?? 'Note';
    final content = '# $title\n\n${note['content'] ?? ''}';
    try {
      final path = asDoc
          ? await PdfExportService.exportAsDoc(title: 'Note_$title', content: content)
          : await PdfExportService.exportAsFile(title: 'Note_$title', content: content);
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ ${asDoc ? "DOC" : "PDF"} saved: $path'),
          backgroundColor: Colors.green.shade800));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
    }
  }

  Future<void> _exportNote(Map<String, dynamic> note) async {
    final title = note['title']?.toString() ?? 'Note';
    final content = note['content']?.toString() ?? '';
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note is empty — add content first')));
      return;
    }
    final api = ref.read(apiServiceProvider);
    await showExportSheet(context, api, title, content);
  }

  // ── AI Actions ──

  Future<void> _aiAction(Map<String, dynamic> note, String action) async {
    final content = note['content']?.toString() ?? '';
    final title = note['title']?.toString() ?? 'Untitled';
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note is empty — add content first')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: AppTheme.accentIndigo),
          const SizedBox(height: 16),
          Text('AI is ${action == 'summarize' ? 'summarizing' : action == 'quiz' ? 'generating quiz' : action == 'expand' ? 'expanding' : 'finding connections'}...',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, decoration: TextDecoration.none)),
        ]),
      )),
    );

    try {
      final api = ref.read(apiServiceProvider);
      String prompt;
      switch (action) {
        case 'summarize':
          prompt = 'Summarize this note into concise bullet points with bold headers.\n\nNote Title: $title\n\nContent:\n$content';
          break;
        case 'quiz':
          prompt = 'Generate 5 recall questions from this note. Format each as:\n\n**Q: [question]**\n\n<details><summary>Show Answer</summary>\n\n[answer]\n\n</details>\n\nNote Title: $title\n\nContent:\n$content';
          break;
        case 'expand':
          prompt = 'Expand and elaborate on this note. Add more detail, examples, and explanations while keeping the original structure.\n\nNote Title: $title\n\nContent:\n$content';
          break;
        case 'connect':
          final notesContext = _notes.map((n) => '- ${n['title']}: ${(n['content'] ?? '').toString().substring(0, (n['content']?.toString().length ?? 0).clamp(0, 150))}').join('\n');
          prompt = 'Find connections between this note and my other notes. List shared concepts, contradictions, and complementary ideas.\n\nCurrent Note: $title\nContent:\n$content\n\nAll My Notes:\n$notesContext';
          break;
        default:
          prompt = content;
      }

      final linkedKb = note['linkedKb']?.toString();
      if (linkedKb != null && linkedKb.isNotEmpty) {
        final kbContent = ref.read(knowledgeProvider.notifier).getKnowledgeBaseContent(linkedKb);
        if (kbContent.isNotEmpty) {
          final limitedKbContent = kbContent.length > 50000 ? kbContent.substring(0, 50000) : kbContent;
          prompt += '\n\n---\nAdditional Context from linked Knowledge Base ($linkedKb):\n$limitedKbContent\n---';
        }
      }

      await Future.delayed(const Duration(milliseconds: 100));
      
      final result = await api.callLLM(prompt: prompt, systemInstruction: DeepTutorPrompts.notebookAssistant);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showAIResult(title, action, result, note);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Error: $e')));
      }
    }
  }

  void _showAIResult(String noteTitle, String action, String result, Map<String, dynamic> sourceNote) {
    final actionLabel = switch (action) {
      'summarize' => '📝 Summary',
      'quiz' => '❓ Quiz',
      'expand' => '📖 Expanded',
      'connect' => '🔗 Connections',
      _ => '🤖 AI Result',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.82,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(color: context.surfaceColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: context.textTer, borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            Expanded(child: Text('$actionLabel — $noteTitle',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.textPri),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20, color: AppTheme.accentCyan),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result));
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('📋 Copied'), duration: Duration(seconds: 1)));
              },
            ),
            IconButton(
              icon: const Icon(Icons.note_add_rounded, size: 20, color: AppTheme.accentGreen),
              tooltip: 'Save as new note',
              onPressed: () {
                final newNote = {
                  'title': '$actionLabel: $noteTitle',
                  'content': result,
                  'tag': action == 'quiz' ? 'Quiz' : action == 'summarize' ? 'Summary' : action == 'connect' ? 'Ideas' : 'Study',
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'notebookId': sourceNote['notebookId'] ?? _selectedNotebookId ?? 'default',
                  'pinned': false,
                };
                setState(() {
                  _notes.insert(0, newNote);
                  _notes.sort((a, b) {
                    final aPinned = a['pinned'] == true ? 1 : 0;
                    final bPinned = b['pinned'] == true ? 1 : 0;
                    if (aPinned != bPinned) return bPinned - aPinned;
                    return (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0);
                  });
                });
                _saveNotebookData();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Saved as new note!')));
              },
            ),
          ]),
          const SizedBox(height: 8),
          Divider(color: context.cardBorder),
          const SizedBox(height: 8),
          Expanded(child: SingleChildScrollView(child: RichContentRenderer(content: result, selectable: true))),
        ]),
      ),
    );
  }

  void _showNoteDetail(Map<String, dynamic> note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: BoxDecoration(color: context.surfaceColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: context.textTer, borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            if (note['tag'] != null) ...[_buildTagChip(note['tag']), const SizedBox(width: 8)],
            if (note['pinned'] == true)
              Padding(padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.push_pin_rounded, size: 14, color: AppTheme.accentOrange.withValues(alpha: 0.8))),
            Expanded(child: Text(note['title'] ?? 'Untitled',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.textPri))),
            IconButton(icon: const Icon(Icons.copy_rounded, size: 20, color: AppTheme.accentCyan),
              onPressed: () { Navigator.pop(ctx); _copyNote(note); }, tooltip: 'Copy'),
            IconButton(
              icon: const Icon(Icons.ios_share_rounded, size: 20, color: AppTheme.accentViolet),
              tooltip: 'Export As…',
              onPressed: () { Navigator.pop(ctx); _exportNote(note); },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.download_rounded, size: 20, color: AppTheme.accentGreen),
              color: context.surfaceColor,
              onSelected: (a) { if (a == 'pdf') {
                _downloadNote(note, false);
              } else {
                _downloadNote(note, true);
              } },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'pdf', child: Row(children: [
                  const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.redAccent), const SizedBox(width: 8),
                  Text('Download PDF', style: TextStyle(color: context.textPri))])),
                PopupMenuItem(value: 'doc', child: Row(children: [
                  const Icon(Icons.description_rounded, size: 18, color: Colors.blueAccent), const SizedBox(width: 8),
                  Text('Download DOC', style: TextStyle(color: context.textPri))])),
              ],
            ),
            IconButton(icon: const Icon(Icons.edit_rounded, size: 20, color: AppTheme.accentIndigo),
              onPressed: () { Navigator.pop(ctx); _showAddNote(existingNote: note); }),
          ]),
          Text(_formatDate(note['timestamp']), style: TextStyle(color: context.textTer, fontSize: 12)),
          const SizedBox(height: 12),

          // AI Action chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _buildAIChip(Icons.summarize_rounded, 'Summarize', AppTheme.accentGreen, () { Navigator.pop(ctx); _aiAction(note, 'summarize'); }),
              const SizedBox(width: 8),
              _buildAIChip(Icons.quiz_rounded, 'Quiz Me', AppTheme.accentCyan, () { Navigator.pop(ctx); _aiAction(note, 'quiz'); }),
              const SizedBox(width: 8),
              _buildAIChip(Icons.open_in_full_rounded, 'Expand', AppTheme.accentOrange, () { Navigator.pop(ctx); _aiAction(note, 'expand'); }),
              const SizedBox(width: 8),
              _buildAIChip(Icons.hub_rounded, 'Connect', AppTheme.accentViolet, () { Navigator.pop(ctx); _aiAction(note, 'connect'); }),
            ]),
          ),

          const SizedBox(height: 12),
          Divider(color: context.cardBorder),
          const SizedBox(height: 8),
          Expanded(child: SingleChildScrollView(child: RichContentRenderer(content: note['content'] ?? '', selectable: true))),
        ]),
      ),
    );
  }

  Widget _buildAIChip(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildTagChip(String? tag) {
    if (tag == null) return const SizedBox.shrink();
    final tagData = _availableTags.firstWhere((t) => t['name'] == tag, orElse: () => {'name': tag, 'color': 0xFF8B5CF6});
    final color = Color(tagData['color'] as int);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(tag, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // ── UI Builders ──

  Widget _buildSegmentedToggle() {
    return Container(
      decoration: BoxDecoration(color: context.surfaceColorDark, borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.all(4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _buildToggleItem('Knowledge Bases', 0),
        _buildToggleItem('Notebooks', 1),
      ]),
    );
  }

  Widget _buildToggleItem(String title, int index) {
    final isActive = _activeTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? context.surfaceColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Text(title, style: TextStyle(
          fontSize: 14,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          color: isActive ? context.textPri : context.textSec,
        )),
      ),
    );
  }

  Widget _buildKnowledgeBasesTab() {
    final kbState = ref.watch(knowledgeProvider);
    final kbCreateCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.add_rounded, size: 20, color: context.textSec),
          const SizedBox(width: 8),
          const Text('Create knowledge base', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(
            controller: _kbNameController,
            onChanged: (val) {
              _kbNameText = val;
            },
            onSubmitted: (_) => _createKnowledgeBase(),
            decoration: InputDecoration(
              hintText: 'Knowledge base name', isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFFB6B6), width: 2)),
          ))),
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _createKnowledgeBase,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB6B6), foregroundColor: Colors.black, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            ),
          ),
        ]),
      ]),
    );

    final kbContentArea = Container(
        decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cardBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            Icon(Icons.folder_open_rounded, size: 20, color: context.textSec),
            const SizedBox(width: 8),
            Text('Knowledge Bases', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ])),
          Divider(height: 1, color: context.cardBorder),
          if (kbState.isLoading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (kbState.knowledgeBases.isEmpty)
            Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('No knowledge bases yet', style: TextStyle(color: context.textTer))))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: kbState.knowledgeBases.length,
              separatorBuilder: (c, i) => Divider(height: 1, color: context.cardBorder),
              itemBuilder: (context, index) {
                final kb = kbState.knowledgeBases[index];
                final name = kb['name']?.toString() ?? 'Unknown';
                final docCount = kb['doc_count'] ?? 0;
                return ListTile(
                  leading: Container(width: 10, height: 10,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentOrange)),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: Text('$docCount documents', style: TextStyle(color: context.textTer, fontSize: 13)),
                  trailing: TextButton.icon(
                    onPressed: () => _uploadToKB(name),
                    icon: const Icon(Icons.upload_file_rounded, size: 16, color: AppTheme.accentIndigo),
                    label: const Text('Upload', style: TextStyle(color: AppTheme.accentIndigo)),
                  ),
                );
              },
            ),
        ]),
      );

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        kbCreateCard,
        const SizedBox(height: 24),
        MediaQuery.of(context).size.width < 600 ? kbContentArea : Expanded(child: kbContentArea),
      ]);
  }

  // ── THE FULL NOTEBOOK TAB ──
  Widget _buildNotebooksTab() {
    final selectedNb = _notebooks.firstWhere((n) => n['id'] == _selectedNotebookId, orElse: () => <String, dynamic>{});
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Instructions Banner ──
      if (_showInstructions)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.accentIndigo.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accentIndigo.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.accentIndigo, size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text(
              'Quick Tips: Select a notebook on the left. Press + to add notes. Tap notes for AI actions, swipe to delete.',
              style: TextStyle(color: AppTheme.accentIndigo, fontSize: 13, fontWeight: FontWeight.w500),
            )),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textTertiary),
              onPressed: () => setState(() => _showInstructions = false),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
          ]),
        ).animate().fadeIn(),


      // ── Create Notebook Bar ──
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.cardBorder)),
        child: isMobile 
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(Icons.create_new_folder_rounded, size: 16, color: context.textSec),
                const SizedBox(width: 8),
                const Text('Create Notebook', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(controller: _nbNameController, decoration: InputDecoration(
                      hintText: 'Notebook name', isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.cardBorder)),
                    )),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(controller: _nbDescController, decoration: InputDecoration(
                      hintText: 'Description', isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.cardBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.cardBorder)),
                    )),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: _createNotebook,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB6B6), foregroundColor: Colors.black, elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0)),
                      child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  )
                ],
              ),
            ],
          )
        : Row(children: [
          Icon(Icons.create_new_folder_rounded, size: 18, color: context.textSec),
          const SizedBox(width: 8),
          Text('Create:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: TextField(controller: _nbNameController, decoration: InputDecoration(
            hintText: 'Notebook name', isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.cardBorder)),
          ))),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: TextField(controller: _nbDescController, decoration: InputDecoration(
            hintText: 'Description (optional)', isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.cardBorder)),
          ))),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _createNotebook,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB6B6), foregroundColor: context.textPri, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            child: const Text('Add'),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Master / Detail Pane ──
      Builder(builder: (context) {
        final paneContent = Container(
          decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.cardBorder)),
          child: isMobile 
            ? Column(children: [
                // ── Top: Mobile Notebook Chips ──
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    itemCount: _notebooks.length,
                    itemBuilder: (context, index) {
                      final nb = _notebooks[index];
                      final nbId = nb['id'];
                      final isSelected = nbId == _selectedNotebookId;
                      return GestureDetector(
                        onTap: () => setState(() { _selectedNotebookId = nbId; _nbTagFilter = null; }),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.accentIndigo : context.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? Colors.transparent : context.cardBorder),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            children: [
                              Icon(Icons.folder_rounded, size: 16, color: isSelected ? Colors.white : context.textSec),
                              const SizedBox(width: 6),
                              Text(nb['name'], style: TextStyle(
                                color: isSelected ? Colors.white : context.textPri,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                fontSize: 14,
                              )),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Divider(height: 1, color: context.cardBorder),
                // ── Bottom: Mobile Notes List ──
                _buildRightNotesPane(selectedNb, nbId: _selectedNotebookId),
              ])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Left: Desktop Notebook list ──
                SizedBox(width: 240, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                    Icon(Icons.edit_note_rounded, size: 20, color: context.textSec),
                    const SizedBox(width: 8),
                    const Text('Notebooks', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ])),
                  Divider(height: 1, color: context.cardBorder),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                  itemCount: _notebooks.length,
                  itemBuilder: (context, index) {
                    final nb = _notebooks[index];
                    final nbId = nb['id'];
                    final isSelected = nbId == _selectedNotebookId;
                    final recordCount = _getNotesForNotebook(nbId).length;

                    return GestureDetector(
                      onTap: () => setState(() { _selectedNotebookId = nbId; _nbTagFilter = null; }),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.accentIndigo.withValues(alpha: 0.08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected ? Border.all(color: AppTheme.accentIndigo.withValues(alpha: 0.35)) : Border.all(color: Colors.transparent),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? AppTheme.accentIndigo : Colors.blueAccent)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(nb['name'], style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14, color: context.textPri))),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(Icons.delete_outline_rounded, size: 16, color: context.textTer),
                              onPressed: () => _deleteNotebook(nbId, nb['name']),
                            ),
                          ]),
                          if (nb['description'] != null && (nb['description'] as String).isNotEmpty)
                            Padding(padding: const EdgeInsets.only(left: 18, top: 3),
                              child: Text(nb['description'], maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: context.textTer))),
                          Padding(padding: const EdgeInsets.only(left: 18, top: 3),
                            child: Text('$recordCount notes', style: TextStyle(fontSize: 11, color: context.textTer))),
                        ]),
                      ),
                    );
                  },
                ),
              ])),

              VerticalDivider(width: 1, color: context.cardBorder),

              // ── Right: Desktop Notes List ──
              Expanded(child: _buildRightNotesPane(selectedNb, nbId: _selectedNotebookId)),
            ]),
        );
            
        return isMobile ? paneContent : Expanded(child: paneContent);
      }),
    ]);
  }

  Widget _buildRightNotesPane(Map<String, dynamic> selectedNb, {String? nbId}) {
    final selectedNotes = nbId != null ? _getNotesForNotebook(nbId) : <Map<String, dynamic>>[];
    return Column(children: [
            // Header Row
            if (selectedNb.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppTheme.accentIndigo)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(selectedNb['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17))),
                  if (selectedNb['description'] != null && selectedNb['description'].toString().isNotEmpty)
                    Expanded(child: Text('— ${selectedNb['description']}', style: TextStyle(color: context.textTer, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  // Search toggle
                  IconButton(
                    icon: Icon(_nbSearching ? Icons.close_rounded : Icons.search_rounded, size: 20, color: context.textTer),
                    onPressed: () => setState(() {
                      _nbSearching = !_nbSearching;
                      if (!_nbSearching) _nbSearchController.clear();
                    }),
                  ),
                  // Add Note button
                  TextButton.icon(
                    onPressed: () => _showAddNote(nbId: _selectedNotebookId),
                    icon: const Icon(Icons.add_rounded, size: 16, color: AppTheme.accentIndigo),
                    label: const Text('Add Note', style: TextStyle(color: AppTheme.accentIndigo, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),

            // Search Bar
            if (_nbSearching)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _nbSearchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),

            // Tag filter row
            if (selectedNb.isNotEmpty && !_nbSearching)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(children: [
                  Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(
                    label: const Text('All', style: TextStyle(fontSize: 12)),
                    selected: _nbTagFilter == null,
                    selectedColor: AppTheme.accentIndigo.withValues(alpha: 0.18),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(color: _nbTagFilter == null ? AppTheme.accentIndigo : context.cardBorder),
                    labelStyle: TextStyle(color: _nbTagFilter == null ? AppTheme.accentIndigo : context.textTer),
                    onSelected: (_) => setState(() => _nbTagFilter = null),
                  )),
                  ..._availableTags.map((tag) {
                    final isSelected = _nbTagFilter == tag['name'];
                    final color = Color(tag['color'] as int);
                    return Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(
                      label: Text(tag['name'] as String, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      selectedColor: color.withValues(alpha: 0.18),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(color: isSelected ? color : context.cardBorder),
                      labelStyle: TextStyle(color: isSelected ? color : context.textTer),
                      onSelected: (_) => setState(() => _nbTagFilter = isSelected ? null : tag['name'] as String),
                    ));
                  }),
                  const SizedBox(width: 8),
                  Padding(padding: const EdgeInsets.only(right: 6), child: ActionChip(
                    label: const Text('Make PPTX', style: TextStyle(fontSize: 12, color: AppTheme.accentOrange, fontWeight: FontWeight.w600)),
                    backgroundColor: AppTheme.accentOrange.withValues(alpha: 0.1),
                    side: BorderSide(color: AppTheme.accentOrange.withValues(alpha: 0.3)),
                    onPressed: () => _makeFromNotebook('PPTX', selectedNotes),
                  )),
                  Padding(padding: const EdgeInsets.only(right: 6), child: ActionChip(
                    label: const Text('Make Slides', style: TextStyle(fontSize: 12, color: AppTheme.accentOrange, fontWeight: FontWeight.w600)),
                    backgroundColor: AppTheme.accentOrange.withValues(alpha: 0.1),
                    side: BorderSide(color: AppTheme.accentOrange.withValues(alpha: 0.3)),
                    onPressed: () => _makeFromNotebook('Slides', selectedNotes),
                  )),
                  Padding(padding: const EdgeInsets.only(right: 6), child: ActionChip(
                    label: const Text('Make Mind Map', style: TextStyle(fontSize: 12, color: AppTheme.accentOrange, fontWeight: FontWeight.w600)),
                    backgroundColor: AppTheme.accentOrange.withValues(alpha: 0.1),
                    side: BorderSide(color: AppTheme.accentOrange.withValues(alpha: 0.3)),
                    onPressed: () => _makeFromNotebook('Mind Map', selectedNotes),
                  )),
                ]),
              ),

            Divider(height: 1, color: context.cardBorder),

            // Notes list
            Builder(builder: (context) {
              final isMobile = MediaQuery.of(context).size.width < 600;
              final listContent = selectedNotes.isEmpty
                ? Padding(padding: const EdgeInsets.all(32), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.note_alt_outlined, size: 48, color: context.textTer.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text(
                      _notes.where((n) => n['notebookId'] == _selectedNotebookId).isEmpty
                          ? 'No notes yet in this notebook' : 'No matching notes',
                      style: TextStyle(color: context.textTer, fontSize: 15)),
                    const SizedBox(height: 8),
                    Text(
                      _notes.where((n) => n['notebookId'] == _selectedNotebookId).isEmpty
                          ? 'Press "+ Add Note" to create your first note' : 'Try a different filter or search',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.textTer, fontSize: 12)),
                  ])))
                : ListView.separated(
                    shrinkWrap: true,
                    physics: isMobile ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                  itemCount: selectedNotes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final note = selectedNotes[index];
                    final isPinned = note['pinned'] == true;
                    return Dismissible(
                      key: ValueKey(note['timestamp']),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _deleteNote(note),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.delete_rounded, color: Colors.red),
                      ),
                      child: GestureDetector(
                        onTap: () => _showNoteDetail(note),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.cardBorder),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              if (isPinned) Padding(padding: const EdgeInsets.only(right: 6),
                                child: Icon(Icons.push_pin_rounded, size: 14, color: AppTheme.accentOrange.withValues(alpha: 0.8))),
                              if (note['tag'] != null) ...[_buildTagChip(note['tag']), const SizedBox(width: 8)],
                              Expanded(child: Text(note['title'] ?? 'Untitled',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textPri),
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert_rounded, color: context.textTer, size: 18),
                                color: context.surfaceColor,
                                onSelected: (action) {
                                  switch (action) {
                                    case 'pin': _togglePin(note); break;
                                    case 'edit': _showAddNote(existingNote: note); break;
                                    case 'copy': _copyNote(note); break;
                                    case 'export': _exportNote(note); break;
                                    case 'summarize': _aiAction(note, 'summarize'); break;
                                    case 'quiz': _aiAction(note, 'quiz'); break;
                                    case 'expand': _aiAction(note, 'expand'); break;
                                    case 'connect': _aiAction(note, 'connect'); break;
                                    case 'download': _downloadNote(note, false); break;
                                    case 'delete': _deleteNote(note); break;
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(value: 'pin', child: Row(children: [
                                    Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, size: 18, color: AppTheme.accentOrange),
                                    const SizedBox(width: 8),
                                    Text(isPinned ? 'Unpin' : 'Pin to top', style: TextStyle(color: context.textPri))])),
                                  PopupMenuItem(value: 'edit', child: Row(children: [
                                    Icon(Icons.edit_rounded, size: 18, color: context.textSec), const SizedBox(width: 8),
                                    Text('Edit', style: TextStyle(color: context.textPri))])),
                                  const PopupMenuItem(value: 'summarize', child: Row(children: [
                                    Icon(Icons.summarize_rounded, size: 18, color: AppTheme.accentGreen), SizedBox(width: 8),
                                    Text('AI Summarize', style: TextStyle(color: AppTheme.accentGreen))])),
                                  const PopupMenuItem(value: 'quiz', child: Row(children: [
                                    Icon(Icons.quiz_rounded, size: 18, color: AppTheme.accentCyan), SizedBox(width: 8),
                                    Text('AI Quiz Me', style: TextStyle(color: AppTheme.accentCyan))])),
                                  const PopupMenuItem(value: 'expand', child: Row(children: [
                                    Icon(Icons.open_in_full_rounded, size: 18, color: AppTheme.accentOrange), SizedBox(width: 8),
                                    Text('AI Expand', style: TextStyle(color: AppTheme.accentOrange))])),
                                  const PopupMenuItem(value: 'connect', child: Row(children: [
                                    Icon(Icons.hub_rounded, size: 18, color: AppTheme.accentViolet), SizedBox(width: 8),
                                    Text('AI Connect Notes', style: TextStyle(color: AppTheme.accentViolet))])),
                                  PopupMenuItem(value: 'copy', child: Row(children: [
                                    Icon(Icons.copy_rounded, size: 18, color: context.textSec), const SizedBox(width: 8),
                                    Text('Copy', style: TextStyle(color: context.textPri))])),
                                  const PopupMenuItem(value: 'export', child: Row(children: [
                                    Icon(Icons.ios_share_rounded, size: 18, color: AppTheme.accentViolet), SizedBox(width: 8),
                                    Text('Export As…', style: TextStyle(color: AppTheme.accentViolet))])),
                                  PopupMenuItem(value: 'download', child: Row(children: [
                                    const Icon(Icons.download_rounded, size: 18, color: AppTheme.accentGreen), const SizedBox(width: 8),
                                    Text('Download PDF', style: TextStyle(color: context.textPri))])),
                                  const PopupMenuItem(value: 'delete', child: Row(children: [
                                    Icon(Icons.delete_rounded, size: 18, color: Colors.red), SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: Colors.red))])),
                                ],
                              ),
                            ]),
                            if ((note['content']?.toString() ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(note['content'].toString(),
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: context.textSec, fontSize: 13, height: 1.5)),
                            ],
                            const SizedBox(height: 6),
                            Text(_formatDate(note['timestamp']),
                              style: TextStyle(fontSize: 11, color: context.textTer)),
                          ]),
                        ).animate(delay: (60 * index).ms).fadeIn(duration: 250.ms).slideX(begin: 0.04, end: 0),
                      ),
                    );
                  },
                );
              return isMobile ? listContent : Expanded(child: listContent);
            }),
          ]);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        if (isMobile) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Text('Knowledge', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: context.textPri)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Center(child: _buildSegmentedToggle()),
              ),
          ]),
          const SizedBox(height: 16),
        ] else ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Knowledge', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: context.textPri)),
              const SizedBox(height: 8),
              Text('Manage your knowledge bases and notebooks in one place.', style: TextStyle(fontSize: 15, color: context.textSec)),
            ]),
            _buildSegmentedToggle(),
          ]),
          const SizedBox(height: 24),
        ],
        isMobile ? (_activeTabIndex == 0 ? _buildKnowledgeBasesTab() : _buildNotebooksTab()) : Expanded(child: _activeTabIndex == 0 ? _buildKnowledgeBasesTab() : _buildNotebooksTab()),
        if (!isMobile) const SizedBox(height: 16),
      ]);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: isMobile 
        ? SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: content,
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: content,
          ),
    );
  }
}
