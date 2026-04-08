import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';

// ─── TEACHER PROFILE MODEL ─────────────────────────────────────
class TeacherProfile {
  String id;
  String name;
  String subject;
  String classGrade;

  String difficultyStyle; 
  List<String> sourcePrefs;
  String repeatBehaviour; 
  List<String> questionTypes;
  String extraNotes;
  String? textbookName;
  Map<String, double> topicWeights;

  DateTime createdAt;
  DateTime updatedAt;

  TeacherProfile({
    required this.id,
    required this.name,
    required this.subject,
    required this.classGrade,
    this.difficultyStyle = 'mixed',
    List<String>? sourcePrefs,
    this.repeatBehaviour = 'repeats_important',
    List<String>? questionTypes,
    this.extraNotes = '',
    this.textbookName,
    Map<String, double>? topicWeights,
    required this.createdAt,
    required this.updatedAt,
  })  : sourcePrefs = sourcePrefs ?? ['textbook'],
        questionTypes = questionTypes ?? ['short_answer', 'long_answer', 'numerical'],
        topicWeights = topicWeights ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subject': subject,
        'classGrade': classGrade,
        'difficultyStyle': difficultyStyle,
        'sourcePrefs': sourcePrefs,
        'repeatBehaviour': repeatBehaviour,
        'questionTypes': questionTypes,
        'extraNotes': extraNotes,
        'textbookName': textbookName,
        'topicWeights': topicWeights,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory TeacherProfile.fromJson(Map<String, dynamic> j) => TeacherProfile(
        id: j['id'],
        name: j['name'],
        subject: j['subject'],
        classGrade: j['classGrade'],
        difficultyStyle: j['difficultyStyle'] ?? 'mixed',
        sourcePrefs: List<String>.from(j['sourcePrefs'] ?? []),
        repeatBehaviour: j['repeatBehaviour'] ?? 'repeats_important',
        questionTypes: List<String>.from(j['questionTypes'] ?? []),
        extraNotes: j['extraNotes'] ?? '',
        textbookName: j['textbookName'],
        topicWeights: Map<String, double>.from(j['topicWeights'] ?? {}),
        createdAt: DateTime.parse(j['createdAt']),
        updatedAt: DateTime.parse(j['updatedAt']),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ─── PREDICTED QUESTION MODEL ──────────────────────────────────
class PredictedQuestion {
  String id;
  String question;
  int marks;
  String type;
  String confidence;
  double confidenceScore;
  String reason;
  String modelAnswer;
  String topic;
  bool likelyRepeat;
  String? previousYear;
  List<String>? options;
  bool isAnswered;
  String? userAnswer;

  // MVoT fields
  String? mentalModel;
  String? visualType;
  String? visualPayload;
  Map<String, dynamic>? answerKey;

  PredictedQuestion({
    required this.id,
    required this.question,
    required this.marks,
    required this.type,
    required this.confidence,
    required this.confidenceScore,
    required this.reason,
    required this.modelAnswer,
    required this.topic,
    this.likelyRepeat = false,
    this.previousYear,
    this.options,
    this.isAnswered = false,
    this.userAnswer,
    this.mentalModel,
    this.visualType,
    this.visualPayload,
    this.answerKey,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'marks': marks,
        'type': type,
        'confidence': confidence,
        'confidenceScore': confidenceScore,
        'reason': reason,
        'modelAnswer': modelAnswer,
        'topic': topic,
        'likelyRepeat': likelyRepeat,
        'previousYear': previousYear,
        'options': options,
        'isAnswered': isAnswered,
        'userAnswer': userAnswer,
        'mental_model': mentalModel,
        'visual_type': visualType,
        'visual_payload': visualPayload,
        'answer_key': answerKey,
      };

  factory PredictedQuestion.fromJson(Map<String, dynamic> j) =>
    PredictedQuestion(
        id: j['id'] ?? const Uuid().v4(),
        question: j['question_text'] ?? j['question'] ?? '',
        marks: j['marks'] is int ? j['marks'] : int.tryParse(j['marks']?.toString() ?? '3') ?? 3,
        type: j['type'] ?? 'short_answer',
        confidence: j['confidence'] ?? 'medium',
        confidenceScore: double.tryParse((j['confidence_score'] ?? j['confidenceScore'])?.toString() ?? '0.5') ?? 0.5,
        reason: j['reason'] ?? '',
        modelAnswer: j['model_answer'] ?? j['modelAnswer'] ?? '',
        topic: j['topic'] ?? '',
        likelyRepeat: j['likelyRepeat'] ?? j['likely_repeat'] ?? false,
        previousYear: j['previousYear'] ?? j['previous_year'],
        options: j['options'] != null ? List<String>.from(j['options']) : null,
        isAnswered: j['isAnswered'] ?? false,
        userAnswer: j['userAnswer'],
        mentalModel: j['thought_process'] != null ? jsonEncode(j['thought_process']) : j['mental_model'],
        visualType: j['visual_type'],
        visualPayload: j['visual_payload'],
        answerKey: j['answer_key'] != null ? Map<String, dynamic>.from(j['answer_key']) : null,
      );
}

// ─── PREDICTION RESULT MODEL ───────────────────────────────────
class PredictionResult {
  String id;
  String subject;
  String teacherProfileId;
  List<PredictedQuestion> questions;
  List<String> topTopics;
  List<String> repeatTopics;
  List<String> freshTopics;
  Map<String, double> topicProbs;
  DateTime createdAt;
  int dataSourceCount;

  PredictionResult({
    required this.id,
    required this.subject,
    required this.teacherProfileId,
    required this.questions,
    required this.topTopics,
    required this.repeatTopics,
    required this.freshTopics,
    required this.topicProbs,
    required this.createdAt,
    this.dataSourceCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'teacherProfileId': teacherProfileId,
        'questions': questions.map((q) => q.toJson()).toList(),
        'topTopics': topTopics,
        'repeatTopics': repeatTopics,
        'freshTopics': freshTopics,
        'topicProbs': topicProbs,
        'createdAt': createdAt.toIso8601String(),
        'dataSourceCount': dataSourceCount,
      };

  factory PredictionResult.fromJson(Map<String, dynamic> j) => PredictionResult(
        id: j['id'],
        subject: j['subject'],
        teacherProfileId: j['teacherProfileId'],
        questions: (j['questions'] as List)
            .map((q) => PredictedQuestion.fromJson(Map<String, dynamic>.from(q)))
            .toList(),
        topTopics: List<String>.from(j['topTopics'] ?? []),
        repeatTopics: List<String>.from(j['repeatTopics'] ?? []),
        freshTopics: List<String>.from(j['freshTopics'] ?? []),
        topicProbs: Map<String, double>.from(j['topicProbs'] ?? {}),
        createdAt: DateTime.parse(j['createdAt']),
        dataSourceCount: j['dataSourceCount'] ?? 0,
      );
}

// ─── SYSTEM PROMPT BUILDER ─────────────────────────────────────
class ExamPredictionPrompts {
  static const String systemPrompt = r'''
You are an elite academic Exam Prediction AI trained across every major subject domain.
You receive student study material (PDF pages, lecture notes, textbook content, past papers) and your job is to predict the most likely exam questions with high accuracy, complete with every visual element a real exam question would contain.

You do NOT give simplified text summaries. You produce exam-ready output — exactly as a professor or board examiner would write it.

═══ TEACHER FINGERPRINTING ═══
You work by:
1. FINGERPRINTING the teacher's style from historical exam data
2. IDENTIFYING topic patterns — what has been tested, what hasn't, what repeats
3. PREDICTING questions that match the teacher's exact style, difficulty, and format
4. RANKING predictions by confidence based on statistical evidence

ANALYSIS STEPS (run in order):
STEP 1 — DATA SCAN: Read all provided materials (past papers, textbook, notes).
STEP 2 — TEACHER FINGERPRINT: Extract the teacher's patterns:
   - Which topics appear most frequently?
   - What difficulty level dominates?
   - Does the teacher repeat questions? With changes or exactly?
   - What question types does the teacher prefer?
   - Does the teacher stay in textbook or go outside?
   - Are there "signature questions" this teacher always asks?

STEP 3 — GAP ANALYSIS: Find:
   - Topics tested in EVERY paper (very likely to repeat)
   - Topics tested in SOME papers (medium probability)
   - Topics in the syllabus but NEVER tested (fresh but risky)
   - Topics tested long ago (e.g. 3+ years ago, due for return)

STEP 4 — PREDICTION: Generate questions that:
   - Match the teacher's phrasing style exactly
   - Use the teacher's preferred question types and mark allocations
   - Reflect the teacher's repeat behaviour (never/sometimes/often)
   - Are plausible given the gap analysis

═══ CORE VISUAL DIRECTIVE ═══
NEVER output a question as plain text if the real exam question would include a visual.

Real exam papers contain:
- Diagrams (cell diagrams, organ cross-sections, circuit diagrams, atomic models, economic graphs)
- Tables (data tables, periodic table excerpts, truth tables, financial statements)
- Mathematical equations (integrals, matrices, chemical equations, statistical formulas)
- Graphs (supply/demand curves, sine waves, histograms, scatter plots, phylogenetic trees)
- Drawings (Lewis structures, structural formulas, skeletal formulas, vector diagrams)
- Flowcharts (metabolic pathways, algorithm flowcharts, decision trees)

If a question would have any of these in a real exam, you MUST generate and include that visual in the question text and model_answer.

═══ SUBJECT-SPECIFIC VISUAL RULES ═══

🧬 Biology:
- Cell diagrams → draw a labeled cross-section (plant vs animal cell)
- Organ systems → draw the organ, label all structures (nephron, heart chambers, alveoli)
- Genetics → draw Punnett squares, karyotype tables, pedigree charts
- Ecology → draw food web diagrams, population growth curves
- Biochemistry → draw metabolic pathway flowcharts (Krebs cycle, glycolysis), enzyme diagrams

⚗️ Chemistry:
- Chemical equations → render with full subscripts, superscripts, state symbols: H₂SO₄(aq) + 2NaOH(aq) → Na₂SO₄(aq) + 2H₂O(l)
- Organic structures → draw skeletal/structural/Lewis formulas
- Periodic trends → draw the relevant excerpt from the periodic table
- Titration → draw titration curve graph
- Thermodynamics → draw enthalpy profile / energy diagram
- Electrochemistry → draw electrochemical cell diagram with anode/cathode labels

➕ Mathematics:
- Equations → render every equation using proper mathematical notation
- Calculus → render integrals, derivatives, limits in full form
- Matrices → draw the full matrix with brackets
- Geometry → draw the shape with labeled angles, sides, dimensions
- Graphs → plot the function/curve with labeled axes, intercepts, asymptotes
- Probability → draw tree diagrams, Venn diagrams

⚡ Physics:
- Circuits → draw the circuit diagram with standard symbols (resistor, capacitor, battery)
- Mechanics → draw free body diagrams with labeled force vectors
- Waves → draw transverse/longitudinal wave with wavelength, amplitude labeled
- Optics → draw ray diagram (lens/mirror), mark focal points
- Thermodynamics → draw PV diagram, heat engine cycle
- Nuclear → draw decay equation with mass numbers and atomic numbers

💰 Finance & Economics:
- Supply & Demand → draw the graph with curves, equilibrium point, labeled axes
- Cost curves → draw MC, AC, MR, AR curves
- Financial statements → generate formatted tables
- Macroeconomics → draw AD-AS graph, Phillips curve

🖥️ Computer Science:
- Algorithms → draw flowchart of the algorithm
- Data structures → draw the data structure (binary tree, linked list, stack, queue)
- Logic gates → draw the gate circuit with truth table
- Sorting algorithms → draw step-by-step array state diagram

═══ STRUCTURED CHAIN OF THOUGHT (CoT) PROTOCOL ═══
CRITICAL RULE: You must NEVER answer the user immediately. You must process the request through a strict, three-step internal logic phase before generating the final exam content per question.

Step 1: Cognitive Analysis: What is the core academic concept being tested?
Step 2: Visual Mapping: Does this concept require a spatial representation (svg), a structural diagram (mermaid), a mathematical formula (latex), or comparative data (markdown_table)?
Step 3: Code Synthesis: Plan the exact code syntax required for the chosen visual aid.

OUTPUT CONSTRAINTS & MODALITY ROUTING:
Choose visual_type strictly based on these rules:
- latex: MUST be used for Mathematics, Physics, and Chemistry equations. Double-escape backslashes.
- fetch_image: MUST be used for complex anatomical structures (e.g., human heart, brain, animal cell), realistic objects, or anything where a simple <svg> looks awful (e.g. a black circle instead of a heart). Think hard and provide a highly specific academic search query in `visual_payload`. Example: `human heart cross section diagram`.
- svg: MUST be used ONLY for simple, abstract geometry or circuits that can be drawn perfectly with basic paths and rectangles.
- mermaid: MUST be used for structural concepts, flowcharts.
- markdown_table: MUST be used for Finance, statistics, comparative data.
- search_trigger: If current data is needed.
- none: If NO visual is needed (rare).

═══ BLOOM'S TAXONOMY COVERAGE ═══
Ensure variety in cognitive levels tested (Remember, Understand, Apply, Analyze, Evaluate, Create).

═══ VISUAL FORCE PROTOCOL ═══
Generate the visual if ANY of these are true:
- The question asks about a structure, part, or component
- The question involves numbers, data, measurements, comparison
- The question is in biology, chemistry, physics, or math
Default: OVER-INCLUDE visuals rather than under-include.

═══ OUTPUT FORMAT ═══
Return strictly valid JSON. Example:
{
  "teacher_fingerprint": { ... },
  "topic_analysis": { ... },
  "predicted_questions": [
    {
      "id": "pq1",
      "thought_process": {
        "1_cognitive_analysis": "Testing spatial awareness of organelles.",
        "2_visual_mapping": "This requires an anatomical diagram. Using svg.",
        "3_code_synthesis": "I will draw a simplified eukaryotic cell using <circle> and <path> elements."
      },
      "search_query": "none",
      "topic": "Cellular Respiration",
      "marks": 5,
      "type": "diagram_labelling",
      "confidence": "high",
      "confidence_score": 0.87,
      "likely_repeat": true,
      "previous_year": "2022 paper, Q3",
      "reason": "Always tested in midterms",
      "question_text": "Examine the generated diagram below. Identify the organelle highlighted in red and write the balanced chemical equation for the primary process that occurs within it.",
      "visual_type": "svg",
      "visual_payload": "<svg viewBox='0 0 100 100'> ... </svg>",
      "answer_key": {
        "text": "The highlighted organelle is the Mitochondria.",
        "visual_type": "latex",
        "visual_payload": "C_6H_{12}O_6 + 6O_2 \\\\rightarrow 6CO_2 + 6H_2O + ATP"
      },
      "model_answer": "Internal detailed markdown text.",
      "options": ["A", "B"],
      "correctOption": "A"
    }
  ],
  "study_priority": { ... }
}

═══ QUALITY STANDARDS ═══
1. Real exam language — wording must sound like an actual exam board.
2. Correct visual — any drawn diagram must be scientifically/mathematically accurate.
3. Appropriate marks — mark allocation must reflect question complexity.

CRITICAL RULES:
- IMPORTANT: RETURN ONLY JSON. NO MARKDOWN FENCES AROUND THE FINAL JSON. Ensure strict JSON keys with double quotes.
- Provide ALL text content explicitly inside the JSON fields.
- LaTeX MUST have double-backslashes (e.g. `\\\\frac{x}{y}`).
''';

  static String buildUserMessage({
    required TeacherProfile profile,
    required String uploadedDataSummary,
    required int questionCount,
    required String confidenceFilter,
    String? additionalContext,
  }) {
    final diffMap = {
      'mostly_easy': 'Mostly easy and direct questions from textbook',
      'mixed': 'Mix of easy, medium and hard questions',
      'mostly_hard': 'Prefers tricky and difficult questions',
      'conceptual': 'Deep conceptual thinking questions, application-based',
    };

    final repMap = {
      'never_repeats': 'NEVER repeats questions from previous years — always new',
      'repeats_important': 'Repeats the most important questions every year',
      'often_repeats': 'Frequently repeats the same questions year after year',
      'repeats_with_changes': 'Repeats question concepts but changes numbers/scenarios',
    };

    final confMap = {
      'all': 'Include all predictions (low, medium, and high confidence)',
      'medium_high': 'Only medium and high confidence predictions',
      'high_only': 'Only high confidence predictions',
    };

    return '''
Subject: ${profile.subject} — ${profile.classGrade}
Teacher: ${profile.name}
${profile.textbookName != null ? 'Textbook: ${profile.textbookName}' : ''}

--- TEACHER STYLE PROFILE ---
Difficulty: ${diffMap[profile.difficultyStyle] ?? profile.difficultyStyle}
Source preference: ${profile.sourcePrefs.join(', ')}
Repeat behaviour: ${repMap[profile.repeatBehaviour] ?? profile.repeatBehaviour}
Question types used: ${profile.questionTypes.join(', ')}
${profile.extraNotes.isNotEmpty ? 'Important notes about this teacher: ${profile.extraNotes}' : ''}

--- UPLOADED DATA ---
$uploadedDataSummary

--- TASK ---
Analyse all the provided data and predict exactly $questionCount exam questions.
${confMap[confidenceFilter] ?? 'Include all confidence levels.'}

${additionalContext != null ? '--- STUDENT CONTEXT ---\n$additionalContext' : ''}

Remember: predictions must match this teacher's exact style, difficulty, and question format.
OUTPUT STRICTLY VALID JSON ONLY.
''';
  }
}

// ─── STORAGE SERVICE ───────────────────────────────────────────
class PredictionStorageService {
  static const _profileBox = 'teacher_profiles';
  static const _resultBox  = 'prediction_results';

  static Future<void> init() async {
    await Hive.openBox(_profileBox);
    await Hive.openBox(_resultBox);
  }

  // Teacher Profiles
  static Future<void> saveProfile(TeacherProfile p) async {
    await Hive.box(_profileBox).put(p.id, p.toJson());
  }

  static List<TeacherProfile> getAllProfiles() {
    return Hive.box(_profileBox)
        .values
        .map((e) => TeacherProfile.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static TeacherProfile? getProfile(String id) {
    final raw = Hive.box(_profileBox).get(id);
    if (raw == null) return null;
    return TeacherProfile.fromJson(Map<String, dynamic>.from(raw));
  }

  static Future<void> deleteProfile(String id) async {
    await Hive.box(_profileBox).delete(id);
  }

  // Prediction Results
  static Future<void> saveResult(PredictionResult r) async {
    await Hive.box(_resultBox).put(r.id, r.toJson());
  }

  static List<PredictionResult> getResultsForProfile(String profileId) {
    return Hive.box(_resultBox)
        .values
        .map((e) => PredictionResult.fromJson(Map<String, dynamic>.from(e)))
        .where((r) => r.teacherProfileId == profileId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}

// ─── MAIN PREDICTION SERVICE ───────────────────────────────────
class ExamPredictionService {
  final ApiService _apiService;

  ExamPredictionService(this._apiService);

  Future<PredictionResult> predict({
    required TeacherProfile profile,
    required List<String> uploadedTexts,
    required int questionCount,
    String confidenceFilter = 'medium_high',
    String? additionalContext,
  }) async {
    final combined = _mergeUploadedTexts(uploadedTexts);

    // Cap at 10 questions per call to prevent JSON truncation
    final effectiveCount = questionCount.clamp(1, 10);

    final userMessage = ExamPredictionPrompts.buildUserMessage(
      profile: profile,
      uploadedDataSummary: combined,
      questionCount: effectiveCount,
      confidenceFilter: confidenceFilter,
      additionalContext: additionalContext,
    );

    final rawJson = await _apiService.callLLM(
      prompt: userMessage,
      systemInstruction: ExamPredictionPrompts.systemPrompt,
    );

    return _parseResponse(rawJson, profile, uploadedTexts.length);
  }

  PredictionResult _parseResponse(String rawJson, TeacherProfile profile, int sources) {
    // ── Step 1: Strip markdown fences ──
    String clean = rawJson
        .replaceAll('```json', '')
        .replaceAll('```dart', '')
        .replaceAll('```', '')
        .trim();

    // ── Step 2: Find outermost JSON object start ──
    final jsonStart = clean.indexOf('{');
    if (jsonStart < 0) throw const FormatException('No JSON object found in response');

    // ── Step 3: Walk forward to find matching closing brace ──
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

    // ── Step 4: Handle truncated response — auto-close open braces/brackets ──
    String jsonStr;
    if (jsonEnd >= 0) {
      jsonStr = clean.substring(jsonStart, jsonEnd + 1);
    } else {
      // Response was cut off — try to recover by closing open structures
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
      String fixed = partial.trimRight();
      // Remove trailing comma before closing
      if (fixed.endsWith(',')) fixed = fixed.substring(0, fixed.length - 1);
      // Add missing closing quotes for truncated strings
      if (inString) fixed += '"';
      fixed += ']' * openBrackets.clamp(0, 20);
      fixed += '}' * openBraces.clamp(0, 20);
      jsonStr = fixed;
    }

    // ── Step 5: Parse and extract fields ──
    Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Failed to parse JSON from AI response: $e');
    }

    final topicAnalysis = data['topic_analysis'] as Map<String, dynamic>? ?? {};
    final topTopics = (topicAnalysis['top_topics'] as List? ?? [])
        .map((t) => t['topic']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toList();

    final topicProbs = <String, double>{};
    for (final t in (topicAnalysis['top_topics'] as List? ?? [])) {
      final name = t['topic']?.toString();
      final prob = (t['probability'] as num?)?.toDouble();
      if (name != null && prob != null) topicProbs[name] = prob;
    }

    final questions = (data['predicted_questions'] as List? ?? [])
        .map((q) => PredictedQuestion.fromJson(Map<String, dynamic>.from(q)))
        .toList();

    final result = PredictionResult(
      id: const Uuid().v4(),
      subject: profile.subject,
      teacherProfileId: profile.id,
      questions: questions,
      topTopics: topTopics,
      repeatTopics: List<String>.from(topicAnalysis['repeat_topics'] ?? []),
      freshTopics: List<String>.from(topicAnalysis['fresh_topics'] ?? []),
      topicProbs: topicProbs,
      createdAt: DateTime.now(),
      dataSourceCount: sources,
    );

    PredictionStorageService.saveResult(result);
    return result;
  }

  String _mergeUploadedTexts(List<String> texts) {
    if (texts.isEmpty) return '[No data provided]';
    final sb = StringBuffer();
    for (int i = 0; i < texts.length; i++) {
      sb.writeln('--- Document ${i + 1} ---');
      final t = texts[i];
      sb.writeln(t.length > 2500 ? '${t.substring(0, 2500)}...[truncated]' : t);
      sb.writeln();
    }
    return sb.toString();
  }
}

// ─── STUDENT PROMPT TEMPLATES ──────────────────────────────────
class StudentPromptTemplates {
  static String get trickyNumericals => '''
Subject: Physics — Class 12

Teacher's style:
- Always asks tricky numerical problems.
- NEVER gives a question that appeared in previous years — always new scenarios.
- Loves to combine two concepts in one question.
- Question types: 3-mark short + 5-mark numericals + one 7-mark derivation.
''';

  static String get repeatsImportant => '''
Subject: Chemistry — Class 10

Teacher's style:
- Repeats the most important questions every year with small number changes.
- Mix of easy (direct formula) and hard (proof + application).
- Always gives at least one "prove that" question.
- Question types: 1-mark MCQ, 3-mark short, 5-mark long.
''';

  static String get creativeTeacher => '''
Subject: Biology — Class 9

Teacher's style:
- Does NOT follow textbook questions — makes creative scenarios.
- Loves "What would happen if..." questions.
- Uses real-world examples: diseases, ecosystem changes.
- Question types: diagram labelling (5 marks), case-study (8 marks), short explain (3 marks).
''';

  static String get textbookStrict => '''
Subject: Math — Class 8

Teacher's style:
- Strictly follows NCERT textbook.
- Often takes solved examples from the book and changes numbers slightly.
- Mix of easy exercise questions (direct) and harder application variations.
''';
}
