import 'dart:convert';
import 'api_service.dart';
import 'export_service.dart';

/// Asks the AI to turn arbitrary markdown/text content into structured
/// data models ready for ExportService to render.
class ExportContentService {
  /// [type] must be one of: 'slides', 'flashcards', 'mindmap'
  static Future<Map<String, dynamic>> generateExportContent({
    required String content,
    required String exportType,
    required ApiService api,
  }) async {
    final isTopicOnly = content.trim().length < 200 && !content.contains('\n\n');

    final prompts = {
      'slides': isTopicOnly ? '''
You are an expert presentation generator. Deeply research and generate a comprehensive presentation on the topic: "$content".
Return ONLY valid JSON (no markdown code fences), matching this schema exactly:
{
  "title": "presentation title",
  "slides": [
    {
      "title": "slide title",
      "bulletPoints": ["point 1", "point 2", "point 3"],
      "keyTerm": "one key concept to remember"
    }
  ]
}
Generate 6–12 highly informative, detailed slides covering all major aspects of the topic.
''' : '''
Convert the following content into structured presentation slides.
Return ONLY valid JSON (no markdown code fences), matching this schema exactly:
{
  "title": "presentation title",
  "slides": [
    {
      "title": "slide title",
      "bulletPoints": ["point 1", "point 2", "point 3"],
      "keyTerm": "one key concept to remember"
    }
  ]
}
Generate at least 4–8 slides covering all major sections of the content.
Content:
$content
''',
      'flashcards': isTopicOnly ? '''
You are an expert tutor. Research and generate high-quality study flashcards for the topic: "$content".
Return ONLY valid JSON (no markdown code fences), matching this schema exactly:
{
  "title": "deck title",
  "flashcards": [
    {"question": "question text", "answer": "answer text"}
  ]
}
Generate 10–20 comprehensive flashcards covering key facts, definitions, and concepts about the topic.
''' : '''
Convert the following content into study flashcards.
Return ONLY valid JSON (no markdown code fences), matching this schema exactly:
{
  "title": "deck title",
  "flashcards": [
    {"question": "question text", "answer": "answer text"}
  ]
}
Generate 8–15 flashcards covering the key facts, definitions, and concepts.
Content:
$content
''',
      'mindmap': isTopicOnly ? '''
You are an expert cartographer of ideas. Research and generate a comprehensive mind map structure for the topic: "$content".
Return ONLY valid JSON (no markdown code fences), matching this schema exactly:
{
  "centralTopic": "main topic in 3-5 words",
  "branches": [
    {
      "title": "branch name",
      "children": ["sub point 1", "sub point 2", "sub point 3"]
    }
  ]
}
Generate 5–8 major branches, each with 3–5 detailed child items.
''' : '''
Convert the following content into a mind map structure.
Return ONLY valid JSON (no markdown code fences), matching this schema exactly:
{
  "centralTopic": "main topic in 3-5 words",
  "branches": [
    {
      "title": "branch name",
      "children": ["sub point 1", "sub point 2", "sub point 3"]
    }
  ]
}
Generate 4–7 branches, each with 2–4 child items.
Content:
$content
''',
    };

    final prompt = prompts[exportType];
    if (prompt == null) throw ArgumentError('Unknown export type: $exportType');

    final raw = await api.callLLM(
      prompt: prompt,
      systemInstruction:
          'You are a precise JSON generator. Return ONLY valid JSON with no markdown code fences, no extra commentary, and no trailing commas.',
    );

    // Strip any markdown fences if the model added them anyway
    String jsonStr = raw.trim();
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      jsonStr = jsonStr.replaceAll(RegExp(r'```$'), '').trim();
    }
    // Fix trailing commas that dart:convert rejects
    jsonStr = jsonStr.replaceAll(RegExp(r',\s*}'), '}');
    jsonStr = jsonStr.replaceAll(RegExp(r',\s*]'), ']');

    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  // ── Convenience builders ──────────────────────────────────────────────────

  static List<ExportSlide> slidesFromJson(Map<String, dynamic> data) {
    return (data['slides'] as List).map((s) {
      return ExportSlide(
        title: s['title']?.toString() ?? '',
        bulletPoints: List<String>.from(s['bulletPoints'] ?? []),
        keyTerm: s['keyTerm']?.toString(),
      );
    }).toList();
  }

  static List<Flashcard> flashcardsFromJson(Map<String, dynamic> data) {
    return (data['flashcards'] as List).map((f) {
      return Flashcard(
        question: f['question']?.toString() ?? '',
        answer: f['answer']?.toString() ?? '',
      );
    }).toList();
  }

  static MindMapData mindMapFromJson(Map<String, dynamic> data) {
    return MindMapData(
      centralTopic: data['centralTopic']?.toString() ?? 'Main Topic',
      branches: (data['branches'] as List).map((b) {
        return MindMapBranch(
          title: b['title']?.toString() ?? '',
          children: List<String>.from(b['children'] ?? []),
        );
      }).toList(),
    );
  }
}
