import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/app_theme.dart';
import '../providers/api_provider.dart';
import '../providers/knowledge_provider.dart';
import '../widgets/rich_content_renderer.dart';
import '../widgets/language_selector.dart';
import '../widgets/export_sheet.dart';


extension ThemeHelper on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get scaffoldBg => isDark ? AppTheme.darkPrimary : AppTheme.primary;
  Color get surfaceColor => isDark ? AppTheme.darkSurface : AppTheme.surface;
  Color get cardBorder => isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder;
  Color get textPri => isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
  Color get textSec => isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
  Color get textTer => isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary;
}

class QuestionGenScreen extends ConsumerStatefulWidget {
  const QuestionGenScreen({super.key});

  @override
  ConsumerState<QuestionGenScreen> createState() => _QuestionGenScreenState();
}

class _QuestionGenScreenState extends ConsumerState<QuestionGenScreen> {
  final _topicController = TextEditingController();
  int _questionCount = 5;
  bool _isGenerating = false;
  List<Map<String, dynamic>> _questions = [];
  final Set<int> _expandedIndices = {};

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generateQuestions() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _questions = [];
      _expandedIndices.clear();
    });

    try {
      final api = ref.read(apiServiceProvider);
      final kb = ref.read(knowledgeProvider).selectedKb;

      String? kbContent;
      if (kb != null) {
        kbContent =
            ref.read(knowledgeProvider.notifier).getKnowledgeBaseContent(kb);
        if (kbContent.isEmpty) kbContent = null;
      }

      final questions = await api.generateQuestions(
        topic: topic,
        count: _questionCount,
        kbContent: kbContent,
      );

      setState(() {
        _questions = questions;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _copyQuestion(String question, String answer) {
    Clipboard.setData(ClipboardData(text: 'Q: $question\nA: $answer'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kbState = ref.watch(knowledgeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Generator'),
        actions: [
          const LanguageSelector(),
          const SizedBox(width: 8),
          if (_questions.isNotEmpty) ...[
            IconButton(
              icon: Icon(Icons.auto_awesome_rounded, color: AppTheme.accentGreen),
              tooltip: 'Export AI Assets (Slides, Mind Map, etc.)',
              onPressed: () {
                final buffer = StringBuffer();
                buffer.writeln('# AI Generated Questions\n');
                for (final q in _questions) {
                  buffer.writeln('## Q: ${q['question']}');
                  buffer.writeln('A: ${q['answer']}');
                  buffer.writeln('\n---\n');
                }
                showExportSheet(context, ref.read(apiServiceProvider), 'AI Generated Questions', buffer.toString());
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // KB Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: Text(
                        kbState.knowledgeBases.isEmpty
                            ? 'No KBs — questions from general knowledge'
                            : 'Select Knowledge Base (optional)',
                        style: TextStyle(color: context.textTer),
                      ),
                      value: (kbState.selectedKb != null && kbState.knowledgeBases.any((kb) => kb['name']?.toString() == kbState.selectedKb)) 
                          ? kbState.selectedKb 
                          : null,
                      dropdownColor: context.surfaceColor,
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('None (General knowledge)',
                              style: TextStyle(color: context.textSec)),
                        ),
                        ...kbState.knowledgeBases.fold<Map<String, Map<String, dynamic>>>({}, (map, kb) {
                          final name = kb['name']?.toString() ?? 'Unknown';
                          if (!map.containsKey(name)) {
                            map[name] = kb;
                          }
                          return map;
                        }).values.map((kb) {
                          final name = kb['name']?.toString() ?? 'Unknown';
                          final docCount = kb['doc_count'] ?? 0;
                          return DropdownMenuItem(
                            value: name,
                            child: Row(
                              children: [
                                Icon(Icons.folder_rounded,
                                    size: 16,
                                    color: AppTheme.accentViolet),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(name,
                                      style: TextStyle(color: context.textPri)),
                                ),
                                Text('$docCount docs',
                                    style: TextStyle(
                                        color: context.textTer,
                                        fontSize: 12)),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) => ref
                          .read(knowledgeProvider.notifier)
                          .selectKnowledgeBase(val),
                    ),
                  ),
                ),
                SizedBox(height: 12),

                // Topic input
                TextField(
                  controller: _topicController,
                  style: TextStyle(color: context.textPri),
                  decoration: InputDecoration(
                    hintText: 'Enter topic (e.g., Neural Networks)',
                    hintStyle: TextStyle(color: context.textTer),
                    prefixIcon: Icon(Icons.topic_rounded,
                        color: context.textTer),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 12),

                // Count selector
                Row(
                  children: [
                    Text('Questions:',
                        style: TextStyle(color: context.textSec)),
                    SizedBox(width: 12),
                    ...List.generate(4, (i) {
                      final count = [3, 5, 10, 15][i];
                      final isSelected = _questionCount == count;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('$count'),
                          selected: isSelected,
                          selectedColor:
                              AppTheme.accentIndigo.withValues(alpha: 0.3),
                          backgroundColor: context.surfaceColor,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppTheme.accentIndigo
                                : context.textSec,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.accentIndigo
                                : context.cardBorder,
                          ),
                          onSelected: (_) =>
                              setState(() => _questionCount = count),
                        ),
                      );
                    }),
                  ],
                ),
                SizedBox(height: 16),

                // Generate button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateQuestions,
                    icon: _isGenerating
                        ? SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: context.textPri),
                          )
                        : Icon(Icons.auto_awesome_rounded),
                    label:
                        Text(_isGenerating ? 'Generating...' : 'Generate'),
                  ),
                ),
              ],
            ),
          ),

          // Questions List
          Expanded(
            child: _questions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.quiz_rounded,
                            size: 64,
                            color: AppTheme.accentGreen
                                .withValues(alpha: 0.3)),
                        SizedBox(height: 16),
                        Text(
                          'No questions generated yet',
                          style: TextStyle(
                              color: context.textTer, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Enter a topic and tap Generate',
                          style: TextStyle(
                              color: context.textTer, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      final q = _questions[index];
                      final isExpanded = _expandedIndices.contains(index);
                      final question = q['question']?.toString() ?? '';
                      final answer = q['answer']?.toString() ?? 'N/A';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.cardBorder),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding:
                                  const EdgeInsets.fromLTRB(16, 4, 4, 4),
                              leading: Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGreen
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: AppTheme.accentGreen,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: RichContentRenderer(
                                content: question,
                                selectable: true,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded,
                                        size: 16,
                                        color: Colors.redAccent),
                                    onPressed: () {
                                      setState(() {
                                        _questions.removeAt(index);
                                        _expandedIndices.remove(index);
                                      });
                                    },
                                    tooltip: 'Delete Question',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.copy_rounded,
                                        size: 16,
                                        color: context.textTer),
                                    onPressed: () =>
                                        _copyQuestion(question, answer),
                                    tooltip: 'Copy Q&A',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isExpanded
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                      color: context.textTer,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedIndices.remove(index);
                                        } else {
                                          _expandedIndices.add(index);
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            if (isExpanded)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                    16, 0, 16, 16),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGreen
                                        .withValues(alpha: 0.05),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppTheme.accentGreen
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: RichContentRenderer(
                                    content: answer,
                                    selectable: true,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                          .animate(delay: (80 * index).ms)
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.1, end: 0);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
