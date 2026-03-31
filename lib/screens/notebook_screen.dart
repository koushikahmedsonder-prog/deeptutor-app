import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/app_theme.dart';
import '../providers/api_provider.dart';
import '../services/deeptutor_prompts.dart';
import '../services/pdf_export_service.dart';

class NotebookScreen extends ConsumerStatefulWidget {
  const NotebookScreen({super.key});

  @override
  ConsumerState<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends ConsumerState<NotebookScreen> {
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _searchController = TextEditingController();
  String? _selectedTag;
  bool _isSearching = false;

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
    _loadNotes();
    _searchController.addListener(_filterNotes);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getStringList('notes') ?? [];
    setState(() {
      _notes = notesJson
          .map((n) => jsonDecode(n) as Map<String, dynamic>)
          .toList()
        ..sort((a, b) {
          final aPinned = a['pinned'] == true ? 1 : 0;
          final bPinned = b['pinned'] == true ? 1 : 0;
          if (aPinned != bPinned) return bPinned - aPinned;
          return (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0);
        });
      _filteredNotes = List.from(_notes);
    });
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = _notes.map((n) => jsonEncode(n)).toList();
    await prefs.setStringList('notes', notesJson);
  }

  void _filterNotes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredNotes = _notes.where((note) {
        final matchesSearch = query.isEmpty ||
            (note['title']?.toString().toLowerCase().contains(query) ?? false) ||
            (note['content']?.toString().toLowerCase().contains(query) ?? false);
        final matchesTag = _selectedTag == null || note['tag'] == _selectedTag;
        return matchesSearch && matchesTag;
      }).toList();
    });
  }

  void _showAddNote({Map<String, dynamic>? existingNote, int? editIndex}) {
    _titleController.text = existingNote?['title'] ?? '';
    _contentController.text = existingNote?['content'] ?? '';
    String? noteTag = existingNote?['tag'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.textTertiary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(editIndex != null ? 'Edit Note' : 'New Note',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  autofocus: true,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Note title',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contentController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  maxLines: 8,
                  minLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Write your note... (markdown supported)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
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
                      backgroundColor: AppTheme.cardDark,
                      checkmarkColor: color,
                      labelStyle: TextStyle(color: isSelected ? color : AppTheme.textSecondary, fontSize: 13),
                      side: BorderSide(color: isSelected ? color : AppTheme.cardBorder),
                      onSelected: (selected) {
                        setSheetState(() => noteTag = selected ? tag['name'] as String : null);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_titleController.text.trim().isNotEmpty) {
                            final note = {
                              'title': _titleController.text.trim(),
                              'content': _contentController.text.trim(),
                              'tag': noteTag,
                              'timestamp': DateTime.now().millisecondsSinceEpoch,
                              'pinned': existingNote?['pinned'] ?? false,
                            };
                            setState(() {
                              if (editIndex != null) {
                                _notes[editIndex] = note;
                              } else {
                                _notes.insert(0, note);
                              }
                            });
                            _saveNotes();
                            _filterNotes();
                            Navigator.pop(ctx);
                          }
                        },
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Save Note'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _togglePin(int index) {
    setState(() {
      _notes[index]['pinned'] = !(_notes[index]['pinned'] ?? false);
      _notes.sort((a, b) {
        final aPinned = a['pinned'] == true ? 1 : 0;
        final bPinned = b['pinned'] == true ? 1 : 0;
        if (aPinned != bPinned) return bPinned - aPinned;
        return (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0);
      });
    });
    _saveNotes();
    _filterNotes();
  }

  void _deleteNote(int index) {
    final note = _notes[index];
    setState(() => _notes.removeAt(index));
    _saveNotes();
    _filterNotes();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${note['title']}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() => _notes.insert(index, note));
            _saveNotes();
            _filterNotes();
          },
        ),
      ),
    );
  }

  void _copyNote(Map<String, dynamic> note) {
    final text = '${note['title'] ?? ''}\n\n${note['content'] ?? ''}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📋 Copied to clipboard'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _downloadNote(Map<String, dynamic> note) async {
    final title = note['title'] ?? 'Note';
    final content = '# $title\n\n${note['content'] ?? ''}';
    try {
      final path = await PdfExportService.exportAsFile(title: 'Note_$title', content: content);
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ PDF saved: $path'), backgroundColor: Colors.green.shade800, duration: const Duration(seconds: 4)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
    }
  }

  Future<void> _downloadAllNotes() async {
    if (_notes.isEmpty) return;
    final buffer = StringBuffer();
    buffer.writeln('# My Notebook\n');
    for (int i = 0; i < _notes.length; i++) {
      final note = _notes[i];
      buffer.writeln('## ${i + 1}. ${note['title'] ?? 'Untitled'}');
      if (note['tag'] != null) buffer.writeln('**Tag:** ${note['tag']}');
      buffer.writeln('**Date:** ${_formatDate(note['timestamp'])}\n');
      buffer.writeln(note['content'] ?? '');
      buffer.writeln('\n---\n');
    }
    try {
      final path = await PdfExportService.exportAsFile(title: 'All_Notebook_Notes', content: buffer.toString());
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ PDF saved: $path'), backgroundColor: Colors.green.shade800, duration: const Duration(seconds: 4)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
    }
  }

  // ── AI Assistant Functions ──

  Future<void> _aiAction(Map<String, dynamic> note, int index, String action) async {
    final content = note['content']?.toString() ?? '';
    final title = note['title']?.toString() ?? 'Untitled';
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note is empty — add content first')),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.accentIndigo),
              const SizedBox(height: 16),
              Text('AI is ${action == 'summarize' ? 'summarizing' : action == 'quiz' ? 'generating quiz' : action == 'expand' ? 'expanding' : 'connecting'}...',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, decoration: TextDecoration.none)),
            ],
          ),
        ),
      ),
    );

    try {
      final api = ref.read(apiServiceProvider);
      String prompt;
      String systemPrompt = DeepTutorPrompts.notebookAssistant;

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
          // Gather all note titles and snippets for cross-referencing
          final notesContext = _notes.map((n) => '- ${n['title']}: ${(n['content'] ?? '').toString().substring(0, (n['content']?.toString().length ?? 0).clamp(0, 150))}').join('\n');
          prompt = 'Find connections between this note and my other notes. List shared concepts, contradictions, and complementary ideas.\n\nCurrent Note: $title\nContent:\n$content\n\nAll My Notes:\n$notesContext';
          break;
        default:
          prompt = content;
      }

      final result = await api.callLLM(prompt: prompt, systemInstruction: systemPrompt);

      if (mounted) {
        Navigator.pop(context); // dismiss loading dialog

        // Show result in a bottom sheet
        _showAIResult(title, action, result, index);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Error: $e')));
      }
    }
  }

  void _showAIResult(String noteTitle, String action, String result, int noteIndex) {
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
        height: MediaQuery.of(ctx).size.height * 0.8,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppTheme.textTertiary, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text('$actionLabel — $noteTitle',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                // Copy
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20, color: AppTheme.accentCyan),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: result));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('📋 Copied'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
                // Save as new note
                IconButton(
                  icon: const Icon(Icons.note_add_rounded, size: 20, color: AppTheme.accentGreen),
                  tooltip: 'Save as new note',
                  onPressed: () {
                    final newNote = {
                      'title': '$actionLabel: $noteTitle',
                      'content': result,
                      'tag': action == 'quiz' ? 'Quiz' : action == 'summarize' ? 'Summary' : action == 'connect' ? 'Ideas' : 'Study',
                      'timestamp': DateTime.now().millisecondsSinceEpoch,
                      'pinned': false,
                    };
                    setState(() => _notes.insert(0, newNote));
                    _saveNotes();
                    _filterNotes();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Saved as new note!')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: AppTheme.cardBorder),
            const SizedBox(height: 8),
            Expanded(
              child: SelectionArea(
                child: Markdown(
                  data: result,
                  selectable: true,
                  padding: EdgeInsets.zero,
                  styleSheet: AppTheme.markdownStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoteDetail(Map<String, dynamic> note, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.8,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppTheme.textTertiary, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                if (note['tag'] != null) ...[
                  _buildTagChip(note['tag']),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(note['title'] ?? 'Untitled',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                ),
                IconButton(icon: const Icon(Icons.copy_rounded, size: 20, color: AppTheme.accentCyan),
                    onPressed: () => _copyNote(note), tooltip: 'Copy'),
                IconButton(icon: const Icon(Icons.download_rounded, size: 20, color: AppTheme.accentGreen),
                    onPressed: () => _downloadNote(note), tooltip: 'Download PDF'),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: AppTheme.accentIndigo),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showAddNote(existingNote: note, editIndex: index);
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_formatDate(note['timestamp']),
              style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
            const SizedBox(height: 12),

            // ── AI Actions ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildAIActionChip(Icons.summarize_rounded, 'Summarize', AppTheme.accentGreen,
                      () { Navigator.pop(ctx); _aiAction(note, index, 'summarize'); }),
                  const SizedBox(width: 8),
                  _buildAIActionChip(Icons.quiz_rounded, 'Quiz Me', AppTheme.accentCyan,
                      () { Navigator.pop(ctx); _aiAction(note, index, 'quiz'); }),
                  const SizedBox(width: 8),
                  _buildAIActionChip(Icons.open_in_full_rounded, 'Expand', AppTheme.accentOrange,
                      () { Navigator.pop(ctx); _aiAction(note, index, 'expand'); }),
                  const SizedBox(width: 8),
                  _buildAIActionChip(Icons.hub_rounded, 'Connect', AppTheme.accentViolet,
                      () { Navigator.pop(ctx); _aiAction(note, index, 'connect'); }),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(color: AppTheme.cardBorder),
            const SizedBox(height: 8),
            Expanded(
              child: SelectionArea(
                child: Markdown(
                  data: note['content'] ?? '',
                  selectable: true,
                  padding: EdgeInsets.zero,
                  styleSheet: AppTheme.markdownStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIActionChip(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip(String? tag) {
    if (tag == null) return const SizedBox.shrink();
    final tagData = _availableTags.firstWhere(
      (t) => t['name'] == tag,
      orElse: () => {'name': tag, 'color': 0xFF8B5CF6},
    );
    final color = Color(tagData['color'] as int);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(tag, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year} • '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search notes...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: AppTheme.textTertiary),
                ),
              )
            : const Text('Notebook'),
        actions: [
          if (!_isSearching && _notes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_rounded, color: AppTheme.accentGreen),
              onPressed: _downloadAllNotes,
              tooltip: 'Download all notes as PDF',
            ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filterNotes();
                }
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddNote(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Note'),
        backgroundColor: AppTheme.accentIndigo,
      ),
      body: Column(
        children: [
          // Tag filter bar
          if (!_isSearching)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _selectedTag == null,
                      selectedColor: AppTheme.accentIndigo.withValues(alpha: 0.2),
                      backgroundColor: AppTheme.surfaceDark,
                      labelStyle: TextStyle(
                        color: _selectedTag == null ? AppTheme.accentIndigo : AppTheme.textSecondary, fontSize: 13),
                      side: BorderSide(color: _selectedTag == null ? AppTheme.accentIndigo : AppTheme.cardBorder),
                      onSelected: (_) {
                        setState(() => _selectedTag = null);
                        _filterNotes();
                      },
                    ),
                  ),
                  ..._availableTags.map((tag) {
                    final isSelected = _selectedTag == tag['name'];
                    final color = Color(tag['color'] as int);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tag['name'] as String),
                        selected: isSelected,
                        selectedColor: color.withValues(alpha: 0.2),
                        backgroundColor: AppTheme.surfaceDark,
                        labelStyle: TextStyle(color: isSelected ? color : AppTheme.textSecondary, fontSize: 13),
                        side: BorderSide(color: isSelected ? color : AppTheme.cardBorder),
                        onSelected: (_) {
                          setState(() => _selectedTag = isSelected ? null : tag['name'] as String);
                          _filterNotes();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Notes list
          Expanded(
            child: _filteredNotes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.note_alt_rounded, size: 64,
                            color: const Color(0xFF26C6DA).withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(_notes.isEmpty ? 'Your Notebook is empty' : 'No matching notes',
                          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          _notes.isEmpty
                              ? 'Save study notes, research summaries,\nAI responses, and ideas here'
                              : 'Try a different search or filter',
                          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ).animate().fadeIn(duration: 600.ms),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = _filteredNotes[index];
                      final realIndex = _notes.indexOf(note);
                      final isPinned = note['pinned'] == true;

                      return Dismissible(
                        key: ValueKey(note['timestamp']),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteNote(realIndex),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_rounded, color: Colors.red),
                        ),
                        child: GestureDetector(
                          onTap: () => _showNoteDetail(note, realIndex),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.cardDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isPinned)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: Icon(Icons.push_pin_rounded, size: 14,
                                            color: AppTheme.accentOrange.withValues(alpha: 0.7)),
                                      ),
                                    if (note['tag'] != null) ...[
                                      _buildTagChip(note['tag']),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Text(note['title'] ?? 'Untitled',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textTertiary, size: 18),
                                      color: AppTheme.surfaceDark,
                                      onSelected: (action) {
                                        switch (action) {
                                          case 'pin': _togglePin(realIndex); break;
                                          case 'edit': _showAddNote(existingNote: note, editIndex: realIndex); break;
                                          case 'copy': _copyNote(note); break;
                                          case 'download': _downloadNote(note); break;
                                          case 'summarize': _aiAction(note, realIndex, 'summarize'); break;
                                          case 'quiz': _aiAction(note, realIndex, 'quiz'); break;
                                          case 'delete': _deleteNote(realIndex); break;
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        PopupMenuItem(value: 'pin', child: Row(children: [
                                          Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, size: 18, color: AppTheme.textSecondary),
                                          const SizedBox(width: 8),
                                          Text(isPinned ? 'Unpin' : 'Pin', style: const TextStyle(color: AppTheme.textPrimary)),
                                        ])),
                                        const PopupMenuItem(value: 'edit', child: Row(children: [
                                          Icon(Icons.edit_rounded, size: 18, color: AppTheme.textSecondary),
                                          SizedBox(width: 8),
                                          Text('Edit', style: TextStyle(color: AppTheme.textPrimary)),
                                        ])),
                                        const PopupMenuItem(value: 'summarize', child: Row(children: [
                                          Icon(Icons.auto_awesome_rounded, size: 18, color: AppTheme.accentIndigo),
                                          SizedBox(width: 8),
                                          Text('AI Summarize', style: TextStyle(color: AppTheme.accentIndigo)),
                                        ])),
                                        const PopupMenuItem(value: 'quiz', child: Row(children: [
                                          Icon(Icons.quiz_rounded, size: 18, color: AppTheme.accentCyan),
                                          SizedBox(width: 8),
                                          Text('AI Quiz', style: TextStyle(color: AppTheme.accentCyan)),
                                        ])),
                                        const PopupMenuItem(value: 'copy', child: Row(children: [
                                          Icon(Icons.copy_rounded, size: 18, color: AppTheme.textSecondary),
                                          SizedBox(width: 8),
                                          Text('Copy', style: TextStyle(color: AppTheme.textPrimary)),
                                        ])),
                                        const PopupMenuItem(value: 'download', child: Row(children: [
                                          Icon(Icons.download_rounded, size: 18, color: AppTheme.accentGreen),
                                          SizedBox(width: 8),
                                          Text('Download PDF', style: TextStyle(color: AppTheme.textPrimary)),
                                        ])),
                                        const PopupMenuItem(value: 'delete', child: Row(children: [
                                          Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Colors.red)),
                                        ])),
                                      ],
                                    ),
                                  ],
                                ),
                                if (note['content'] != null && note['content'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(note['content'].toString(),
                                    maxLines: 3, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5)),
                                ],
                                const SizedBox(height: 8),
                                Text(_formatDate(note['timestamp']),
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                              ],
                            ),
                          ).animate(delay: (80 * index).ms).fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
