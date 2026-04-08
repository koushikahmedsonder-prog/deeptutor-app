import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../config/app_theme.dart';
import '../services/exam_prediction_service.dart';
import 'rich_content_renderer.dart';
import '../utils/theme_helper.dart';

class ExamQuestionRenderer extends StatefulWidget {
  final PredictedQuestion question;
  final int index;

  final VoidCallback? onDelete;
  final VoidCallback? onSolveAction;

  const ExamQuestionRenderer({
    super.key,
    required this.question,
    required this.index,
    this.onDelete,
    this.onSolveAction,
  });

  @override
  State<ExamQuestionRenderer> createState() => _ExamQuestionRendererState();
}

class _ExamQuestionRendererState extends State<ExamQuestionRenderer> {

  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (Question index, marks, difficulty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.scaffoldBg,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${widget.index + 1}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.textPri),
                ),
                Row(
                  children: [
                    if (q.likelyRepeat)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPink.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.accentPink.withOpacity(0.5)),
                        ),
                        child: const Text('Likely Repeat', style: TextStyle(color: AppTheme.accentPink, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    Text(
                      '${q.marks} Marks',
                      style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
                    ),
                    if (widget.onDelete != null) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: widget.onDelete,
                        child: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),



          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text Payload
                RichContentRenderer(content: q.question),
                
                // Visual Payload (GenUI Rendering)
                if (q.visualPayload != null && q.visualPayload!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildGenUiVisual(q.visualType, q.visualPayload!),
                ],
                
                const SizedBox(height: 16),
                Divider(color: context.cardBorder),
                
                // Model Answer / Answer Key section
                InkWell(
                  onTap: () => setState(() => _showAnswer = !_showAnswer),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: AppTheme.accentGreen, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'View Model Answer',
                          style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Icon(
                          _showAnswer ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: AppTheme.textTertiary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showAnswer) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.scaffoldBg.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (q.answerKey != null) ...[
                          RichContentRenderer(content: q.answerKey!['text'] ?? q.modelAnswer),
                          if (q.answerKey!['visual_payload'] != null) ...[
                            const SizedBox(height: 12),
                            _buildGenUiVisual(q.answerKey!['visual_type'], q.answerKey!['visual_payload']),
                          ]
                        ] else ...[
                          RichContentRenderer(content: q.modelAnswer),
                        ],
                      ],
                    ),
                  ),
                ],
                
                if (widget.onSolveAction != null) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: widget.onSolveAction,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentIndigo.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.accentIndigo),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.auto_awesome, color: AppTheme.accentIndigo, size: 16),
                            SizedBox(width: 8),
                            Text('Solve with AI', style: TextStyle(color: AppTheme.accentIndigo, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // GenUI Orchestrator / Routing Logic
  Widget _buildGenUiVisual(String? visualType, String payload) {
    if (payload.trim().isEmpty) return const SizedBox.shrink();

    String cleanPayload = payload.trim();
    if (cleanPayload.startsWith('```')) {
      final endOfFirstLine = cleanPayload.indexOf('\n');
      if (endOfFirstLine != -1) {
        cleanPayload = cleanPayload.substring(endOfFirstLine + 1);
      } else {
        cleanPayload = '';
      }
      if (cleanPayload.endsWith('```')) {
        cleanPayload = cleanPayload.substring(0, cleanPayload.length - 3).trim();
      }
    }

    try {
      switch (visualType) {
        case 'latex':
          var lt = cleanPayload;
          if (lt.startsWith(r'$$') && lt.endsWith(r'$$')) {
            lt = lt.substring(2, lt.length - 2).trim();
          } else if (lt.startsWith(r'\[') && lt.endsWith(r'\]')) {
            lt = lt.substring(2, lt.length - 2).trim();
          } else if (lt.startsWith(r'$') && lt.endsWith(r'$')) {
            lt = lt.substring(1, lt.length - 1).trim();
          }
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Math.tex(
                lt,
                textStyle: const TextStyle(fontSize: 18, color: Colors.black),
                onErrorFallback: (err) => _buildErrorFallback('LaTeX Syntax Error'),
              ),
            ),
          );

        case 'svg':
          return Container(
            padding: const EdgeInsets.all(16),
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SvgPicture.string(
              cleanPayload,
              fit: BoxFit.contain,
              placeholderBuilder: (context) => const Center(child: CircularProgressIndicator()),
            ),
          );

        case 'mermaid':
          return RichContentRenderer(content: "```mermaid\n$cleanPayload\n```");

        case 'fetch_image':
          return RichContentRenderer(content: '[FETCH_IMAGE: "$cleanPayload"]');

        case 'markdown_image':
        case 'markdown_table':
          return RichContentRenderer(content: cleanPayload);

        case 'search_trigger':
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.amber.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(child: Text('AI Search Protocol Triggered: $payload', style: const TextStyle(color: Colors.amber))),
              ],
            ),
          );
          
        case 'none':
        default:
          return RichContentRenderer(content: payload);
      }
    } catch (e) {
      return _buildErrorFallback('Render Error: $e');
    }
  }

  Widget _buildErrorFallback(String reason) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.05),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Visual Aid Unavailable',
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'The AI generated malformed code ($reason).',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 12),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: widget.onSolveAction, // Let them pass it back to the solver
            child: const Icon(Icons.refresh_rounded, color: Colors.redAccent, size: 24),
          ),
        ],
      ),
    );
  }
}
