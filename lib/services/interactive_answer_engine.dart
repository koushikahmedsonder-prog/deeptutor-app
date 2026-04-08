import 'dart:convert';
import 'document_service.dart';
import 'api_service.dart';

// ─── ANSWER FORMAT MODELS ──────────────────────────────────────

enum QuestionType {
  numerical,
  concept,
  process,
  comparison,
  proof,
  coding,
  factual,
  application,
  unknown,
}

class AnswerSection {
  final String type;       // 'hook'|'steps'|'formula'|'answer_box'|'verify'|'common_trap'|'self_check'|'table'|'code'|'citation'|'text'
  final String? content;
  final List<String>? items;
  final List<Map<String, String>>? rows;  // for tables: [{col1: v1, col2: v2}]
  final String? language;  // for code blocks

  AnswerSection({
    required this.type,
    this.content,
    this.items,
    this.rows,
    this.language,
  });

  factory AnswerSection.fromJson(Map<String, dynamic> j) => AnswerSection(
    type: j['type']?.toString() ?? 'text',
    content: j['content']?.toString(),
    items: j['items'] != null ? List<String>.from(j['items'].map((e) => e.toString())) : null,
    rows: j['rows'] != null
        ? (j['rows'] as List)
            .map((r) => Map<String, String>.from((r as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))))
            .toList()
        : null,
    language: j['language']?.toString(),
  );
}

class InteractiveAnswer {
  final QuestionType questionType;
  final String subject;
  final String difficulty;
  final List<String> toolsUsed;
  final List<AnswerSection> sections;
  final String rawText;  // fallback full text

  InteractiveAnswer({
    required this.questionType,
    required this.subject,
    required this.difficulty,
    required this.toolsUsed,
    required this.sections,
    required this.rawText,
  });

  factory InteractiveAnswer.fromJson(Map<String, dynamic> j, String raw) {
    final typeStr = j['question_type']?.toString().toLowerCase() ?? 'unknown';
    final typeMap = {
      'numerical': QuestionType.numerical,
      'concept': QuestionType.concept,
      'process': QuestionType.process,
      'comparison': QuestionType.comparison,
      'proof': QuestionType.proof,
      'coding': QuestionType.coding,
      'factual': QuestionType.factual,
      'application': QuestionType.application,
    };

    final sections = (j['answer_sections'] as List? ?? [])
        .map((s) => AnswerSection.fromJson(Map<String, dynamic>.from(s)))
        .toList();

    return InteractiveAnswer(
      questionType: typeMap[typeStr] ?? QuestionType.unknown,
      subject: j['subject']?.toString() ?? 'general',
      difficulty: j['difficulty']?.toString() ?? 'medium',
      toolsUsed: j['tools_used'] != null ? List<String>.from(j['tools_used'].map((e) => e.toString())) : [],
      sections: sections,
      rawText: raw,
    );
  }

  factory InteractiveAnswer.fromRawText(String text) {
    return InteractiveAnswer(
      questionType: QuestionType.unknown,
      subject: 'general',
      difficulty: 'medium',
      toolsUsed: [],
      sections: [AnswerSection(type: 'text', content: text)],
      rawText: text,
    );
  }

  // Check if this looks like a parsed interactive layout or just a fallback
  bool get isRichFormat =>
      questionType != QuestionType.unknown && sections.isNotEmpty;

  /// Converts the answer sections back into readable, formatted markdown!
  String toMarkdown() {
    if (!isRichFormat) return rawText;
    
    final sb = StringBuffer();
    for (final section in sections) {
      switch (section.type) {
        case 'text':
        case 'hook':
        case 'formula':
          if (section.content != null) {
            sb.writeln(section.content);
            sb.writeln();
          }
          break;
        case 'answer_box':
          if (section.content != null) {
            sb.writeln('**Answer:** ${section.content}');
            sb.writeln();
          }
          break;
        case 'verify':
        case 'self_check':
        case 'common_trap':
          if (section.content != null) {
            sb.writeln('> 💡 **Tip:** ${section.content}');
            sb.writeln();
          }
          break;
        case 'steps':
          if (section.items != null) {
            for (int i = 0; i < section.items!.length; i++) {
              sb.writeln('${i + 1}. ${section.items![i]}');
            }
            sb.writeln();
          }
          break;
        case 'table':
          if (section.rows != null && section.rows!.isNotEmpty) {
            final keys = section.rows!.first.keys.toList();
            sb.writeln('| ${keys.join(' | ')} |');
            sb.writeln('| ${keys.map((_) => '---').join(' | ')} |');
            for (final row in section.rows!) {
              sb.writeln('| ${keys.map((k) => row[k] ?? '').join(' | ')} |');
            }
            sb.writeln();
          }
          break;
        case 'code':
          if (section.content != null) {
            sb.writeln('```${section.language ?? ''}');
            sb.writeln(section.content);
            sb.writeln('```');
            sb.writeln();
          }
          break;
        case 'citation':
          if (section.items != null) {
            sb.writeln('**Sources:**');
            for (final item in section.items!) {
              if (item.trim().isNotEmpty) sb.writeln('- $item');
            }
            sb.writeln();
          }
          break;
        default:
          if (section.content != null) {
            sb.writeln(section.content);
            sb.writeln();
          }
      }
    }
    return sb.toString().trim();
  }
}

// ─── PROMPTS ──────────────────────────────────────────────────

class InteractiveAnswerPrompts {
  static const String analysisLoop = '''
You are DeepTutor's Analysis Agent. Your job is to investigate and understand a question BEFORE it gets answered.

Run this analysis silently:

STEP 1 — CLASSIFY:
Determine question type from these signals:
- NUMERICAL: numbers present, "calculate/find/determine", units (kg, m/s, J, N, mol, V, A)
- CONCEPT: "what is/define/explain/describe/what does X mean"
- PROCESS: "how does X work/happen", "steps of/stages of/mechanism/pathway"
- COMPARISON: "difference between/compare/contrast/vs/which is better"
- PROOF: "prove/derive/show that/verify mathematically"
- CODING: "write code/implement/algorithm/debug/time complexity"
- FACTUAL: "who/when/where/what happened/history of/current/latest"
- APPLICATION: scenario given + question about it

STEP 2 — IDENTIFY TOOLS NEEDED:
- rag_search: textbook content
- web_search: current facts, statistics, recent events
- paper_search: academic citations
- code_executor: numerical verification
- query_item: definitions, constants

STEP 3 — IDENTIFY KEY INSIGHT:
What is the ONE thing the student must understand to follow this answer?

Return a JSON analysis:
{
  "question_type": "...",
  "subject_domain": "...",
  "student_level": "beginner|intermediate|advanced",
  "tools_needed": [...],
  "key_insight": "...",
  "common_misconception": "...",
  "answer_approach": "one sentence describing how to answer"
}
Return ONLY the JSON. Nothing else.
''';

  static const String solveLoop = '''
You are DeepTutor's Interactive Answer Engine. You received an analysis of this question.
Now generate a rich, interactive, structured answer.

USE THIS FORMAT based on the question type from the analysis:

═══ FOR NUMERICAL / CALCULATION ═══
Structure your answer as JSON:
{
  "question_type": "numerical",
  "subject": "physics|chemistry|maths|...",
  "difficulty": "easy|medium|hard",
  "tools_used": [],
  "answer_sections": [
    {"type": "text", "content": "This is a [type] problem. Let me work through it step by step."},
    {"type": "text", "content": "GIVEN: [list all given values with units]\nFIND: [what we need]\nPRINCIPLE: [law or formula we will use, and why it applies]"},
    {"type": "steps", "items": [
      "Step 1 — [What we do]: [Formula symbolically] → Substitute: [numbers] → Result: [value + unit]"
    ]},
    {"type": "answer_box", "content": "[Final answer with unit]"},
    {"type": "verify", "content": "Sanity check: [brief verification]"},
    {"type": "common_trap", "content": "Students often [specific mistake]"},
    {"type": "self_check", "content": "Try this: [a slightly different variation]"}
  ]
}

═══ FOR CONCEPT EXPLANATION ═══
{
  "question_type": "concept",
  "subject": "...",
  "difficulty": "...",
  "tools_used": [],
  "answer_sections": [
    {"type": "hook", "content": "[Vivid analogy or real-world observation — 2 sentences max]"},
    {"type": "text", "content": "[Simple plain-language explanation a 14-year-old can follow]"},
    {"type": "text", "content": "[Formal definition with key terms in CAPS or **bold**]"},
    {"type": "text", "content": "Real example: [specific, concrete, not vague]"},
    {"type": "common_trap", "content": "Many students think [misconception]... but actually [correction] because [reason]"},
    {"type": "self_check", "content": "Quick check — [one question that tests genuine understanding, not rote recall]"}
  ]
}

═══ FOR PROCESS / MECHANISM ═══
{
  "question_type": "process",
  "subject": "...",
  "difficulty": "...",
  "tools_used": [],
  "answer_sections": [
    {"type": "text", "content": "Overview: [one sentence — what is the overall purpose/outcome of this process?]"},
    {"type": "steps", "items": [
      "Stage 1 — [Name]: [What happens] | Why: [reason] | Produces: [output]",
      "Stage 2 — [Name]: [Input from stage 1] → [transformation] → [output]"
    ]},
    {"type": "text", "content": "Key dependency: The whole process depends on [X]. If this fails, [consequence]."},
    {"type": "text", "content": "Real world: [where this process occurs and why it matters]"},
    {"type": "self_check", "content": "What would happen if [one stage was disrupted]?"}
  ]
}

═══ FOR COMPARISON ═══
{
  "question_type": "comparison",
  "subject": "...",
  "difficulty": "...",
  "tools_used": [],
  "answer_sections": [
    {"type": "text", "content": "Quick answer: The main difference is [one clear sentence]"},
    {"type": "table", "rows": [
      {"Feature": "Definition", "X": "...", "Y": "..."}
    ]},
    {"type": "text", "content": "Key insight: The fundamental reason they differ is [deeper explanation]"},
    {"type": "common_trap", "content": "Exam trap: [how examiners confuse students between these two]"},
    {"type": "self_check", "content": "Classify this: [give an example and ask which category it falls into]"}
  ]
}

═══ FOR PROOF / DERIVATION ═══
{
  "question_type": "proof",
  "subject": "...",
  "difficulty": "...",
  "tools_used": [],
  "answer_sections": [
    {"type": "text", "content": "Goal: We want to show that [target result]"},
    {"type": "text", "content": "Starting point: We begin with [known result, definition, or axiom]"},
    {"type": "steps", "items": [
      "Step 1: [equation or statement] — because [justification/rule applied]",
      "Final step: Therefore [result] = [target] ∎"
    ]},
    {"type": "text", "content": "Physical/mathematical meaning: This result tells us [intuition]"},
    {"type": "self_check", "content": "Now try: Prove [related result that uses the same technique]"}
  ]
}

═══ FOR CODING ═══
{
  "question_type": "coding",
  "subject": "...",
  "difficulty": "...",
  "tools_used": [],
  "answer_sections": [
    {"type": "text", "content": "Approach: We'll use [algorithm/data structure] because [justification]"},
    {"type": "code", "language": "python", "content": "[Clean, commented code]"},
    {"type": "text", "content": "Walkthrough: [Line-by-line explanation of non-obvious parts]"},
    {"type": "text", "content": "Trace: Input=[example] → [execution trace] → Output=[result]"},
    {"type": "text", "content": "Complexity: Time O([x]) because [reason]. Space O([y])."},
    {"type": "common_trap", "content": "Edge cases to watch: [empty input/overflow/off-by-one/etc.]"},
    {"type": "self_check", "content": "Modify this: [small challenge that extends the solution]"}
  ]
}

═══ FOR FACTUAL / RESEARCH ═══
{
  "question_type": "factual",
  "subject": "...",
  "difficulty": "...",
  "tools_used": [],
  "answer_sections": [
    {"type": "text", "content": "[Direct one-sentence answer]"},
    {"type": "text", "content": "[2-3 sentences of context and background]"},
    {"type": "text", "content": "Why it matters: [significance and impact]"},
    {"type": "text", "content": "Nuance: [important qualification or 'however' point]"},
    {"type": "text", "content": "Connection: This relates to [X], which you may also want to understand."},
    {"type": "citation", "items": [
      "1. [source title / URL]"
    ]}
  ]
}

CRITICAL RULES:
- Return ONLY the JSON object. Do not wrap it in markdown codeblocks (no ```json). Do not put text before or after the JSON.
- Never start an answer section with "Certainly!" or "Great question!"
- Match vocabulary to student level detected in analysis
- All content strings must be plain text and safely escaped for JSON so Flutter can parse them without throws.
''';

  static String singleCallPrompt({
    required String subject,
    required String studentLevel,
  }) => '''
You are DeepTutor's Interactive Answer Engine.

PHASE 1 — SILENTLY classify the question:
Type: numerical | concept | process | comparison | proof | coding | factual | application

PHASE 2 — Output ONLY a valid JSON object. No explanation text, no markdown code fences, no "Here is..." preamble. Start your response with { and end with }.

Use the exact JSON structure for the detected question type:

${solveLoop.substring(solveLoop.indexOf('═══'))}

VISUAL VARIETY RULES (Add to "text" or "answer_sections"):
- ONLY use diagrams/visuals when truly useful. Do not force generic mindmaps.
- **Images:** If a real photo helps (anatomy, geography, hardware), insert purely this text in a content string: [FETCH_IMAGE: descriptive keywords]
- **Tables:** Use a "table" section type for data/comparisons, or use Markdown tables inside "text" sections.
- **Code/Algorithms:** Use a "code" section type.
- **Charts:** Use Mermaid only for complex workflows, not simple lists. 

REMEMBER: Your ENTIRE response must be a single valid JSON object. Start with { immediately. All strings must be JSON-escaped.
''';
}

// ─── ENGINE ───────────────────────────────────────────────────

class InteractiveAnswerEngine {
  final ApiService _api;

  InteractiveAnswerEngine(this._api);

  Future<InteractiveAnswer> answerSingleCall({
    required String question,
    required String pastContext,
    PickedDocument? attachment,
    bool useWebSearch = false,
  }) async {
    final systemInstruction = InteractiveAnswerPrompts.singleCallPrompt(
      subject: 'General',
      studentLevel: 'intermediate',
    );

    final prompt = '${pastContext.isNotEmpty ? 'Previous Context:\n$pastContext\n\n' : ''}User Question: $question';

    final resultRaw = await _api.callLLM(
      prompt: prompt,
      systemInstruction: systemInstruction,
      attachment: attachment,
      useWebSearch: useWebSearch,
    );

    return InteractiveAnswerEngine.parseAnswer(resultRaw);
  }

  Future<InteractiveAnswer> answerWithDualLoop({
    required String question,
    required String pastContext,
    String? kbContent,
    PickedDocument? attachment,
    bool useWebSearch = false,
  }) async {
    // LOOP 1: Analysis
    final analysisPrompt = '${pastContext.isNotEmpty ? 'Previous Context:\n$pastContext\n\n' : ''}User Question: $question';
    
    final analysisRaw = await _api.callLLM(
      prompt: analysisPrompt,
      systemInstruction: InteractiveAnswerPrompts.analysisLoop,
      attachment: attachment,
    );

    Map<String, dynamic> analysis = {};
    try {
      final cleanAnalysis = analysisRaw.replaceAll('```json', '').replaceAll('```', '').trim();
      final jsonStart = cleanAnalysis.indexOf('{');
      final jsonEnd = cleanAnalysis.lastIndexOf('}');
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        analysis = jsonDecode(cleanAnalysis.substring(jsonStart, jsonEnd + 1));
      }
    } catch (_) {} // fail silently

    // LOOP 2: Solve
    String solvePrompt = 'Analysis output:\n${jsonEncode(analysis)}\n\n';
    if (kbContent != null && kbContent.isNotEmpty) {
      solvePrompt += 'KNOWLEDGE BASE CONTENT:\n$kbContent\n\n';
    }
    solvePrompt += 'User Question: $question\n\nGenerate the structured JSON answer.';

    final finalAnswerRaw = await _api.callLLM(
      prompt: solvePrompt,
      systemInstruction: InteractiveAnswerPrompts.solveLoop,
      attachment: attachment,
      useWebSearch: useWebSearch, // we will explicitly use the web search in step 2
    );

    return InteractiveAnswerEngine.parseAnswer(finalAnswerRaw);
  }

  static InteractiveAnswer parseAnswer(String raw) {
    try {
      // Step 1: Strip markdown fences and leading/trailing whitespace
      String clean = raw
          .replaceAll('```json', '')
          .replaceAll('```dart', '')
          .replaceAll('```', '')
          .trim();

      // Step 2: Find the outermost JSON object boundaries
      final jsonStart = clean.indexOf('{');
      if (jsonStart < 0) return InteractiveAnswer.fromRawText(raw);

      // Step 3: Walk forward to find matching closing brace
      int depth = 0;
      int jsonEnd = -1;
      bool inString = false;
      bool escaped = false;
      for (int i = jsonStart; i < clean.length; i++) {
        final ch = clean[i];
        if (escaped) { escaped = false; continue; }
        if (ch == '\\' && inString) { escaped = true; continue; }
        if (ch == '"') { inString = !inString; continue; }
        if (inString) continue;
        if (ch == '{') {
          depth++;
        } else if (ch == '}') {
          depth--;
          if (depth == 0) { jsonEnd = i; break; }
        }
      }

      // Step 4: If braces didn't balance (truncated response), try to close it
      String jsonStr;
      if (jsonEnd >= 0) {
        jsonStr = clean.substring(jsonStart, jsonEnd + 1);
      } else {
        // Truncated — close all open braces/brackets
        final partial = clean.substring(jsonStart);
        int openBraces = 0, openBrackets = 0;
        inString = false; escaped = false;
        for (int i = 0; i < partial.length; i++) {
          final ch = partial[i];
          if (escaped) { escaped = false; continue; }
          if (ch == '\\' && inString) { escaped = true; continue; }
          if (ch == '"') { inString = !inString; continue; }
          if (inString) continue;
          if (ch == '{') {
            openBraces++;
          } else if (ch == '}') openBraces--;
          else if (ch == '[') openBrackets++;
          else if (ch == ']') openBrackets--;
        }
        // Remove trailing comma if present, then close
        String fixed = partial.trimRight();
        if (fixed.endsWith(',')) fixed = fixed.substring(0, fixed.length - 1);
        fixed += ']' * openBrackets.clamp(0, 10);
        fixed += '}' * openBraces.clamp(0, 10);
        jsonStr = fixed;
      }

      final data = jsonDecode(jsonStr);
      final answer = InteractiveAnswer.fromJson(data, raw);
      return answer;
    } catch (e) {
      // ignore parse failures — fall back to plain text
    }
    return InteractiveAnswer.fromRawText(raw);
  }
}
