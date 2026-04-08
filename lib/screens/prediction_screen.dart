import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../config/app_theme.dart';
import '../utils/theme_helper.dart';
import '../providers/api_provider.dart';
import '../providers/solver_provider.dart';
import '../services/exam_prediction_service.dart';
import '../services/document_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/action_chip_button.dart';
import '../widgets/exam_question_renderer.dart';
import '../widgets/language_selector.dart';
import 'todo_screen.dart' show StudyTask, StudyQuestion, TaskType, TodoStorage;



class PredictionScreen extends ConsumerStatefulWidget {
  const PredictionScreen({super.key});

  @override
  ConsumerState<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends ConsumerState<PredictionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // State
  List<TeacherProfile> _profiles = [];
  TeacherProfile? _selectedProfile;
  final List<PickedDocument> _uploadedDocs = [];
  bool _isPredicting = false;
  String _predictingStatus = '';
  PredictionResult? _latestResult;

  // Controllers for new profile
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();
  final _extraNotesController = TextEditingController();
  String _diffStyle = 'mixed';
  String _repeatBehavior = 'repeats_important';
  int _questionCount = 5;
  final TextEditingController _focusAreaController = TextEditingController();
  final Set<String> _selectedVisuals = {};
  
  final Map<String, String> _visualOptions = {
    'Diagrams': 'Generate system diagrams or flowchart using Mermaid.js syntax.',
    'Graphs': 'Design plots and analytical graphs using coordinate systems.',
    'Equations': 'Use inline \$ and display \$\$ LaTeX for all mathematical equations.',
    'Images': 'Include relevant web images using [FETCH_IMAGE: "query"].',
    'Mind Maps': 'Create visual mind maps using Mermaid.js (ideal for History or Bio).',
    'Chemical Structures': 'Provide layouts of chemical molecules and reactions.',
    'Architecture': 'Generate software architecture diagrams using Mermaid.js.',
    'Statistical Charts': 'Create pie/bar charts using Mermaid.js for data.',
    'Code Snippets': 'Provide clear, syntax-highlighted code blocks.',
    'Timeline': 'Generate a chronological timeline using Mermaid.js for history.',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfiles();
  }

  void _loadProfiles() {
    setState(() {
      _profiles = PredictionStorageService.getAllProfiles();
      if (_profiles.isEmpty) {
        _selectedProfile = null;
        _latestResult = null;
      } else {
        if (_selectedProfile == null) {
          _selectedProfile = _profiles.first;
        } else {
          // Re-bind to the exact instance in the new list to avoid identity issues in Dropdown
          final matchIdx = _profiles.indexWhere((p) => p.id == _selectedProfile!.id);
          _selectedProfile = matchIdx != -1 ? _profiles[matchIdx] : _profiles.first;
        }
        _loadResultForSelected();
      }
    });
  }

  void _loadResultForSelected() {
    if (_selectedProfile != null) {
      final results = PredictionStorageService.getResultsForProfile(_selectedProfile!.id);
      setState(() {
        _latestResult = results.isNotEmpty ? results.first : null;
      });
    }
  }

  void _saveNewProfile() {
    if (_nameController.text.isEmpty || _subjectController.text.isEmpty) return;
    
    final p = TeacherProfile(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      subject: _subjectController.text.trim(),
      classGrade: 'General', 
      difficultyStyle: _diffStyle,
      repeatBehaviour: _repeatBehavior,
      extraNotes: _extraNotesController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    PredictionStorageService.saveProfile(p).then((_) {
      _nameController.clear();
      _subjectController.clear();
      _extraNotesController.clear();
      _loadProfiles();
      setState(() => _selectedProfile = p);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher Profile saved!'))
      );
    });
  }

  Future<void> _pickDocument() async {
    final docService = ref.read(documentServiceProvider);
    final docs = await docService.pickMultipleDocuments();
    if (docs.isNotEmpty) {
      setState(() => _uploadedDocs.addAll(docs));
    }
  }

  Future<void> _runPrediction() async {
    if (_selectedProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a profile first')));
      return;
    }
    if (_uploadedDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload at least one document constraint past papers')));
      return;
    }
    
    setState(() {
      _isPredicting = true;
      _predictingStatus = 'Analysing documents...';
    });
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      final apiService = ref.read(apiServiceProvider);
      final predictService = ExamPredictionService(apiService);
      
      final focusText = _focusAreaController.text.trim();
      String contextWrapper = "";
      if (focusText.isNotEmpty) {
        contextWrapper += "IMPORTANT CONSTRAINT: ONLY focus on the following chapters/pages/topics for your prediction: $focusText\n\n";
      }
      
      if (_selectedVisuals.isNotEmpty) {
        contextWrapper += "VISUAL REQUIREMENTS (You MUST include these in your questions):\n";
        for (var v in _selectedVisuals) {
           contextWrapper += "- ${_visualOptions[v]}\n";
        }
        contextWrapper += "\n";
      }
          
      final futureDocs = _uploadedDocs.map((d) async {
        final content = await d.readContent();
        return 'Filename: ${d.name}\nContent:\n$content';
      });
      final docContents = await Future.wait(futureDocs);
      
      if (contextWrapper.isNotEmpty) {
        docContents.insert(0, contextWrapper);
      }
      
      if (mounted) {
        setState(() {
          _predictingStatus = 'Generating predictions...';
          _latestResult = null; // Clear previous result so it doesn't mask errors
        });
      }
      final result = await predictService.predict(
        profile: _selectedProfile!,
        uploadedTexts: docContents,
        questionCount: _questionCount,
        confidenceFilter: 'all'
      );
      
      // Auto-create StudyTask
      final task = StudyTask(
        id: const Uuid().v4(),
        title: 'Predicted Exam: ${_selectedProfile!.subject}',
        description: 'Auto-generated from Teacher Fingerprint analysis.',
        type: TaskType.predictQuestions,
        createdAt: DateTime.now(),
        questions: result.questions.map((q) => StudyQuestion(
          id: const Uuid().v4(),
          question: q.question,
          topic: q.topic,
          difficulty: q.confidence,
          feedback: q.reason,
          answer: q.modelAnswer,
          options: q.options ?? [],
          correctOption: q.options != null && q.options!.isNotEmpty ? 'A' : null, // Simplification for mock,
          correct: null,
        )).toList(),
      );
      
      await TodoStorage.save(task);

      setState(() {
        _latestResult = result;
        _isPredicting = false;
        _predictingStatus = '';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prediction complete! Task added to Study Planner.'),
          backgroundColor: AppTheme.accentGreen,
        )
      );
      
    } catch (e, stackTrace) {
      setState(() {
        _isPredicting = false;
        _predictingStatus = '';
      });
      print('Prediction Error: $e');
      print('Stacktrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating predictions. Please try again.'),
          backgroundColor: Colors.red.shade700)
      );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text('Exam Prediction Engine', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          LanguageSelector(),
          SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentOrange,
          labelColor: AppTheme.accentOrange,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            Tab(text: 'Predict'),
            Tab(text: 'Profiles'),
            Tab(text: 'Prompt Lab'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPredictTab(),
          _buildProfilesTab(),
          _buildPromptLabTab(),
        ],
      ),
    );
  }

  // ─── TAB 1: PREDICT ──────────────────────────────────────────────
  Widget _buildPredictTab() {
    if (_profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_rounded, size: 60, color: context.textSec),
            SizedBox(height: 16),
            Text('No Teacher Profiles found.', style: TextStyle(color: context.textPri, fontSize: 18)),
            SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentOrange),
              onPressed: () => _tabController.animateTo(1),
              child: Text('Create Profile'),
            )
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Teacher File', style: AppTheme.sectionHeaderStyle.copyWith(color: context.textPri)),
              SizedBox(height: 12),
              DropdownButtonFormField<TeacherProfile>(
                initialValue: _selectedProfile,
                dropdownColor: context.scaffoldBg,
                style: TextStyle(color: context.textPri),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: _profiles.map((p) => DropdownMenuItem(
                  value: p,
                  child: Text('${p.name} - ${p.subject}'),
                )).toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedProfile = v;
                    _loadResultForSelected();
                  });
                },
              ),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Upload Past Exams / Notes', style: AppTheme.sectionHeaderStyle.copyWith(color: context.textPri)),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _uploadedDocs.map((d) => Chip(
                  label: Text(d.name, style: TextStyle(color: context.textPri)),
                  backgroundColor: context.surfaceColor,
                  onDeleted: () => setState(() => _uploadedDocs.remove(d)),
                )).toList(),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _focusAreaController,
                style: TextStyle(color: context.textPri),
                decoration: InputDecoration(
                  labelText: 'Focus Area (e.g., Chapter 3, Pages 1-10)',
                  filled: true,
                  fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              SizedBox(height: 16),
              Text('Required Visuals', style: AppTheme.sectionHeaderStyle.copyWith(color: context.textPri).copyWith(fontSize: 14)),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _visualOptions.keys.map((key) {
                  final isSelected = _selectedVisuals.contains(key);
                  return FilterChip(
                    label: Text(key, style: TextStyle(color: isSelected ? Colors.black : context.textPri, fontSize: 12)),
                    selected: isSelected,
                    selectedColor: AppTheme.accentCyan,
                    backgroundColor: context.surfaceColor,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedVisuals.add(key);
                        } else {
                          _selectedVisuals.remove(key);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              SizedBox(height: 12),
              ActionChipButton(
                icon: Icons.upload_file_rounded,
                label: 'Add Documents',
                color: AppTheme.accentCyan,
                onTap: _pickDocument,
              ),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Number of Questions to Predict', style: AppTheme.sectionHeaderStyle.copyWith(color: context.textPri)),
                  Text('$_questionCount', style: TextStyle(color: AppTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              Slider(
                value: _questionCount.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: AppTheme.accentOrange,
                inactiveColor: AppTheme.primary,
                onChanged: (v) => setState(() => _questionCount = v.toInt()),
              ),
              Text('Tip: 5-10 questions for best quality results',
                  style: TextStyle(fontSize: 11, color: context.textTer)),
            ],
          ),
        ),
        
        SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: _isPredicting ? SizedBox.shrink() : Icon(Icons.bolt, color: Colors.black),
            label: _isPredicting 
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text(_predictingStatus.isNotEmpty ? _predictingStatus : 'Generating...',
                      style: TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold)),
                ])
              : Text('Generate Predictions', style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: _isPredicting ? null : _runPrediction,
          ),
        ),
        
        SizedBox(height: 24),
        if (_latestResult != null) _buildResultSection(_latestResult!),
      ],
    );
  }

  Future<void> _exportDoc(PredictionResult result, bool asDoc) async {
    final sb = StringBuffer();
    sb.writeln('# Exam Prediction Report');
    sb.writeln('**Teacher:** ${_selectedProfile?.name} \\| **Subject:** ${_selectedProfile?.subject}');
    sb.writeln('**Generated on:** ${result.createdAt.toString().split(' ')[0]}');
    sb.writeln('');
    sb.writeln('## Topic Analysis');
    sb.writeln('**Top Topics expected:** ${result.topTopics.join(', ')}');
    sb.writeln('**Fresh / Risky Topics:** ${result.freshTopics.join(', ')}');
    sb.writeln('');
    sb.writeln('## Predicted Questions');
    
    for (int i = 0; i < result.questions.length; i++) {
       final q = result.questions[i];
       sb.writeln('### Q${i+1} (${q.marks} Marks) ¬ (${q.confidence.toUpperCase()} CONFIDENCE)');
       sb.writeln(q.question);
       sb.writeln('');
       
       if (q.visualType == 'markdown_table' || q.visualType == 'markdown_image') {
         sb.writeln(q.visualPayload);
         sb.writeln('');
       } else if (q.visualType == 'svg' || q.visualType == 'mermaid') {
         sb.writeln('*[Graphic omitted from export. Please view in DeepTutor App]*');
         sb.writeln('');
       }
       
       sb.writeln('---');
    }

    final fileName = 'Exam_Predictions_${_selectedProfile?.subject}';
    final path = asDoc
        ? await PdfExportService.exportAsDoc(title: fileName, content: sb.toString())
        : await PdfExportService.exportAsFile(title: fileName, content: sb.toString());

    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported ${asDoc ? "DOC" : "PDF"} to $path'), backgroundColor: AppTheme.accentGreen));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export ${asDoc ? "DOC" : "PDF"}', style: TextStyle(color: context.textPri))));
    }
  }

  Widget _buildResultSection(PredictionResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Study Planner Banner ──
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.accentGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accentGreen.withOpacity(0.4)),
          ),
          child: Row(children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text(
              '${result.questions.length} questions generated and saved to Study Planner.',
              style: TextStyle(color: AppTheme.accentGreen, fontSize: 13, fontWeight: FontWeight.w600),
            )),
            GestureDetector(
              onTap: _isPredicting ? null : _runPrediction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentOrange.withOpacity(0.4)),
                ),
                child: Text('Generate More', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accentOrange)),
              ),
            ),
          ]),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Prediction Analysis', style: AppTheme.sectionHeaderStyle.copyWith(color: context.textPri)),
            PopupMenuButton<String>(
              icon: Icon(Icons.download_rounded, color: AppTheme.accentCyan),
              tooltip: 'Download',
              color: context.surfaceColor,
              onSelected: (action) {
                if (action == 'pdf') {
                   _exportDoc(result, false);
                } else if (action == 'doc') {
                   _exportDoc(result, true);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'pdf', child: Row(children: [
                  Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Download as PDF', style: TextStyle(color: context.textPri)),
                ])),
                PopupMenuItem(value: 'doc', child: Row(children: [
                  Icon(Icons.description_rounded, size: 18, color: Colors.blueAccent),
                  SizedBox(width: 8),
                  Text('Download as DOC', style: TextStyle(color: context.textPri)),
                ])),
              ],
            ),
          ],
        ),
        SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(child: _buildStatCard('Top Topics', result.topTopics.take(2).join(', '), AppTheme.accentCyan)),
            SizedBox(width: 8),
            Expanded(child: _buildStatCard('Fresh (Risky)', result.freshTopics.take(2).join(', '), AppTheme.accentPink)),
          ],
        ),
        
        SizedBox(height: 24),
        Text('Predicted Questions', style: AppTheme.sectionHeaderStyle.copyWith(color: context.textPri)),
        SizedBox(height: 12),
        
        ...result.questions.asMap().entries.map((entry) {
          final int index = entry.key;
          final PredictedQuestion q = entry.value;
          return ExamQuestionRenderer(
            question: q,
            index: index,
            onDelete: () {
              setState(() {
                result.questions.removeAt(index);
                PredictionStorageService.saveResult(result);
              });
            },
            onSolveAction: () {
              ref.read(solverProvider.notifier).sendSolverQuestion(
                q.question,
                useWebSearch: true,
              );
              context.push('/solver');
            },
          );
        }),
      ],
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          SizedBox(height: 4),
          Text(value.isNotEmpty ? value : 'None found', style: TextStyle(color: context.textPri, fontSize: 14)),
        ],
      ),
    );
  }

  // ─── TAB 2: PROFILES ─────────────────────────────────────────────
  Widget _buildProfilesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create New Profile', style: AppTheme.sectionHeaderStyle.copyWith(color: context.textPri)),
              SizedBox(height: 16),
              TextField(
                controller: _nameController,
                style: TextStyle(color: context.textPri),
                decoration: InputDecoration(
                  labelText: 'Teacher Name (e.g. Mr. Smith)',
                  filled: true, fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _subjectController,
                style: TextStyle(color: context.textPri),
                decoration: InputDecoration(
                  labelText: 'Subject (e.g. Physics)',
                  filled: true, fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              SizedBox(height: 16),
              Text('Difficulty Style', style: TextStyle(color: context.textPri, fontSize: 14)),
              DropdownButton<String>(
                value: _diffStyle,
                dropdownColor: context.scaffoldBg,
                style: TextStyle(color: context.textPri),
                isExpanded: true,
                items: ['mostly_easy', 'mixed', 'mostly_hard', 'conceptual'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _diffStyle = v!),
              ),
              SizedBox(height: 16),
              Text('Repeat Behavior', style: TextStyle(color: context.textPri, fontSize: 14)),
              DropdownButton<String>(
                value: _repeatBehavior,
                dropdownColor: context.scaffoldBg,
                style: TextStyle(color: context.textPri),
                isExpanded: true,
                items: ['never_repeats', 'repeats_important', 'often_repeats', 'repeats_with_changes'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _repeatBehavior = v!),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _extraNotesController,
                style: TextStyle(color: context.textPri),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Custom Instructions / Quirks (e.g. Always asks about exceptions)',
                  filled: true, fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentOrange),
                  onPressed: _saveNewProfile,
                  child: Text('Save Profile'),
                ),
              )
            ],
          ),
        ),
        
        SizedBox(height: 24),
        Text('Saved Profiles', style: AppTheme.sectionHeaderStyle.copyWith(color: context.textPri)),
        SizedBox(height: 12),
        ..._profiles.map((p) => ListTile(
          tileColor: AppTheme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(p.name, style: TextStyle(color: context.textPri, fontWeight: FontWeight.bold)),
          subtitle: Text('${p.subject} • ${p.difficultyStyle}', style: TextStyle(color: context.textSec)),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline, color: AppTheme.accentPink),
            onPressed: () {
              PredictionStorageService.deleteProfile(p.id).then((_) => _loadProfiles());
            },
          ),
        )),
      ],
    );
  }

  // ─── TAB 3: PROMPT LAB ───────────────────────────────────────────
  Widget _buildPromptLabTab() {
    final templates = [
      {'title': 'Write Your Own (Custom)', 'body': 'Use the "Custom Instructions" field when creating a Teacher Profile to inject exact matching rules, quirks, or textbook strictness that the AI should follow when predicting.'},
      {'title': 'The Tricky Numericals Teacher', 'body': StudentPromptTemplates.trickyNumericals},
      {'title': 'The Important Repeater', 'body': StudentPromptTemplates.repeatsImportant},
      {'title': 'The Creative Scenario Maker', 'body': StudentPromptTemplates.creativeTeacher},
      {'title': 'The Strict Textbook Follower', 'body': StudentPromptTemplates.textbookStrict},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          "Learn how to write effective prediction rules by studying these templates. Add your custom rules in the 'Custom Instructions' field under the Profiles tab!",
          style: TextStyle(color: context.textSec, fontSize: 14, height: 1.5),
        ),
        SizedBox(height: 24),
        ...templates.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['title']!, style: TextStyle(color: AppTheme.accentOrange, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(t['body']!, style: TextStyle(color: context.textPri, fontSize: 13, fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
}
