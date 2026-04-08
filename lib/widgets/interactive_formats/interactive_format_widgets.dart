import 'package:flutter/material.dart';
import '../../services/interactive_answer_engine.dart';
import '../rich_content_renderer.dart';


class InteractiveAnswerWidget extends StatelessWidget {
  final InteractiveAnswer answer;

  const InteractiveAnswerWidget({super.key, required this.answer});

  @override
  Widget build(BuildContext context) {
    if (!answer.isRichFormat) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: RichContentRenderer(content: answer.rawText, selectable: false),
      );
    }

    final buffer = StringBuffer();

    for (final sec in answer.sections) {
      if (sec.type == 'hook') {
        buffer.writeln('> 💡 **Insight:** ${sec.content ?? ""}');
        buffer.writeln();
      } else if (sec.type == 'steps') {
        final items = sec.items ?? [];
        for (int i = 0; i < items.length; i++) {
          buffer.writeln('${i + 1}. ${items[i]}');
        }
        buffer.writeln();
      } else if (sec.type == 'answer_box') {
        buffer.writeln('**🎯 Final Answer:**');
        buffer.writeln('> ${sec.content ?? ""}');
        buffer.writeln();
      } else if (sec.type == 'common_trap') {
        buffer.writeln('> ⚠️ **Common Trap:** ${sec.content ?? ""}');
        buffer.writeln();
      } else if (sec.type == 'self_check') {
        buffer.writeln('### 🧠 Self Check');
        buffer.writeln(sec.content ?? "");
        buffer.writeln();
      } else if (sec.type == 'table' && sec.rows != null && sec.rows!.isNotEmpty) {
        final columns = sec.rows!.first.keys.toList();
        buffer.writeln('| ${columns.join(' | ')} |');
        buffer.writeln('| ${columns.map((_) => '---').join(' | ')} |');
        for (final row in sec.rows!) {
          buffer.writeln('| ${columns.map((c) => row[c] ?? '').join(' | ')} |');
        }
        buffer.writeln();
      } else if (sec.type == 'citation') {
        buffer.writeln('**References:**');
        for (final cit in sec.items ?? []) {
          buffer.writeln('- $cit');
        }
        buffer.writeln();
      } else if (sec.type == 'code') {
        buffer.writeln('```${sec.language ?? ''}');
        buffer.writeln(sec.content ?? '');
        buffer.writeln('```');
        buffer.writeln();
      } else {
        buffer.writeln(sec.content ?? '');
        buffer.writeln();
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: RichContentRenderer(content: buffer.toString().trim(), selectable: false),
    );
  }
}
