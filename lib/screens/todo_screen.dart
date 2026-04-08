// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/app_theme.dart';
import '../utils/theme_helper.dart';
import '../providers/api_provider.dart';
import '../widgets/camera_capture_dialog.dart';



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
  String? answer, difficulty, topic, userAnswer, feedback, correctOption;
  List<String> options; // MCQ options (A, B, C, D)
  bool answered;
  bool? correct; // null = not checked, true = correct, false = wrong
  StudyQuestion({required this.id, required this.question, this.answer,
      this.difficulty, this.topic, this.userAnswer, this.answered = false,
      this.correct, this.feedback, this.correctOption, List<String>? options})
      : options = options ?? [];
  Map<String, dynamic> toJson() => {'id': id, 'question': question,
      'answer': answer, 'difficulty': difficulty, 'topic': topic,
      'userAnswer': userAnswer, 'answered': answered,
      'correct': correct, 'feedback': feedback,
      'correctOption': correctOption, 'options': options};
  factory StudyQuestion.fromJson(Map<String, dynamic> j) => StudyQuestion(
      id: j['id'], question: j['question'], answer: j['answer'],
      difficulty: j['difficulty'], topic: j['topic'],
      userAnswer: j['userAnswer'], answered: j['answered'] ?? false,
      correct: j['correct'], feedback: j['feedback'],
      correctOption: j['correctOption'],
      options: List<String>.from(j['options'] ?? []));
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
  static Future<void> clearAll() => _box.clear();

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
      backgroundColor: context.scaffoldBg,
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
        icon: Icon(Icons.add),
        label: Text('New Task', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _clearAllTasks() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Clear All Tasks', style: TextStyle(color: context.textPri)),
        content: Text('Are you sure you want to delete ALL study tasks? This cannot be undone.', style: TextStyle(color: context.textSec)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          TextButton(
            onPressed: () async {
              await TodoStorage.clearAll();
              _reload();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Delete All', style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
            icon: Icon(Icons.arrow_back),
            color: context.textSec,
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Back',
          ),
          SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.accentCyan, AppTheme.accentIndigo]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.checklist_rounded, color: context.textPri, size: 22),
          ),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Study Planner', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.textPri)),
            Text('Track tasks · Generate questions', style: TextStyle(fontSize: 10, color: context.textTer), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          if (_tasks.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_rounded),
              color: Colors.red.shade400,
              tooltip: 'Clear All Tasks',
              onPressed: _clearAllTasks,
            ),
          IconButton(
            icon: Icon(Icons.close),
            color: context.textSec,
            onPressed: () => Navigator.pop(context),
            tooltip: 'Exit',
          ),
        ]),
        SizedBox(height: 16),
        // Stats row
        Row(children: [
          _StatBox('Total', _tasks.length, AppTheme.accentCyan),
          SizedBox(width: 8),
          _StatBox('Done', _tasks.where((t) => t.status == TaskStatus.done).length, AppTheme.accentGreen),
          SizedBox(width: 8),
          _StatBox('Active', _tasks.where((t) => t.status == TaskStatus.inProgress).length, AppTheme.accentOrange),
          SizedBox(width: 8),
          _StatBox('Questions', _totalQ, AppTheme.accentViolet),
        ]),
        SizedBox(height: 14),
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
                      color: _filter == i ? AppTheme.accentCyan : context.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _filter == i ? AppTheme.accentCyan : context.cardBorder),
                    ),
                    child: Text(
                      ['All', 'Pending', 'Active', 'Done'][i],
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: _filter == i ? Colors.black : context.textSec),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.task_alt_outlined, size: 52, color: context.textTer),
      SizedBox(height: 12),
      Text('No tasks yet', style: TextStyle(color: context.textSec, fontSize: 15)),
      SizedBox(height: 4),
      Text('Tap + to add your first study task', style: TextStyle(color: context.textTer, fontSize: 12)),
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
        child: Icon(Icons.delete_outline, color: context.textPri),
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
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: done ? AppTheme.accentGreen.withOpacity(0.3) : context.cardBorder,
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
              SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(task.title,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                        color: done ? context.textTer : context.textPri,
                        decoration: done ? TextDecoration.lineThrough : null),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_typeLabels[task.type.index],
                    style: TextStyle(fontSize: 11, color: context.textTer)),
              ])),
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: _prioColor, shape: BoxShape.circle)),
              SizedBox(width: 8),
              _StatusBadge(task.status),
              SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18),
                color: context.textTer,
                tooltip: 'Delete Task',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: onDelete,
              ),
            ]),
            if (task.progress > 0 || task.type == TaskType.studyProgress) ...[
              SizedBox(height: 10),
              Row(children: [
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: task.progress / 100, minHeight: 4,
                    backgroundColor: context.cardBorder,
                    valueColor: AlwaysStoppedAnimation(done ? AppTheme.accentGreen : AppTheme.accentCyan),
                  ),
                )),
                SizedBox(width: 8),
                Text('${task.progress}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accentCyan)),
              ]),
            ],
            if (task.questions.isNotEmpty || task.fileNames.isNotEmpty || task.scannedPaths.isNotEmpty) ...[
              SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                if (task.questions.isNotEmpty) _Chip(Icons.help_outline, '${task.questions.length} Qs'),
                if (task.fileNames.isNotEmpty) _Chip(Icons.attach_file, '${task.fileNames.length} file(s)'),
                if (task.scannedPaths.isNotEmpty) _Chip(Icons.camera_alt_outlined, '${task.scannedPaths.length} scan(s)'),
              ]),
            ],
            if (task.dueDate != null) ...[
              SizedBox(height: 6),
              Row(children: [
                Icon(Icons.schedule, size: 12, color: _isOverdue ? Colors.red : context.textTer),
                SizedBox(width: 4),
                Text(_dueLabel, style: TextStyle(fontSize: 11, color: _isOverdue ? Colors.red : context.textTer)),
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
  static const _colors = [Color(0xFF9CA3AF), AppTheme.accentOrange, AppTheme.accentGreen];
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
    Icon(icon, size: 11, color: context.textTer),
    SizedBox(width: 3),
    Text(label, style: TextStyle(fontSize: 11, color: context.textTer)),
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
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: context.cardBorder, borderRadius: BorderRadius.circular(2))),
          Expanded(child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
            Text('New Study Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.textPri)),
            SizedBox(height: 16),
            Text('TASK TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.textTer, letterSpacing: 0.8)),
            SizedBox(height: 8),
            ..._types.map((t) => _TypeOption(type: t.$1, icon: t.$2, title: t.$3, subtitle: t.$4,
                selected: _type == t.$1, onTap: () => setState(() => _type = t.$1))),
            SizedBox(height: 14),
            TextField(controller: _titleCtrl,
                style: TextStyle(color: context.textPri),
                decoration: InputDecoration(
                  labelText: 'Task Title', labelStyle: TextStyle(color: context.textSec),
                  filled: true, fillColor: context.cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.cardBorder)),
                )),
            SizedBox(height: 12),
            Row(children: [
              Text('Priority:', style: TextStyle(color: context.textSec, fontSize: 13)),
              SizedBox(width: 8),
              for (final p in Priority.values) Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _priority = p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _priority == p ? AppTheme.accentCyan : context.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _priority == p ? AppTheme.accentCyan : context.cardBorder),
                    ),
                    child: Text(['Low', 'Med', 'High'][p.index],
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: _priority == p ? Colors.black : context.textSec)),
                  ),
                ),
              ),
            ]),
            SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _due = d);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.cardBorder)),
                child: Row(children: [
                  Icon(Icons.calendar_today, size: 16, color: context.textSec),
                  SizedBox(width: 10),
                  Text(_due == null ? 'Set due date (optional)' : 'Due: ${_due!.day}/${_due!.month}/${_due!.year}',
                      style: TextStyle(color: context.textSec, fontSize: 13)),
                ]),
              ),
            ),
            SizedBox(height: 20),
            SizedBox(height: 50, child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _saving ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text('Create Task', style: TextStyle(fontWeight: FontWeight.w700)),
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
        color: selected ? AppTheme.accentCyan.withOpacity(0.08) : context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppTheme.accentCyan : context.cardBorder, width: selected ? 1.5 : 0.8),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: selected ? AppTheme.accentCyan : context.textSec),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: selected ? AppTheme.accentCyan : context.textPri)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: context.textTer)),
        ])),
        if (selected) Icon(Icons.check_circle, color: AppTheme.accentCyan, size: 16),
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
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: _t.questions.isNotEmpty ? 1 : 0,
    );
  }

  Future<void> _save() async { await TodoStorage.save(_t); widget.onSave(); }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.card));

  Future<void> _scanPage() async {
    final doc = await showCameraCapture(context);
    if (doc != null && mounted) {
      setState(() { _t.scannedPaths.add(doc.path); _t.status = TaskStatus.inProgress; });
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
          ? 'Generate $_questionCount MCQ questions from these ${_t.scannedPaths.length} scanned book pages.'
          : _t.type == TaskType.predictQuestions
              ? 'Based on this previous year exam paper style, predict $_questionCount likely MCQ exam questions.'
              : 'Generate $_questionCount MCQ questions from the uploaded document on topic: "${_t.title}".';
      
      final studyPlannerSystemPrompt = '''You are an MCQ question generator. Generate exactly $_questionCount multiple choice questions.

OUTPUT FORMAT — Use this EXACT format for each question (no markdown, no JSON):

Q: [Question text]
A) [Option A text]
B) [Option B text]
C) [Option C text]
D) [Option D text]
ANSWER: [A or B or C or D]
DIFFICULTY: [easy/medium/hard]

RULES:
- Every question MUST have exactly 4 options: A, B, C, D.
- ANSWER must be a single letter: A, B, C, or D.
- Mix difficulty: 30% easy, 50% medium, 20% hard.
- Options should be plausible — no joke answers.
- Separate each question block with a blank line.
''';
      
      final result = await api.callLLM(prompt: context_, systemInstruction: studyPlannerSystemPrompt, attachment: null, useWebSearch: false);
      
      final List<StudyQuestion> newQs = [];
      final lines = result.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      String? currentQ, currentD, correctOpt;
      List<String> currentOpts = [];
      
      for (final line in lines) {
        if (line.startsWith('Q:') || line.startsWith('Q.')) {
          // Save previous question
          if (currentQ != null && currentQ.isNotEmpty && currentOpts.length == 4) {
            newQs.add(StudyQuestion(
              id: const Uuid().v4(), question: currentQ,
              options: List.from(currentOpts),
              correctOption: correctOpt ?? 'A',
              answer: correctOpt != null && currentOpts.length == 4
                  ? currentOpts[{'A':0,'B':1,'C':2,'D':3}[correctOpt] ?? 0]
                  : null,
              difficulty: currentD ?? 'medium',
            ));
          }
          currentQ = line.replaceFirst(RegExp(r'^Q[:.]\s*'), '').trim();
          currentOpts = [];
          currentD = 'medium';
          correctOpt = null;
        } else if (RegExp(r'^[A-D][).]').hasMatch(line)) {
          currentOpts.add(line.substring(2).trim());
        } else if (line.toUpperCase().startsWith('ANSWER:') || line.toUpperCase().startsWith('ANSWER :')) {
          correctOpt = line.replaceFirst(RegExp(r'^ANSWER\s*:\s*', caseSensitive: false), '').trim().toUpperCase();
          if (correctOpt.length > 1) correctOpt = correctOpt.substring(0, 1);
        } else if (line.toUpperCase().startsWith('DIFFICULTY:')) {
          currentD = line.substring(11).trim().toLowerCase();
        } else if (currentQ != null && currentOpts.isEmpty) {
          // Multi-line question
          currentQ = '$currentQ\n$line';
        }
      }
      // Save last question
      if (currentQ != null && currentQ.isNotEmpty && currentOpts.length == 4) {
        newQs.add(StudyQuestion(
          id: const Uuid().v4(), question: currentQ,
          options: List.from(currentOpts),
          correctOption: correctOpt ?? 'A',
          answer: correctOpt != null && currentOpts.length == 4
              ? currentOpts[{'A':0,'B':1,'C':2,'D':3}[correctOpt] ?? 0]
              : null,
          difficulty: currentD ?? 'medium',
        ));
      }
      
      if (newQs.isEmpty) {
        _snack('⚠️ Could not parse MCQ questions. Try again.');
      } else {
        // ── CLEAR old questions and REPLACE with new batch ──
        setState(() {
          _t.questions.clear();
          _t.questions.addAll(newQs);
          _t.status = TaskStatus.inProgress;
          if (_t.progress < 20) _t.progress = 20;
        });
        await _save(); _snack('✅ Generated ${newQs.length} MCQ questions!');
        _tabs.animateTo(1); // switch to questions tab
      }
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
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        title: Text(_t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15)),
        actions: [
          if (_t.status != TaskStatus.done)
            IconButton(icon: Icon(Icons.check_circle_outline, color: AppTheme.accentGreen), tooltip: 'Mark Done', onPressed: _markDone),
          IconButton(icon: Icon(Icons.close), tooltip: 'Exit', onPressed: () => Navigator.pop(context)),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.accentCyan,
          unselectedLabelColor: context.textSec,
          indicatorColor: AppTheme.accentCyan,
          tabs: [Tab(text: 'Actions'), Tab(text: 'Questions'), Tab(text: 'Progress')],
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
  Widget _buildActionsTab() => Container(
    color: context.scaffoldBg,
    child: ListView(padding: const EdgeInsets.all(16), children: [
    // Progress slider
    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(
        color: context.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('PROGRESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.textTer, letterSpacing: 0.8)),
          Text('${_t.progress}%', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.accentCyan)),
        ]),
        Slider(value: _t.progress.toDouble(), min: 0, max: 100, divisions: 20, activeColor: AppTheme.accentCyan,
            onChanged: (v) async { setState(() => _t.progress = v.round()); await _save(); }),
      ]),
    ),
    SizedBox(height: 12),

    // Action buttons
    if (_t.type == TaskType.scanBook || _t.type == TaskType.predictQuestions) ...[
      _ActionBtn(Icons.camera_alt_rounded, 'Scan Page with Camera',
          '${_t.scannedPaths.length} page(s) scanned', AppTheme.accentCyan, _processingOrNull(false, _scanPage)),
      SizedBox(height: 8),
    ],
    if (_t.type == TaskType.makeQuestions || _t.type == TaskType.predictQuestions) ...[
      _ActionBtn(Icons.upload_file_rounded, 'Upload Document / Exam Paper',
          _t.fileNames.isEmpty ? 'PDF, DOCX, TXT supported' : _t.fileNames.join(', '), AppTheme.accentIndigo, _attachFile),
      SizedBox(height: 8),
    ],
    if (_t.type != TaskType.custom && _t.type != TaskType.studyProgress) ...[
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('NUMBER OF QUESTIONS: $_questionCount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.textTer, letterSpacing: 0.8)),
      ]),
      Slider(value: _questionCount.toDouble(), min: 1, max: 100, divisions: 99, activeColor: AppTheme.accentViolet,
          onChanged: (v) => setState(() => _questionCount = v.round())),
      SizedBox(height: 8),
      _ActionBtn(Icons.auto_awesome_rounded, _processing ? 'AI Generating...' : 'Generate $_questionCount Questions',
          'Creates study questions automatically', AppTheme.accentViolet, _processing ? null : _runAI, loading: _processing),
      SizedBox(height: 16),
    ],

    // Sub-tasks
    Text('SUB-TASKS / CHAPTERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.textTer, letterSpacing: 0.8)),
    SizedBox(height: 8),
    Row(children: [
      Expanded(child: TextField(controller: _subCtrl, style: TextStyle(color: context.textPri, fontSize: 13),
          decoration: InputDecoration(hintText: 'Add chapter or topic...', hintStyle: TextStyle(color: context.textTer),
              filled: true, fillColor: context.cardColor, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.cardBorder))))),
      SizedBox(width: 8),
      GestureDetector(
        onTap: () async {
          if (_subCtrl.text.trim().isEmpty) return;
          setState(() => _t.subTasks.add(SubTask(id: const Uuid().v4(), title: _subCtrl.text.trim())));
          _subCtrl.clear(); await _save();
        },
        child: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.accentCyan, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.add, color: Colors.black, size: 20)),
      ),
    ]),
    SizedBox(height: 8),
    if (_t.subTasks.isEmpty)
      Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No chapters added yet', style: TextStyle(color: context.textTer, fontSize: 13)))
    else
      ..._t.subTasks.map((s) => CheckboxListTile(
        value: s.done, onChanged: (_) => _toggleSub(s.id),
        activeColor: AppTheme.accentCyan, checkColor: Colors.black,
        title: Text(s.title, style: TextStyle(fontSize: 13, color: s.done ? context.textTer : context.textPri,
            decoration: s.done ? TextDecoration.lineThrough : null)),
        dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
      )),

    // Scanned images
    if (_t.scannedPaths.isNotEmpty) ...[
      SizedBox(height: 12),
      Text('SCANNED PAGES (${_t.scannedPaths.length})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.textTer, letterSpacing: 0.8)),
      SizedBox(height: 8),
      SizedBox(height: 90, child: ListView.separated(
        scrollDirection: Axis.horizontal, itemCount: _t.scannedPaths.length,
        separatorBuilder: (_, __) => SizedBox(width: 8),
        itemBuilder: (_, i) => ClipRRect(borderRadius: BorderRadius.circular(8),
            child: Image.file(File(_t.scannedPaths[i]), width: 70, height: 90, fit: BoxFit.cover)),
      )),
    ],
  ]));

  VoidCallback? _processingOrNull(bool loading, VoidCallback fn) => loading ? null : fn;

  // ── QUESTIONS TAB ───────────────────────────────────────
  Widget _buildQuestionsTab() {
    if (_t.questions.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.quiz_outlined, size: 52, color: context.textTer),
      SizedBox(height: 12),
      Text('No questions yet', style: TextStyle(color: context.textSec)),
      SizedBox(height: 4),
      Text('Use the Actions tab → Run AI to generate questions', style: TextStyle(fontSize: 12, color: context.textTer)),
    ]));
    }
    final answered = _t.questions.where((q) => q.answered).length;
    final correct = _t.questions.where((q) => q.correct == true).length;
    final wrong = _t.questions.where((q) => q.correct == false).length;
    final unanswered = _t.questions.length - answered;
    
    return Container(
      color: context.scaffoldBg,
      child: Column(children: [
      Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [AppTheme.accentCyan.withOpacity(0.1), AppTheme.accentIndigo.withOpacity(0.1)]),
            borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.accentCyan.withOpacity(0.2))),
        child: Column(children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$answered / ${_t.questions.length} answered', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.textPri)),
              SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                value: _t.questions.isEmpty ? 0 : answered / _t.questions.length, minHeight: 5,
                backgroundColor: context.cardBorder, valueColor: const AlwaysStoppedAnimation(AppTheme.accentCyan),
              )),
            ])),
            SizedBox(width: 14),
            Text('${_t.questions.isEmpty ? 0 : (answered / _t.questions.length * 100).round()}%',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.accentCyan)),
          ]),
          
          // ── Score breakdown ──
          if (answered > 0) ...[
            SizedBox(height: 10),
            Row(children: [
              _ScorePill('✅ $correct', AppTheme.accentGreen),
              SizedBox(width: 8),
              _ScorePill('❌ $wrong', Colors.red.shade400),
              SizedBox(width: 8),
              _ScorePill('⏳ $unanswered', context.textTer),
              Spacer(),
              if (wrong > 0)
                GestureDetector(
                  onTap: _retryIncorrect,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentOrange.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.refresh_rounded, size: 14, color: AppTheme.accentOrange),
                      SizedBox(width: 4),
                      Text('Retry Wrong', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accentOrange)),
                    ]),
                  ),
                ),
            ]),
          ],
        ]),
      ),
      Expanded(child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), itemCount: _t.questions.length,
        separatorBuilder: (_, __) => SizedBox(height: 10),
        itemBuilder: (ctx, i) => _QuestionCard(q: _t.questions[i], index: i + 1,
          onAnswer: (ans) async {
            setState(() { _t.questions[i].userAnswer = ans; _t.questions[i].answered = true; });
            await _save();
            _checkAnswer(i, ans);
          }),
      )),
    ]));
  }

  /// Reset all incorrect answers so the user can re-attempt them
  void _retryIncorrect() {
    setState(() {
      for (final q in _t.questions) {
        if (q.correct == false) {
          q.answered = false;
          q.userAnswer = null;
          q.correct = null;
          q.feedback = null;
        }
      }
    });
    _save();
    _snack('🔄 Incorrect questions reset — try again!');
  }

  void _checkAnswer(int index, String userAnswer) {
    final q = _t.questions[index];

    // ── MCQ: Instant check — just compare the option letter ──
    if (q.options.isNotEmpty && q.correctOption != null) {
      final isCorrect = userAnswer.trim().toUpperCase() == q.correctOption!.trim().toUpperCase();
      final correctIdx = {'A':0,'B':1,'C':2,'D':3}[q.correctOption!.trim().toUpperCase()] ?? 0;
      final correctText = correctIdx < q.options.length ? q.options[correctIdx] : q.correctOption!;
      setState(() {
        _t.questions[index].correct = isCorrect;
        _t.questions[index].feedback = isCorrect
            ? '✅ Correct!'
            : '❌ The correct answer is ${q.correctOption}: $correctText';
      });
      _save();
      return;
    }

    // ── Fallback for non-MCQ (legacy) ──
    if (q.answer == null || q.answer!.isEmpty) return;
    final u = userAnswer.trim().toLowerCase();
    final c = q.answer!.trim().toLowerCase();
    final isCorrect = u == c || c.contains(u) && u.length > 3 || u.contains(c) && c.length > 3;
    setState(() {
      _t.questions[index].correct = isCorrect;
      _t.questions[index].feedback = isCorrect
          ? 'Correct! Matches the expected answer.'
          : 'Incorrect — review the model answer.';
    });
    _save();
  }

  // ── PROGRESS TAB ────────────────────────────────────────
  Widget _buildProgressTab() {
    final subDone = _t.subTasks.where((s) => s.done).length;
    final qAnswered = _t.questions.where((q) => q.answered).length;
    final qCorrect = _t.questions.where((q) => q.correct == true).length;
    final qWrong = _t.questions.where((q) => q.correct == false).length;
    final scorePercent = qAnswered > 0 ? (qCorrect / qAnswered * 100).round() : 0;
    
    return ListView(padding: const EdgeInsets.all(20), children: [
      // Main progress circle
      Center(child: SizedBox(width: 120, height: 120, child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(value: _t.progress / 100, strokeWidth: 10,
            backgroundColor: context.cardBorder, valueColor: AlwaysStoppedAnimation(_t.progress == 100 ? AppTheme.accentGreen : AppTheme.accentCyan)),
        Text('${_t.progress}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPri)),
      ]))),
      SizedBox(height: 24),
      _ProgBar('Overall Progress', _t.progress, 100, AppTheme.accentCyan),
      if (_t.questions.isNotEmpty) ...[
        SizedBox(height: 12), 
        _ProgBar('Questions Answered', qAnswered, _t.questions.length, AppTheme.accentViolet),
        
        // ── Score breakdown ──
        if (qAnswered > 0) ...[
          SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                scorePercent >= 70 ? AppTheme.accentGreen.withOpacity(0.08) : AppTheme.accentOrange.withOpacity(0.08),
                context.cardColor,
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scorePercent >= 70 ? AppTheme.accentGreen.withOpacity(0.2) : AppTheme.accentOrange.withOpacity(0.2),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(
                  scorePercent >= 70 ? Icons.emoji_events_rounded : Icons.school_rounded,
                  size: 18, color: scorePercent >= 70 ? Colors.amber : AppTheme.accentOrange,
                ),
                SizedBox(width: 8),
                Text('Score: $scorePercent%',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                        color: scorePercent >= 70 ? AppTheme.accentGreen : AppTheme.accentOrange)),
                Spacer(),
                Text(
                  scorePercent >= 90 ? '🌟 Excellent!' : scorePercent >= 70 ? '👍 Good job!' : scorePercent >= 50 ? '📖 Keep studying!' : '💪 Try again!',
                  style: TextStyle(fontSize: 13, color: context.textSec),
                ),
              ]),
              SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _StatCol('✅ Correct', '$qCorrect', AppTheme.accentGreen),
                _StatCol('❌ Wrong', '$qWrong', Colors.red.shade400),
                _StatCol('⏳ Left', '${_t.questions.length - qAnswered}', context.textTer),
              ]),
            ]),
          ),
        ],
      ],
      if (_t.subTasks.isNotEmpty) ...[SizedBox(height: 12), _ProgBar('Chapters / Sub-tasks', subDone, _t.subTasks.length, AppTheme.accentGreen)],
      if (_t.scannedPaths.isNotEmpty) ...[SizedBox(height: 12), _ProgBar('Pages Scanned', _t.scannedPaths.length, _t.scannedPaths.length, AppTheme.accentOrange)],
      if (_t.completedAt != null) ...[
        SizedBox(height: 20),
        Row(children: [
          Icon(Icons.celebration, size: 18, color: Colors.amber),
          SizedBox(width: 8),
          Text('Completed on ${_t.completedAt!.day}/${_t.completedAt!.month}/${_t.completedAt!.year}',
              style: TextStyle(color: context.textPri, fontWeight: FontWeight.w600)),
        ]),
      ],
    ]);
  }
}

class _StatCol extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCol(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
    SizedBox(height: 2),
    Text(label, style: TextStyle(fontSize: 11, color: context.textSec)),
  ]);
}

class _ScorePill extends StatelessWidget {
  final String text;
  final Color color;
  const _ScorePill(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );
}

class _ProgBar extends StatelessWidget {
  final String label; final int value, max; final Color color;
  const _ProgBar(this.label, this.value, this.max, this.color);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.textPri)),
      Text('$value / $max', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]),
    SizedBox(height: 5),
    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
      value: max == 0 ? 0 : value / max, minHeight: 6, backgroundColor: context.cardBorder,
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
          SizedBox(width: 12),
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
  String? _selected; // currently selected MCQ option letter

  /// Strip markdown bold markers (**text** → text)
  String _clean(String s) => s.replaceAll(RegExp(r'\*{1,2}'), '').trim();

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final isMCQ = q.options.isNotEmpty;
    final diffColor = q.difficulty == 'hard' ? Colors.red.shade400 : q.difficulty == 'medium' ? AppTheme.accentOrange : AppTheme.accentGreen;
    final labels = ['A', 'B', 'C', 'D'];

    // Determine card color based on correctness
    Color cardBg = context.cardColor;
    Color cardBorderC = context.cardBorder;
    if (q.answered && q.correct != null) {
      if (q.correct!) {
        cardBg = AppTheme.accentGreen.withOpacity(0.05);
        cardBorderC = AppTheme.accentGreen.withOpacity(0.3);
      } else {
        cardBg = Colors.red.withOpacity(0.05);
        cardBorderC = Colors.red.withOpacity(0.3);
      }
    }

    return AnimatedContainer(duration: 200.ms, padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderC),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header: number, difficulty, status ──
        Row(children: [
          CircleAvatar(radius: 11, backgroundColor: AppTheme.accentCyan.withOpacity(0.15),
              child: Text('${widget.index}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accentCyan))),
          SizedBox(width: 8),
          if (q.difficulty != null) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: diffColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(q.difficulty!, style: TextStyle(fontSize: 10, color: diffColor, fontWeight: FontWeight.w600))),
          Spacer(),
          if (q.answered && q.correct != null) ...[
            Icon(q.correct! ? Icons.check_circle : Icons.cancel, size: 16,
                color: q.correct! ? AppTheme.accentGreen : Colors.red.shade400),
          ],
        ]),
        SizedBox(height: 10),
        Text(_clean(q.question), style: TextStyle(fontSize: 14, height: 1.5, color: context.textPri)),

        // ── MCQ Options ──
        if (isMCQ && !q.answered) ...[
          SizedBox(height: 12),
          ...List.generate(q.options.length, (i) {
            final letter = i < labels.length ? labels[i] : '?';
            final isSelected = _selected == letter;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selected = letter);
                  // Submit immediately on tap
                  widget.onAnswer(letter);
                },
                child: AnimatedContainer(
                  duration: 150.ms,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.accentCyan.withOpacity(0.12) : context.surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppTheme.accentCyan : context.cardBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.accentCyan : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? AppTheme.accentCyan : context.textTer, width: 1.5),
                      ),
                      child: Center(child: Text(letter, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.black : context.textSec,
                      ))),
                    ),
                    SizedBox(width: 10),
                    Expanded(child: Text(_clean(q.options[i]),
                        style: TextStyle(fontSize: 13, color: isSelected ? AppTheme.accentCyan : context.textPri))),
                  ]),
                ),
              ),
            );
          }),
        ],

        // ── MCQ Options AFTER answering (show which was correct/wrong) ──
        if (isMCQ && q.answered) ...[
          SizedBox(height: 12),
          ...List.generate(q.options.length, (i) {
            final letter = i < labels.length ? labels[i] : '?';
            final isCorrectOption = letter == q.correctOption?.toUpperCase();
            final isUserPick = letter == q.userAnswer?.toUpperCase();
            Color optBg = context.surfaceColor;
            Color optBorder = context.cardBorder;
            Color optText = context.textPri;
            Color circleColor = context.textTer;

            if (isCorrectOption) {
              optBg = AppTheme.accentGreen.withOpacity(0.1);
              optBorder = AppTheme.accentGreen.withOpacity(0.5);
              optText = AppTheme.accentGreen;
              circleColor = AppTheme.accentGreen;
            } else if (isUserPick && !isCorrectOption) {
              optBg = Colors.red.withOpacity(0.1);
              optBorder = Colors.red.withOpacity(0.5);
              optText = Colors.red.shade300;
              circleColor = Colors.red.shade400;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: optBg, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: optBorder),
                ),
                child: Row(children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: (isCorrectOption || isUserPick) ? circleColor : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: circleColor, width: 1.5),
                    ),
                    child: Center(child: isCorrectOption
                        ? Icon(Icons.check, size: 14, color: Colors.black)
                        : isUserPick
                            ? Icon(Icons.close, size: 14, color: context.textPri)
                            : Text(letter, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.textTer))),
                  ),
                  SizedBox(width: 10),
                  Expanded(child: Text(_clean(q.options[i]),
                      style: TextStyle(fontSize: 13, color: optText,
                          fontWeight: isCorrectOption ? FontWeight.w600 : FontWeight.normal,
                          decoration: isUserPick && !isCorrectOption ? TextDecoration.lineThrough : null))),
                  if (isCorrectOption)
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.accentGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                      child: Text('✓ Correct', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.accentGreen)),
                    ),
                ]),
              ),
            );
          }),
          // Feedback text
          if (q.feedback != null && q.feedback!.isNotEmpty) ...[
            SizedBox(height: 6),
            Text(q.feedback!, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic,
                color: q.correct == true ? AppTheme.accentGreen : context.textSec)),
          ],
        ],

        // ── Fallback: text input for non-MCQ legacy questions ──
        if (!isMCQ && !q.answered) ...[
          SizedBox(height: 10),
          TextField(controller: _ctrl, maxLines: 2, style: TextStyle(color: context.textPri, fontSize: 13),
              decoration: InputDecoration(hintText: 'Write your answer...', hintStyle: TextStyle(color: context.textTer),
                  filled: true, fillColor: context.surfaceColor, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.cardBorder)))),
          SizedBox(height: 8),
          Row(children: [
            Spacer(),
            GestureDetector(
              onTap: () { if (_ctrl.text.trim().isNotEmpty) widget.onAnswer(_ctrl.text.trim()); },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(color: AppTheme.accentCyan, borderRadius: BorderRadius.circular(8)),
                  child: Text('Submit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black))),
            ),
          ]),
        ],

        // ── Non-MCQ: Show feedback after submission ──
        if (!isMCQ && q.answered && q.userAnswer != null) ...[
          SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: q.correct == true ? AppTheme.accentGreen.withOpacity(0.08) : Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: q.correct == true ? AppTheme.accentGreen.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(q.correct == true ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 14,
                    color: q.correct == true ? AppTheme.accentGreen : Colors.red.shade400),
                SizedBox(width: 6),
                Text(q.correct == true ? 'Correct!' : 'Incorrect',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: q.correct == true ? AppTheme.accentGreen : Colors.red.shade400)),
              ]),
              SizedBox(height: 4),
              Text('Your answer: ${q.userAnswer}', style: TextStyle(fontSize: 12, color: context.textSec)),
              if (q.feedback != null) Text(q.feedback!, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: context.textSec)),
            ]),
          ),
        ],

        // ── Answer reveal (for non-MCQ only) ──
        if (!isMCQ && q.answer != null && q.answer!.isNotEmpty) ...[
          SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _showAns = !_showAns),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _showAns ? AppTheme.accentCyan.withOpacity(0.08) : AppTheme.accentViolet.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _showAns ? AppTheme.accentCyan.withOpacity(0.3) : AppTheme.accentViolet.withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(_showAns ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 16,
                    color: _showAns ? AppTheme.accentCyan : AppTheme.accentViolet),
                SizedBox(width: 8),
                Text(_showAns ? 'Hide Answer' : 'Tap to Reveal Answer',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: _showAns ? AppTheme.accentCyan : AppTheme.accentViolet)),
              ]),
            ),
          ),
          if (_showAns) ...[
            SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentCyan.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accentCyan.withOpacity(0.2)),
              ),
              child: Text(_clean(q.answer!), style: TextStyle(fontSize: 13, height: 1.6, color: context.textPri)),
            ),
          ],
        ],
      ]),
    );
  }
}
