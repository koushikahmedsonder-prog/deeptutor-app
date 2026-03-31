// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/app_theme.dart';
import '../providers/api_provider.dart';
import '../widgets/camera_capture_dialog.dart';
import '../services/document_service.dart';

// ══════════════════════════════════════════════════════════
//  MODELS
// ══════════════════════════════════════════════════════════

enum TaskType { makeQuestions, predictQuestions, scanBook, studyProgress, custom }
enum TaskStatus { pending, inProgress, done }
enum Priority { low, medium, high }

class SubTask {
  String id; String title; bool done;
  SubTask({required this.id, required this.title, this.done = false});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};
  factory SubTask.fromJson(Map<String, dynamic> j) =>
      SubTask(id: j['id'], title: j['title'], done: j['done'] ?? false);
}

class StudyQuestion {
  String id, question;
  String? answer, difficulty, topic, userAnswer;
  bool answered;
  StudyQuestion({required this.id, required this.question, this.answer,
      this.difficulty, this.topic, this.userAnswer, this.answered = false});
  Map<String, dynamic> toJson() => {'id': id, 'question': question,
      'answer': answer, 'difficulty': difficulty, 'topic': topic,
      'userAnswer': userAnswer, 'answered': answered};
  factory StudyQuestion.fromJson(Map<String, dynamic> j) => StudyQuestion(
      id: j['id'], question: j['question'], answer: j['answer'],
      difficulty: j['difficulty'], topic: j['topic'],
      userAnswer: j['userAnswer'], answered: j['answered'] ?? false);
}

class StudyTask {
  String id, title;
  String? description;
  TaskType type; TaskStatus status; Priority priority;
  DateTime createdAt; DateTime? dueDate, completedAt;
  int progress;
  List<String> filePaths, fileNames, scannedPaths;
  List<StudyQuestion> questions;
  List<SubTask> subTasks;

  StudyTask({required this.id, required this.title, this.description,
      required this.type, this.status = TaskStatus.pending,
      this.priority = Priority.medium, required this.createdAt,
      this.dueDate, this.completedAt, this.progress = 0,
      List<String>? filePaths, List<String>? fileNames,
      List<String>? scannedPaths, List<StudyQuestion>? questions,
      List<SubTask>? subTasks})
      : filePaths = filePaths ?? [],
        fileNames = fileNames ?? [],
        scannedPaths = scannedPaths ?? [],
        questions = questions ?? [],
        subTasks = subTasks ?? [];

  Map<String, dynamic> toJson() => {'id': id, 'title': title,
      'description': description, 'type': type.index, 'status': status.index,
      'priority': priority.index, 'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(), 'progress': progress,
      'filePaths': filePaths, 'fileNames': fileNames,
      'scannedPaths': scannedPaths,
      'questions': questions.map((q) => q.toJson()).toList(),
      'subTasks': subTasks.map((s) => s.toJson()).toList()};

  factory StudyTask.fromJson(Map<String, dynamic> j) => StudyTask(
      id: j['id'], title: j['title'], description: j['description'],
      type: TaskType.values[j['type'] as int],
      status: TaskStatus.values[j['status'] as int],
      priority: Priority.values[j['priority'] as int],
      createdAt: DateTime.parse(j['createdAt']),
      dueDate: j['dueDate'] != null ? DateTime.parse(j['dueDate']) : null,
      completedAt: j['completedAt'] != null ? DateTime.parse(j['completedAt']) : null,
      progress: j['progress'] ?? 0,
      filePaths: List<String>.from(j['filePaths'] ?? []),
      fileNames: List<String>.from(j['fileNames'] ?? []),
      scannedPaths: List<String>.from(j['scannedPaths'] ?? []),
      questions: (j['questions'] as List? ?? [])
          .map((q) => StudyQuestion.fromJson(Map<String, dynamic>.from(q))).toList(),
      subTasks: (j['subTasks'] as List? ?? [])
          .map((s) => SubTask.fromJson(Map<String, dynamic>.from(s))).toList());
}

// ══════════════════════════════════════════════════════════
//  STORAGE
// ══════════════════════════════════════════════════════════

class TodoStorage {
  static Box get _box => Hive.box('study_tasks');

  static Future<void> save(StudyTask t) => _box.put(t.id, t.toJson());
  static Future<void> delete(String id) => _box.delete(id);

  static List<StudyTask> all() => _box.values
      .map((e) => StudyTask.fromJson(Map<String, dynamic>.from(e)))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

// ══════════════════════════════════════════════════════════
//  TODO SCREEN
// ══════════════════════════════════════════════════════════

class TodoScreen extends ConsumerStatefulWidget {
  const TodoScreen({super.key});
  @override
  ConsumerState<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends ConsumerState<TodoScreen> {
  List<StudyTask> _tasks = [];
  int _filter = 0; // 0=all 1=pending 2=active 3=done

  @override
  void initState() { super.initState(); _reload(); }

  void _reload() => setState(() => _tasks = TodoStorage.all());

  List<StudyTask> get _filtered {
    switch (_filter) {
      case 1: return _tasks.where((t) => t.status == TaskStatus.pending).toList();
      case 2: return _tasks.where((t) => t.status == TaskStatus.inProgress).toList();
      case 3: return _tasks.where((t) => t.status == TaskStatus.done).toList();
      default: return _tasks;
    }
  }

  int get _totalQ => _tasks.fold(0, (s, t) => s + t.questions.length);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          _filtered.isEmpty
              ? SliverFillRemaining(child: _buildEmpty())
              : SliverList(delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final task = _filtered[i];
                    return _TaskCard(
                      task: task,
                      onTap: () => _openDetail(task),
                      onDelete: () async { await TodoStorage.delete(task.id); _reload(); },
                    ).animate().fadeIn(delay: (i * 40).ms).slideY(begin: 0.1, end: 0);
                  },
                  childCount: _filtered.length,
                )),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accentCyan,
        foregroundColor: Colors.black,
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('New Task', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            color: AppTheme.textSecondary,
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Back',
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.accentCyan, AppTheme.accentIndigo]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.checklist_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Study Planner', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            Text('Track tasks · Generate questions', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          IconButton(
            icon: const Icon(Icons.close),
            color: AppTheme.textSecondary,
            onPressed: () => Navigator.pop(context),
            tooltip: 'Exit',
          ),
        ]),
        const SizedBox(height: 16),
        // Stats row
        Row(children: [
          _StatBox('Total', _tasks.length, AppTheme.accentCyan),
          const SizedBox(width: 8),
          _StatBox('Done', _tasks.where((t) => t.status == TaskStatus.done).length, AppTheme.accentGreen),
          const SizedBox(width: 8),
          _StatBox('Active', _tasks.where((t) => t.status == TaskStatus.inProgress).length, AppTheme.accentOrange),
          const SizedBox(width: 8),
          _StatBox('Questions', _totalQ, AppTheme.accentViolet),
        ]),
        const SizedBox(height: 14),
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (int i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filter = i),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _filter == i ? AppTheme.accentCyan : AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _filter == i ? AppTheme.accentCyan : AppTheme.cardBorder),
                    ),
                    child: Text(
                      ['All', 'Pending', 'Active', 'Done'][i],
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: _filter == i ? Colors.black : AppTheme.textSecondary),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.task_alt_outlined, size: 52, color: AppTheme.textTertiary),
      const SizedBox(height: 12),
      const Text('No tasks yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
      const SizedBox(height: 4),
      const Text('Tap + to add your first study task', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
    ]),
  );

  void _openDetail(StudyTask task) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _TaskDetailScreen(task: task, onSave: _reload),
    ));
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTaskSheet(onAdd: (t) async { await TodoStorage.save(t); _reload(); }),
    );
  }
}

// ── Stat box ────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String label; final int value; final Color color;
  const _StatBox(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(children: [
      Text('$value', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
    ]),
  ));
}

// ══════════════════════════════════════════════════════════
//  TASK CARD
// ══════════════════════════════════════════════════════════

class _TaskCard extends StatelessWidget {
  final StudyTask task; final VoidCallback onTap, onDelete;
  const _TaskCard({required this.task, required this.onTap, required this.onDelete});

  static const _typeIcons = [Icons.quiz_rounded, Icons.psychology_rounded,
      Icons.camera_alt_rounded, Icons.trending_up, Icons.task_alt_rounded];
  static const _typeColors = [AppTheme.accentIndigo, AppTheme.accentViolet,
      AppTheme.accentCyan, AppTheme.accentGreen, AppTheme.accentOrange];
  static const _typeLabels = ['Generate Questions', 'Predict from Prev. Year',
      'Scan Book', 'Progress Tracker', 'Custom Task'];

  Color get _prioColor => [AppTheme.accentCyan, AppTheme.accentOrange, AppTheme.accentPink][task.priority.index];
  Color get _typeColor => _typeColors[task.type.index];

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.done;
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade800,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete(); return true;
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: done ? AppTheme.accentGreen.withOpacity(0.3) : AppTheme.cardBorder,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_typeIcons[task.type.index], size: 16, color: _typeColor),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(task.title,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                        color: done ? AppTheme.textTertiary : AppTheme.textPrimary,
                        decoration: done ? TextDecoration.lineThrough : null),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_typeLabels[task.type.index],
                    style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
              ])),
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: _prioColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              _StatusBadge(task.status),
            ]),
            if (task.progress > 0 || task.type == TaskType.studyProgress) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: task.progress / 100, minHeight: 4,
                    backgroundColor: AppTheme.cardBorder,
                    valueColor: AlwaysStoppedAnimation(done ? AppTheme.accentGreen : AppTheme.accentCyan),
                  ),
                )),
                const SizedBox(width: 8),
                Text('${task.progress}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accentCyan)),
              ]),
            ],
            if (task.questions.isNotEmpty || task.fileNames.isNotEmpty || task.scannedPaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                if (task.questions.isNotEmpty) _Chip(Icons.help_outline, '${task.questions.length} Qs'),
                if (task.fileNames.isNotEmpty) _Chip(Icons.attach_file, '${task.fileNames.length} file(s)'),
                if (task.scannedPaths.isNotEmpty) _Chip(Icons.camera_alt_outlined, '${task.scannedPaths.length} scan(s)'),
              ]),
            ],
            if (task.dueDate != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.schedule, size: 12, color: _isOverdue ? Colors.red : AppTheme.textTertiary),
                const SizedBox(width: 4),
                Text(_dueLabel, style: TextStyle(fontSize: 11, color: _isOverdue ? Colors.red : AppTheme.textTertiary)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  bool get _isOverdue => task.dueDate!.isBefore(DateTime.now()) && task.status != TaskStatus.done;
  String get _dueLabel {
    final d = task.dueDate!.difference(DateTime.now()).inDays;
    if (d == 0) return 'Due today';
    if (d == 1) return 'Due tomorrow';
    if (d < 0) return 'Overdue ${-d}d';
    return 'Due in ${d}d';
  }
}

class _StatusBadge extends StatelessWidget {
  final TaskStatus status;
  const _StatusBadge(this.status);
  static const _labels = ['Pending', 'Active', 'Done'];
  static const _colors = [AppTheme.textTertiary, AppTheme.accentOrange, AppTheme.accentGreen];
  @override
  Widget build(BuildContext context) {
    final c = _colors[status.index];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(_labels[status.index], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon; final String label;
  const _Chip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 11, color: AppTheme.textTertiary),
    const SizedBox(width: 3),
    Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
  ]);
}

// ══════════════════════════════════════════════════════════
//  ADD TASK SHEET
// ══════════════════════════════════════════════════════════

class _AddTaskSheet extends StatefulWidget {
  final Future<void> Function(StudyTask) onAdd;
  const _AddTaskSheet({required this.onAdd});
  @override State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  TaskType _type = TaskType.makeQuestions;
  Priority _priority = Priority.medium;
  final _titleCtrl = TextEditingController();
  DateTime? _due;
  bool _saving = false;

  static const _types = [
    (TaskType.makeQuestions, Icons.quiz_rounded, 'Generate Questions', 'Upload doc → AI creates Qs'),
    (TaskType.predictQuestions, Icons.psychology_rounded, 'Predict from Prev. Year', 'Scan old exam → AI predicts similar Qs'),
    (TaskType.scanBook, Icons.camera_alt_rounded, 'Scan Book Pages', 'Camera scan chapters → study questions'),
    (TaskType.studyProgress, Icons.trending_up, 'Progress Tracker', 'Track chapters & topics'),
    (TaskType.custom, Icons.task_alt_rounded, 'Custom Task', 'Free-form task with sub-tasks'),
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppTheme.cardBorder, borderRadius: BorderRadius.circular(2))),
          Expanded(child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
            const Text('New Study Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            const Text('TASK TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textTertiary, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            ..._types.map((t) => _TypeOption(type: t.$1, icon: t.$2, title: t.$3, subtitle: t.$4,
                selected: _type == t.$1, onTap: () => setState(() => _type = t.$1))),
            const SizedBox(height: 14),
            TextField(controller: _titleCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Task Title', labelStyle: const TextStyle(color: AppTheme.textSecondary),
                  filled: true, fillColor: AppTheme.cardDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.cardBorder)),
                )),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Priority:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(width: 8),
              for (final p in Priority.values) Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _priority = p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _priority == p ? AppTheme.accentCyan : AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _priority == p ? AppTheme.accentCyan : AppTheme.cardBorder),
                    ),
                    child: Text(['Low', 'Med', 'High'][p.index],
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: _priority == p ? Colors.black : AppTheme.textSecondary)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _due = d);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder)),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 10),
                  Text(_due == null ? 'Set due date (optional)' : 'Due: ${_due!.day}/${_due!.month}/${_due!.year}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(height: 50, child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Create Task', style: TextStyle(fontWeight: FontWeight.w700)),
            )),
          ])),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title'))); return;
    }
    setState(() => _saving = true);
    await widget.onAdd(StudyTask(id: const Uuid().v4(), title: _titleCtrl.text.trim(),
        type: _type, priority: _priority, createdAt: DateTime.now(), dueDate: _due));
    if (mounted) Navigator.pop(context);
  }
}

class _TypeOption extends StatelessWidget {
  final TaskType type; final IconData icon; final String title, subtitle; final bool selected; final VoidCallback onTap;
  const _TypeOption({required this.type, required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: 200.ms,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? AppTheme.accentCyan.withOpacity(0.08) : AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppTheme.accentCyan : AppTheme.cardBorder, width: selected ? 1.5 : 0.8),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: selected ? AppTheme.accentCyan : AppTheme.textSecondary),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: selected ? AppTheme.accentCyan : AppTheme.textPrimary)),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
        ])),
        if (selected) const Icon(Icons.check_circle, color: AppTheme.accentCyan, size: 16),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════
//  TASK DETAIL SCREEN
// ══════════════════════════════════════════════════════════

class _TaskDetailScreen extends ConsumerStatefulWidget {
  final StudyTask task; final VoidCallback onSave;
  const _TaskDetailScreen({required this.task, required this.onSave});
  @override ConsumerState<_TaskDetailScreen> createState() => _TaskDetailState();
}

class _TaskDetailState extends ConsumerState<_TaskDetailScreen> with TickerProviderStateMixin {
  late StudyTask _t;
  late TabController _tabs;
  bool _processing = false;
  final _subCtrl = TextEditingController();
  int _questionCount = 5;

  @override
  void initState() {
    super.initState();
    _t = widget.task;
    _tabs = TabController(length: 3, vsync: this);
  }

  Future<void> _save() async { await TodoStorage.save(_t); widget.onSave(); }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.cardDark));

  Future<void> _scanPage() async {
    final doc = await showCameraCapture(context);
    if (doc != null && mounted) {
      setState(() { _t.scannedPaths.add(doc.path ?? ''); _t.status = TaskStatus.inProgress; });
      await _save(); _snack('✅ Page scanned (${_t.scannedPaths.length} total)');
    }
  }

  Future<void> _attachFile() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf', 'txt', 'md', 'docx', 'png', 'jpg'], allowMultiple: true);
    if (r != null && mounted) {
      setState(() {
        for (final f in r.files) { if (f.path != null) { _t.filePaths.add(f.path!); _t.fileNames.add(f.name); } }
        _t.status = TaskStatus.inProgress;
      });
      await _save(); _snack('${r.files.length} file(s) attached');
    }
  }

  Future<void> _runAI() async {
    if (_t.type == TaskType.makeQuestions && _t.filePaths.isEmpty) { _snack('Attach a document first'); return; }
    if (_t.type == TaskType.scanBook && _t.scannedPaths.isEmpty) { _snack('Scan some pages first'); return; }
    if (_t.type == TaskType.predictQuestions && _t.filePaths.isEmpty && _t.scannedPaths.isEmpty) { _snack('Attach or scan a past exam paper first'); return; }

    setState(() => _processing = true);
    try {
      final api = ref.read(apiServiceProvider);
      final context_ = _t.type == TaskType.scanBook
          ? 'Generate $_questionCount study questions with answers from these ${_t.scannedPaths.length} scanned book pages. Mix difficulty levels.'
          : _t.type == TaskType.predictQuestions
              ? 'Based on this previous year exam paper style, predict $_questionCount likely exam questions with answers. Mix difficulty levels.'
              : 'Generate $_questionCount study questions with answers from the uploaded document on topic: "${_t.title}". Mix difficulty levels.';
      
      final studyPlannerSystemPrompt = '''You are a study question generator. Generate exactly $_questionCount questions with answers.

OUTPUT FORMAT — You MUST use this exact format for each question:
Q: [Full question text]
A: [Detailed answer text]
Difficulty: [easy/medium/hard]

RULES:
- Use the exact Q:/A:/Difficulty: prefixes shown above.
- Mix difficulty levels: 30% easy, 50% medium, 20% hard.
- Each answer must be complete and educational.
- Do NOT wrap in markdown, JSON, or any other format.
- Separate each question block with a blank line.
''';
      
      final result = await api.callLLM(prompt: context_, systemInstruction: studyPlannerSystemPrompt, attachment: null, useWebSearch: false);
      
      final List<StudyQuestion> newQs = [];
      final lines = result.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      String? currentQ, currentA, currentD;
      
      for (final line in lines) {
        if (line.startsWith('Q:')) {
          if (currentQ != null && currentQ.isNotEmpty) {
            newQs.add(StudyQuestion(id: const Uuid().v4(), question: currentQ, answer: currentA, difficulty: currentD ?? 'medium'));
          }
          currentQ = line.replaceFirst(RegExp(r'^Q:\s*'), '').trim();
          currentA = null;
          currentD = 'medium';
        } else if (line.startsWith('A:')) {
          currentA = line.replaceFirst(RegExp(r'^A:\s*'), '').trim();
        } else if (line.toLowerCase().startsWith('difficulty:')) {
          currentD = line.substring(11).trim().toLowerCase();
        } else {
          if (currentQ != null && currentA == null) {
            currentQ = currentQ + '\n' + line;
          } else if (currentA != null) {
            currentA = currentA + '\n' + line;
          }
        }
      }
      if (currentQ != null && currentQ.isNotEmpty) {
        newQs.add(StudyQuestion(id: const Uuid().v4(), question: currentQ, answer: currentA, difficulty: currentD ?? 'medium'));
      }
      
      if (newQs.isEmpty) {
        newQs.add(StudyQuestion(id: const Uuid().v4(), question: result.substring(0, result.length > 300 ? 300 : result.length), difficulty: 'medium'));
      }

      setState(() { _t.questions.addAll(newQs); _t.status = TaskStatus.inProgress; if (_t.progress < 20) _t.progress = 20; });
      await _save(); _snack('✅ Generated ${newQs.length} questions!');
      _tabs.animateTo(1); // switch to questions tab
    } catch (e) { _snack('AI error: $e'); }
    finally { if (mounted) setState(() => _processing = false); }
  }

  Future<void> _markDone() async {
    setState(() { _t.status = TaskStatus.done; _t.progress = 100; _t.completedAt = DateTime.now(); });
    await _save(); _snack('🎉 Task completed!');
  }

  Future<void> _toggleSub(String id) async {
    final i = _t.subTasks.indexWhere((s) => s.id == id);
    if (i == -1) return;
    setState(() { _t.subTasks[i].done = !_t.subTasks[i].done; });
    final done = _t.subTasks.where((s) => s.done).length;
    final pct = (done / _t.subTasks.length * 100).round();
    setState(() { _t.progress = pct; if (pct == 100) { _t.status = TaskStatus.done; _t.completedAt = DateTime.now(); } });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(_t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
        actions: [
          if (_t.status != TaskStatus.done)
            IconButton(icon: const Icon(Icons.check_circle_outline, color: AppTheme.accentGreen), tooltip: 'Mark Done', onPressed: _markDone),
          IconButton(icon: const Icon(Icons.close), tooltip: 'Exit', onPressed: () => Navigator.pop(context)),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.accentCyan,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.accentCyan,
          tabs: const [Tab(text: 'Actions'), Tab(text: 'Questions'), Tab(text: 'Progress')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _buildActionsTab(),
        _buildQuestionsTab(),
        _buildProgressTab(),
      ]),
    );
  }

  // ── ACTIONS TAB ─────────────────────────────────────────
  Widget _buildActionsTab() => ListView(padding: const EdgeInsets.all(16), children: [
    // Progress slider
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(
        color: AppTheme.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('PROGRESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textTertiary, letterSpacing: 0.8)),
          Text('${_t.progress}%', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accentCyan)),
        ]),
        Slider(value: _t.progress.toDouble(), min: 0, max: 100, divisions: 20, activeColor: AppTheme.accentCyan,
            onChanged: (v) async { setState(() => _t.progress = v.round()); await _save(); }),
      ]),
    ),
    const SizedBox(height: 12),

    // Action buttons
    if (_t.type == TaskType.scanBook || _t.type == TaskType.predictQuestions) ...[
      _ActionBtn(Icons.camera_alt_rounded, 'Scan Page with Camera',
          '${_t.scannedPaths.length} page(s) scanned', AppTheme.accentCyan, _processingOrNull(false, _scanPage)),
      const SizedBox(height: 8),
    ],
    if (_t.type == TaskType.makeQuestions || _t.type == TaskType.predictQuestions) ...[
      _ActionBtn(Icons.upload_file_rounded, 'Upload Document / Exam Paper',
          _t.fileNames.isEmpty ? 'PDF, DOCX, TXT supported' : _t.fileNames.join(', '), AppTheme.accentIndigo, _attachFile),
      const SizedBox(height: 8),
    ],
    if (_t.type != TaskType.custom && _t.type != TaskType.studyProgress) ...[
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('NUMBER OF QUESTIONS: $_questionCount', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textTertiary, letterSpacing: 0.8)),
      ]),
      Slider(value: _questionCount.toDouble(), min: 1, max: 20, divisions: 19, activeColor: AppTheme.accentViolet,
          onChanged: (v) => setState(() => _questionCount = v.round())),
      const SizedBox(height: 8),
      _ActionBtn(Icons.auto_awesome_rounded, _processing ? 'AI Generating...' : 'Generate $_questionCount Questions',
          'Creates study questions automatically', AppTheme.accentViolet, _processing ? null : _runAI, loading: _processing),
      const SizedBox(height: 16),
    ],

    // Sub-tasks
    const Text('SUB-TASKS / CHAPTERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textTertiary, letterSpacing: 0.8)),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: TextField(controller: _subCtrl, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(hintText: 'Add chapter or topic...', hintStyle: const TextStyle(color: AppTheme.textTertiary),
              filled: true, fillColor: AppTheme.cardDark, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.cardBorder))))),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: () async {
          if (_subCtrl.text.trim().isEmpty) return;
          setState(() => _t.subTasks.add(SubTask(id: const Uuid().v4(), title: _subCtrl.text.trim())));
          _subCtrl.clear(); await _save();
        },
        child: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.accentCyan, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.add, color: Colors.black, size: 20)),
      ),
    ]),
    const SizedBox(height: 8),
    if (_t.subTasks.isEmpty)
      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No chapters added yet', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)))
    else
      ..._t.subTasks.map((s) => CheckboxListTile(
        value: s.done, onChanged: (_) => _toggleSub(s.id),
        activeColor: AppTheme.accentCyan, checkColor: Colors.black,
        title: Text(s.title, style: TextStyle(fontSize: 13, color: s.done ? AppTheme.textTertiary : AppTheme.textPrimary,
            decoration: s.done ? TextDecoration.lineThrough : null)),
        dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
      )),

    // Scanned images
    if (_t.scannedPaths.isNotEmpty) ...[
      const SizedBox(height: 12),
      Text('SCANNED PAGES (${_t.scannedPaths.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textTertiary, letterSpacing: 0.8)),
      const SizedBox(height: 8),
      SizedBox(height: 90, child: ListView.separated(
        scrollDirection: Axis.horizontal, itemCount: _t.scannedPaths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ClipRRect(borderRadius: BorderRadius.circular(8),
            child: Image.file(File(_t.scannedPaths[i]), width: 70, height: 90, fit: BoxFit.cover)),
      )),
    ],
  ]);

  VoidCallback? _processingOrNull(bool loading, VoidCallback fn) => loading ? null : fn;

  // ── QUESTIONS TAB ───────────────────────────────────────
  Widget _buildQuestionsTab() {
    if (_t.questions.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.quiz_outlined, size: 52, color: AppTheme.textTertiary),
      const SizedBox(height: 12),
      const Text('No questions yet', style: TextStyle(color: AppTheme.textSecondary)),
      const SizedBox(height: 4),
      const Text('Use the Actions tab → Run AI to generate questions', style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
    ]));
    final answered = _t.questions.where((q) => q.answered).length;
    return Column(children: [
      Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [AppTheme.accentCyan.withOpacity(0.1), AppTheme.accentIndigo.withOpacity(0.1)]),
            borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.accentCyan.withOpacity(0.2))),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$answered / ${_t.questions.length} answered', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
              value: _t.questions.isEmpty ? 0 : answered / _t.questions.length, minHeight: 5,
              backgroundColor: AppTheme.cardBorder, valueColor: const AlwaysStoppedAnimation(AppTheme.accentCyan),
            )),
          ])),
          const SizedBox(width: 14),
          Text('${_t.questions.isEmpty ? 0 : (answered / _t.questions.length * 100).round()}%',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.accentCyan)),
        ]),
      ),
      Expanded(child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), itemCount: _t.questions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _QuestionCard(q: _t.questions[i], index: i + 1,
          onAnswer: (ans) async {
            setState(() { _t.questions[i].userAnswer = ans; _t.questions[i].answered = true; });
            await _save();
          }),
      )),
    ]);
  }

  // ── PROGRESS TAB ────────────────────────────────────────
  Widget _buildProgressTab() {
    final subDone = _t.subTasks.where((s) => s.done).length;
    final qAnswered = _t.questions.where((q) => q.answered).length;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Center(child: SizedBox(width: 120, height: 120, child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(value: _t.progress / 100, strokeWidth: 10,
            backgroundColor: AppTheme.cardBorder, valueColor: AlwaysStoppedAnimation(_t.progress == 100 ? AppTheme.accentGreen : AppTheme.accentCyan)),
        Text('${_t.progress}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
      ]))),
      const SizedBox(height: 24),
      _ProgBar('Overall Progress', _t.progress, 100, AppTheme.accentCyan),
      if (_t.questions.isNotEmpty) ...[const SizedBox(height: 12), _ProgBar('Questions Answered', qAnswered, _t.questions.length, AppTheme.accentViolet)],
      if (_t.subTasks.isNotEmpty) ...[const SizedBox(height: 12), _ProgBar('Chapters / Sub-tasks', subDone, _t.subTasks.length, AppTheme.accentGreen)],
      if (_t.scannedPaths.isNotEmpty) ...[const SizedBox(height: 12), _ProgBar('Pages Scanned', _t.scannedPaths.length, _t.scannedPaths.length, AppTheme.accentOrange)],
      if (_t.completedAt != null) ...[
        const SizedBox(height: 20),
        Row(children: [
          const Icon(Icons.celebration, size: 18, color: Colors.amber),
          const SizedBox(width: 8),
          Text('Completed on ${_t.completedAt!.day}/${_t.completedAt!.month}/${_t.completedAt!.year}',
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        ]),
      ],
    ]);
  }
}

class _ProgBar extends StatelessWidget {
  final String label; final int value, max; final Color color;
  const _ProgBar(this.label, this.value, this.max, this.color);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
      Text('$value / $max', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]),
    const SizedBox(height: 5),
    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
      value: max == 0 ? 0 : value / max, minHeight: 6, backgroundColor: AppTheme.cardBorder,
      valueColor: AlwaysStoppedAnimation(color),
    )),
  ]);
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String title, subtitle; final Color color; final VoidCallback? onTap; final bool loading;
  const _ActionBtn(this.icon, this.title, this.subtitle, this.color, this.onTap, {this.loading = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedOpacity(opacity: onTap == null ? 0.5 : 1, duration: 200.ms,
      child: Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3))),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: loading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                  : Icon(icon, size: 18, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: color.withOpacity(0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Icon(Icons.chevron_right, color: color.withOpacity(0.4)),
        ]),
      ),
    ),
  );
}

// ── Question Card ───────────────────────────────────────
class _QuestionCard extends StatefulWidget {
  final StudyQuestion q; final int index; final Future<void> Function(String) onAnswer;
  const _QuestionCard({required this.q, required this.index, required this.onAnswer});
  @override State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  bool _showAns = false;
  final _ctrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final diffColor = q.difficulty == 'hard' ? Colors.red.shade400 : q.difficulty == 'medium' ? AppTheme.accentOrange : AppTheme.accentGreen;
    return AnimatedContainer(duration: 200.ms, padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: q.answered ? AppTheme.accentGreen.withOpacity(0.05) : AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: q.answered ? AppTheme.accentGreen.withOpacity(0.3) : AppTheme.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 11, backgroundColor: AppTheme.accentCyan.withOpacity(0.15),
              child: Text('${widget.index}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accentCyan))),
          const SizedBox(width: 8),
          if (q.difficulty != null) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: diffColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(q.difficulty!, style: TextStyle(fontSize: 10, color: diffColor, fontWeight: FontWeight.w600))),
          const Spacer(),
          if (q.answered) const Icon(Icons.check_circle, size: 16, color: AppTheme.accentGreen),
        ]),
        const SizedBox(height: 10),
        Text(q.question, style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textPrimary)),
        if (!q.answered) ...[
          const SizedBox(height: 10),
          TextField(controller: _ctrl, maxLines: 2, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(hintText: 'Write your answer...', hintStyle: const TextStyle(color: AppTheme.textTertiary),
                  filled: true, fillColor: AppTheme.surfaceDark, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.cardBorder)))),
          const SizedBox(height: 8),
          Row(children: [
            if (q.answer != null) TextButton(onPressed: () => setState(() => _showAns = !_showAns),
                child: Text(_showAns ? 'Hide Answer' : 'Show Answer', style: const TextStyle(fontSize: 12, color: AppTheme.accentCyan))),
            const Spacer(),
            GestureDetector(
              onTap: () { if (_ctrl.text.trim().isNotEmpty) widget.onAnswer(_ctrl.text.trim()); },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(color: AppTheme.accentCyan, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Submit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black))),
            ),
          ]),
        ] else if (q.userAnswer != null) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.surfaceDark, borderRadius: BorderRadius.circular(8)),
              child: Text('Your answer: ${q.userAnswer}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
        ],
        if (_showAns && q.answer != null) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.accentCyan.withOpacity(0.07), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentCyan.withOpacity(0.2))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Model Answer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accentCyan)),
                const SizedBox(height: 4),
                Text(q.answer!, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
              ])),
        ],
      ]),
    );
  }
}
