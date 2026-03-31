import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/app_theme.dart';
import '../providers/api_provider.dart';
import '../providers/knowledge_provider.dart';
import '../services/pdf_export_service.dart';

class QuestionGenScreen extends ConsumerStatefulWidget {
  const QuestionGenScreen({super.key});

  @override
  ConsumerState<QuestionGenScreen> createState() => _QuestionGenScreenState();
}

class _QuestionGenScreenState extends ConsumerState<QuestionGenScreen> {
  final _topicController = TextEditingController();
  int _questionCount = 5;
  bool _isGenerating = false;
  bool _isExporting = false;
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

  Future<void> _downloadQuestions() async {
    if (_questions.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final buffer = StringBuffer();
      buffer.writeln('# Generated Questions\n');
      buffer.writeln('**Topic:** ${_topicController.text.trim()}\n');
      buffer.writeln('---\n');

      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        buffer.writeln('## Question ${i + 1}\n');
        buffer.writeln('${q['question'] ?? ''}\n');
        buffer.writeln('**Answer:**\n');
        buffer.writeln('${q['answer'] ?? 'N/A'}\n');
        buffer.writeln('---\n');
      }

      final topic = _topicController.text.trim();
      final path = await PdfExportService.exportAsFile(
        title: 'Questions_${topic.isEmpty ? "Generated" : topic}',
        content: buffer.toString(),
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
          if (_questions.isNotEmpty) ...[
            IconButton(
              onPressed: _isExporting ? null : _downloadQuestions,
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
          // Controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // KB Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: Text(
                        kbState.knowledgeBases.isEmpty
                            ? 'No KBs — questions from general knowledge'
                            : 'Select Knowledge Base (optional)',
                        style:
                            const TextStyle(color: AppTheme.textTertiary),
                      ),
                      value: kbState.selectedKb,
                      dropdownColor: AppTheme.surfaceDark,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None (General knowledge)',
                              style:
                                  TextStyle(color: AppTheme.textSecondary)),
                        ),
                        ...kbState.knowledgeBases.map((kb) {
                          final name = kb['name']?.toString() ?? 'Unknown';
                          final docCount = kb['doc_count'] ?? 0;
                          return DropdownMenuItem(
                            value: name,
                            child: Row(
                              children: [
                                const Icon(Icons.folder_rounded,
                                    size: 16,
                                    color: AppTheme.accentViolet),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(name,
                                      style: const TextStyle(
                                          color: AppTheme.textPrimary)),
                                ),
                                Text('$docCount docs',
                                    style: const TextStyle(
                                        color: AppTheme.textTertiary,
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
                const SizedBox(height: 12),

                // Topic input
                TextField(
                  controller: _topicController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter topic (e.g., Neural Networks)',
                    prefixIcon: const Icon(Icons.topic_rounded,
                        color: AppTheme.textTertiary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Count selector
                Row(
                  children: [
                    const Text('Questions:',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(width: 12),
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
                          backgroundColor: AppTheme.surfaceDark,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppTheme.accentIndigo
                                : AppTheme.textSecondary,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.accentIndigo
                                : AppTheme.cardBorder,
                          ),
                          onSelected: (_) =>
                              setState(() => _questionCount = count),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),

                // Generate button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateQuestions,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
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
                        const SizedBox(height: 16),
                        const Text(
                          'No questions generated yet',
                          style: TextStyle(
                              color: AppTheme.textTertiary, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter a topic and tap Generate',
                          style: TextStyle(
                              color: AppTheme.textTertiary, fontSize: 13),
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
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.cardBorder),
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
                              title: SelectableText(
                                question,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded,
                                        size: 16,
                                        color: AppTheme.textTertiary),
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
                                      color: AppTheme.textTertiary,
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
                                  child: SelectableText(
                                    answer,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
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
