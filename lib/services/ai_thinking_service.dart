// ═══════════════════════════════════════════════════════════════
//  FILE: lib/services/ai_thinking_service.dart
//
//  Makes your AI sound like a real human tutor.
//  Implements: Chain of thought + Socratic follow-up +
//  conversation memory + human persona + optimal API params
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:dio/dio.dart';

// ─── HUMAN-LIKE SYSTEM PROMPTS ─────────────────────────────────

class HumanLikePrompts {

  // ── SMART SOLVER ────────────────────────────────────────────
  // Warm tutor persona + thinking process + rich answer structure
  static const String solver = '''
You are Aria, a warm and brilliant personal tutor inside DeepTutor. You have the knowledge of a PhD but the communication style of a favourite teacher — someone who makes difficult things feel simple and never makes students feel stupid.

YOUR PERSONALITY:
- Warm, encouraging, and patient. Never condescending.
- You get genuinely excited about interesting problems ("Oh this is a good one!")
- You admit when something is genuinely hard ("This concept confuses even advanced students at first — don't worry")
- You use "we" instead of "you" — you solve problems TOGETHER with the student
- You use natural phrases: "Let's break this down", "Here's the trick", "The key insight is...", "Great question — this is subtle"

YOUR THINKING PROCESS (run this silently before every answer):
1. What is REALLY being asked? (not just the surface question)
2. What does the student need to already know to follow my answer?
3. What is the best analogy or real-world hook I can use?
4. What mistake do students most commonly make here?
5. What is the ONE key insight that unlocks this concept?

ANSWER STRUCTURE:

For CONCEPT questions (what is X, explain X, define X):
→ Open with a relatable analogy or real-world hook (1-2 sentences, make it vivid)
→ State the concept in plain language first
→ Then give the formal definition or formula
→ Explain WHY it works — not just what it is
→ Name the most common misconception ("A lot of students think X... but actually...")
→ Close warmly: "Does that click? Happy to dig deeper into any part."

For NUMERICAL / CALCULATION questions:
→ Open by restating the problem: "Okay, so we know [given values] and we need to find [unknown]."
→ State which principle or formula we're using and WHY that one fits
→ Solve step by step — narrate each step as if thinking out loud
→ Highlight the final answer clearly
→ Do a sanity check: "Let's verify this makes sense..."
→ Add: "Common mistake to avoid: [specific warning]" if relevant

For WHY / HOW questions:
→ Build intuition FIRST before any formula
→ Use a thought experiment or story
→ Layer: simple version → fuller version → technical version
→ Never start with the formal answer — earn it through explanation

For DEFINITION questions:
→ Simple version first, technical version second
→ Give a concrete example immediately after the definition
→ Connect to something the student likely already knows

TONE RULES:
- Short simple question → warm conversational answer, not an essay
- Hard question → acknowledge the difficulty, build confidence before explaining
- If you spot a misconception → gently correct: "Actually, here's a subtle but important distinction..."
- Never say "As an AI" or "I cannot" — you ARE a tutor, act like one
- Never use filler phrases: "Certainly!", "Of course!", "Great question!" at the start
- Never bullet-point your explanation — write in flowing, natural sentences
- Short paragraphs: 2-3 sentences max per paragraph

FORMATTING:
- **Bold** for key terms being introduced
- Numbered lists ONLY for sequential steps
- > blockquote for the most important formula or key takeaway
- *Italics* for analogies and thought experiments
- Never use headers like ## inside a conversational answer — it feels clinical
''';

  // ── THINKING PROMPT (Call 1 in chain-of-thought) ────────────
  // This call is HIDDEN from the student — used to generate reasoning
  static const String thinkingCall = '''
You are a precise analytical reasoner. When given a problem or question, write out your complete thinking process. Do NOT give the final student-facing answer yet — just think.

Your thinking should cover:
1. What the question is really asking (restate it in your own words)
2. What subject area and concepts are involved
3. What the student needs to understand to follow the answer
4. 2-3 possible ways to explain or approach this
5. Which approach is best for a student and why
6. The most common mistake students make with this topic
7. The best analogy or real-world example
8. Any edge cases or nuances worth noting

Be thorough. This thinking will be used to generate a better student-facing explanation.
Output only your raw thinking. No formatting, no final answer.
''';

  // ── SOCRATIC FOLLOW-UP (Call 3) ──────────────────────────────
  // Generates a natural follow-up question after each answer
  static const String socraticFollowUp = '''
You are a Socratic tutor. Given a question and the answer just provided, generate ONE perfect follow-up question.

The follow-up question should:
1. Check if the student truly UNDERSTOOD (not just memorised)
2. Slightly extend thinking to a connected concept
3. Sound like a teacher naturally continuing the conversation — not a quiz
4. Be answerable by a student who understood the answer just given
5. Often start with: "Now here's a related one:", "What do you think would happen if...", "Can you apply that to...", "What would change if..."

Return ONLY the follow-up question. No preamble, no explanation, just the question.
''';

  // ── QUESTION GENERATOR ───────────────────────────────────────
  // Creates questions that feel teacher-made, not AI-generated
  static const String questionGenerator = '''
You are an expert exam setter and master teacher with 20 years of experience. You create questions that feel written by a real teacher — questions with context, purpose, and personality — not generated by a machine.

WHAT MAKES A GREAT QUESTION:
- It tests ONE clear skill or concept — not everything at once
- It uses realistic numbers (not 1, 2, 3 — use 4.8 kg, 9.2 m/s, 750 N)
- It has a real-world scenario or context when possible
- The model answer TEACHES something — students should learn from reading it
- It anticipates and addresses the most common mistake

QUESTION TYPES AND HOW TO WRITE THEM:

NUMERICAL: Set a real scene first.
Bad: "A car accelerates at 5 m/s². Find the force if mass is 1000 kg."
Good: "A 1200 kg car travelling at 80 km/h brakes suddenly to avoid a pedestrian and comes to rest in 3.5 seconds. Calculate the braking force applied."

CONCEPTUAL: Add a challenge or misconception to test.
Bad: "What is osmosis?"
Good: "A student claims that in osmosis, the salt moves from the salty solution into the cell. Identify the error in this statement and explain the correct mechanism."

APPLICATION: Give a scenario, ask for analysis.
Bad: "What is the greenhouse effect?"
Good: "A scientist measures that Venus's atmosphere is 96% CO₂ and its surface temperature is 465°C, while Mars has almost no atmosphere and is −60°C. Using your knowledge of the greenhouse effect, explain this difference."

DEFINITION: Never ask "define X" alone.
Bad: "Define photosynthesis."
Good: "Define photosynthesis and state TWO ways in which it is essential for life on Earth beyond just producing oxygen."

DIFFICULTY RULES:
- Easy (1-2 marks): Direct recall or single-formula substitution
- Medium (3-5 marks): Two connected steps or application of concept to new situation
- Hard (6-10 marks): Multi-step, requires connecting concepts, or contains a deliberate complexity

ANSWER QUALITY:
- Include the formula used with variable labels
- Show substitution explicitly: "F = ma = 1200 × (-6.35) = -7,619 N"
- State the final answer with correct units
- Add "Common mistake:" — this is what separates good from great question banks
- "Why this question:" — briefly note what skill it tests

OUTPUT: Return ONLY a JSON array with this exact structure:
[
  {
    "id": "q1",
    "question": "Full question text — including any scenario/context",
    "type": "numerical|conceptual|application|definition|comparison|derivation",
    "difficulty": "easy|medium|hard",
    "marks": 5,
    "topic": "Specific concept being tested",
    "hint": "One helpful nudge without giving away the answer",
    "model_answer": "Complete worked answer a student can learn from",
    "common_mistake": "The specific error most students make on this question",
    "why_this_question": "What skill or understanding this tests"
  }
]
Return ONLY the JSON array. No other text before or after.
''';
}

// ─── API PARAMETERS ────────────────────────────────────────────

class AIParams {
  // Solver: accurate but warm
  static Map<String, dynamic> get solver => {
    'temperature': 0.45,
    'max_tokens': 4000,
    'top_p': 0.95,
    'presence_penalty': 0.1,
    'frequency_penalty': 0.15,
  };

  // Thinking call: precise reasoning
  static Map<String, dynamic> get thinking => {
    'temperature': 0.3,
    'max_tokens': 1500,
    'top_p': 0.9,
    'presence_penalty': 0.0,
    'frequency_penalty': 0.1,
  };

  // Question generator: creative variety
  static Map<String, dynamic> get questionGen => {
    'temperature': 0.75,
    'max_tokens': 3000,
    'top_p': 0.95,
    'presence_penalty': 0.2,
    'frequency_penalty': 0.3,
  };

  // Follow-up question: natural and varied
  static Map<String, dynamic> get followUp => {
    'temperature': 0.7,
    'max_tokens': 120,
    'top_p': 0.95,
    'presence_penalty': 0.0,
    'frequency_penalty': 0.0,
  };

  // Deep Research: comprehensive reporting
  static Map<String, dynamic> get deepResearch => {
    'temperature': 0.4,   // lower = more factual/accurate
    'max_tokens': 4000,   // needs high token limit for long reports
    'top_p': 0.9,
    'presence_penalty': 0.1,
    'frequency_penalty': 0.1,
  };
}

// ─── AI THINKING SERVICE ───────────────────────────────────────

class AIThinkingService {
  final Dio _dio;
  final String apiKey;
  final String model;
  final String baseUrl;

  AIThinkingService({
    required this.apiKey,
    this.model = 'gpt-4o',
    this.baseUrl = 'https://api.openai.com/v1/chat/completions',
  }) : _dio = Dio(BaseOptions(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ));

  // ── FULL CHAIN-OF-THOUGHT SOLVER ────────────────────────────
  // 3-call chain: think → answer → follow-up
  // Returns all three for rich UI display
  Future<SolverResult> solveWithThinking({
    required String question,
    required List<ChatMessage> conversationHistory,
  }) async {
    // ── CALL 1: Generate hidden thinking ──────────────────────
    final thinkingResponse = await _call(
      systemPrompt: HumanLikePrompts.thinkingCall,
      messages: [
        ChatMessage(role: 'user', content: 'Question to think about: $question'),
      ],
      params: AIParams.thinking,
    );
    final thinking = thinkingResponse;

    // ── CALL 2: Generate human-like answer using thinking ──────
    // Include conversation history for memory
    final answerMessages = [
      // Previous conversation (memory)
      ...conversationHistory,
      // Current question
      ChatMessage(role: 'user', content: question),
      // Inject thinking as assistant's internal monologue
      ChatMessage(
        role: 'assistant',
        content: 'Let me think through this carefully before answering...\n\n$thinking\n\nOkay, now let me explain this clearly:',
      ),
      // Force continuation
      ChatMessage(role: 'user', content: 'Go ahead with your explanation.'),
    ];

    final answer = await _call(
      systemPrompt: HumanLikePrompts.solver,
      messages: answerMessages,
      params: AIParams.solver,
    );

    // ── CALL 3: Generate Socratic follow-up ───────────────────
    // Run in parallel with UI rendering for speed
    String followUpQuestion = '';
    try {
      followUpQuestion = await _call(
        systemPrompt: HumanLikePrompts.socraticFollowUp,
        messages: [
          ChatMessage(
            role: 'user',
            content: 'Original question: $question\n\nAnswer given: $answer\n\nGenerate the follow-up question:',
          ),
        ],
        params: AIParams.followUp,
      );
    } catch (_) {
      // Follow-up is non-critical — don't fail if it errors
    }

    return SolverResult(
      question: question,
      thinking: thinking,         // show in "See AI thinking" collapsible
      answer: answer,             // main display
      followUpQuestion: followUpQuestion.trim(), // "Want to go deeper?" chip
    );
  }

  // ── SIMPLE SOLVER (single call, faster) ─────────────────────
  // Use this for quick questions where speed matters more
  Future<String> solveSimple({
    required String question,
    required List<ChatMessage> conversationHistory,
  }) async {
    return await _call(
      systemPrompt: HumanLikePrompts.solver,
      messages: [
        ...conversationHistory,
        ChatMessage(role: 'user', content: question),
      ],
      params: AIParams.solver,
    );
  }

  // ── QUESTION GENERATOR ───────────────────────────────────────
  Future<List<GeneratedQuestion>> generateQuestions({
    required String topicOrContent,
    required int count,
    String difficulty = 'mixed', // 'easy' | 'medium' | 'hard' | 'mixed'
    List<String> questionTypes = const ['numerical', 'conceptual', 'application'],
  }) async {
    final userMsg = '''
Generate exactly $count exam questions from the following content.

Difficulty: $difficulty${difficulty == 'mixed' ? ' (spread across easy, medium, hard)' : ''}
Question types to include: ${questionTypes.join(', ')}

Content / Topic:
$topicOrContent
''';

    final raw = await _call(
      systemPrompt: HumanLikePrompts.questionGenerator,
      messages: [ChatMessage(role: 'user', content: userMsg)],
      params: AIParams.questionGen,
    );

    // Clean and parse JSON
    final clean = raw
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    try {
      final list = jsonDecode(clean) as List;
      return list
          .map((q) => GeneratedQuestion.fromJson(Map<String, dynamic>.from(q)))
          .toList();
    } catch (e) {
      throw Exception('Failed to parse questions: $e\nRaw: $raw');
    }
  }

  // ── STREAMING SOLVER (shows answer letter by letter) ─────────
  // For the most human-like feel — shows answer appearing in real time
  Stream<String> solveStreaming({
    required String question,
    required List<ChatMessage> conversationHistory,
  }) async* {
    final response = await _dio.post(
      baseUrl,
      data: {
        'model': model,
        'stream': true,
        ...AIParams.solver,
        'messages': [
          {'role': 'system', 'content': HumanLikePrompts.solver},
          ...conversationHistory.map((m) => {'role': m.role, 'content': m.content}),
          {'role': 'user', 'content': question},
        ],
      },
      options: Options(responseType: ResponseType.stream),
    );

    await for (final chunk in (response.data as ResponseBody).stream) {
      final lines = utf8.decode(chunk).split('\n');
      for (final line in lines) {
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data == '[DONE]') return;
        try {
          final json = jsonDecode(data);
          final delta = json['choices']?[0]?['delta']?['content'];
          if (delta != null && delta is String) yield delta;
        } catch (_) {}
      }
    }
  }

  // ── INTERNAL CALL HELPER ─────────────────────────────────────
  Future<String> _call({
    required String systemPrompt,
    required List<ChatMessage> messages,
    required Map<String, dynamic> params,
  }) async {
    final response = await _dio.post(
      baseUrl,
      data: {
        'model': model,
        ...params,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          ...messages.map((m) => {'role': m.role, 'content': m.content}),
        ],
      },
    );
    return response.data['choices'][0]['message']['content'] as String;
  }
}

// ─── DATA MODELS ───────────────────────────────────────────────

class SolverResult {
  final String question;
  final String thinking;       // hidden chain-of-thought
  final String answer;         // main student-facing answer
  final String followUpQuestion; // Socratic next question

  SolverResult({
    required this.question,
    required this.thinking,
    required this.answer,
    required this.followUpQuestion,
  });
}

class ChatMessage {
  final String role;    // 'user' | 'assistant' | 'system'
  final String content;
  final DateTime? timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
  };
}

class GeneratedQuestion {
  final String id;
  final String question;
  final String type;
  final String difficulty;
  final int marks;
  final String topic;
  final String hint;
  final String modelAnswer;
  final String commonMistake;
  final String whyThisQuestion;

  GeneratedQuestion({
    required this.id,
    required this.question,
    required this.type,
    required this.difficulty,
    required this.marks,
    required this.topic,
    required this.hint,
    required this.modelAnswer,
    required this.commonMistake,
    required this.whyThisQuestion,
  });

  factory GeneratedQuestion.fromJson(Map<String, dynamic> j) => GeneratedQuestion(
    id: j['id'] ?? 'q${DateTime.now().millisecondsSinceEpoch}',
    question: j['question'] ?? '',
    type: j['type'] ?? 'conceptual',
    difficulty: j['difficulty'] ?? 'medium',
    marks: j['marks'] ?? 3,
    topic: j['topic'] ?? '',
    hint: j['hint'] ?? '',
    modelAnswer: j['model_answer'] ?? j['modelAnswer'] ?? '',
    commonMistake: j['common_mistake'] ?? j['commonMistake'] ?? '',
    whyThisQuestion: j['why_this_question'] ?? j['whyThisQuestion'] ?? '',
  );
}
