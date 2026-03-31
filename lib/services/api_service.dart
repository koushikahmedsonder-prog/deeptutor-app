import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/models_config.dart';
import 'document_service.dart';
import 'deeptutor_prompts.dart';

class ApiService {
  late final Dio _dio;
  String _apiKey;
  LLMModel _model;

  ApiService({required String apiKey, required LLMModel model})
      : _apiKey = apiKey,
        _model = model {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      headers: {
        'Content-Type': 'application/json',
      },
    ));
  }

  void updateApiKey(String key) => _apiKey = key;
  void updateModel(LLMModel model) => _model = model;

  String get apiKey => _apiKey;
  LLMModel get currentModel => _model;
  bool get hasApiKey => _apiKey.isNotEmpty;

  // ── Unified call method — routes to the correct provider ──
  Future<String> callLLM({
    required String prompt,
    String? systemInstruction,
    LLMModel? modelOverride,
    PickedDocument? attachment,
    bool useWebSearch = false,
  }) async {
    final model = modelOverride ?? _model;

    if (_apiKey.isEmpty) {
      throw ApiException(
          'No API key configured. Add your ${model.providerName} API key in Settings.');
    }

    // ── Pre-extract text from non-image documents
    // Gemini handles images & PDFs natively via inlineData.
    // Claude and OpenAI receive all content as text in the prompt.
    String enrichedPrompt = prompt;
    PickedDocument? imageAttachment; // Only populated for image types

    if (attachment != null) {
      if (attachment.type == DocumentType.image) {
        // Images are forwarded as-is to Gemini; for others, encode as base64 text summary
        if (model.provider == AIProvider.gemini) {
          imageAttachment = attachment;
        } else {
          // For Claude / OpenAI we just mention the image (no vision support via this code path)
          enrichedPrompt = '$prompt\n\n[User attached an image: ${attachment.name}]';
        }
      } else {
        // PDF / DOC / TXT — extract text and inject into prompt for ALL providers
        final extractedText = await attachment.readContent();
        enrichedPrompt =
            '$prompt\n\n---\n**Attached document: ${attachment.name}**\n$extractedText\n---';

        // Gemini also gets the raw PDF bytes for higher-quality parsing on top of text
        if (model.provider == AIProvider.gemini &&
            attachment.type == DocumentType.pdf &&
            attachment.bytes != null) {
          imageAttachment = attachment; // reuse field to pass PDF bytes to _callGemini
        }
      }
    }

    return switch (model.provider) {
      AIProvider.gemini => _callGemini(
          prompt: enrichedPrompt,
          systemInstruction: systemInstruction,
          model: model,
          attachment: imageAttachment,
          useWebSearch: useWebSearch,
        ),
      AIProvider.anthropic => _callAnthropic(
          prompt: enrichedPrompt,
          systemInstruction: systemInstruction,
          model: model,
        ),
      // OpenAI, DeepSeek, Groq all use OpenAI-compatible API
      _ => _callOpenAICompatible(
          prompt: enrichedPrompt,
          systemInstruction: systemInstruction,
          model: model,
        ),
    };
  }

  // ── Gemini API ──
  Future<String> _callGemini({
    required String prompt,
    String? systemInstruction,
    required LLMModel model,
    PickedDocument? attachment,
    bool useWebSearch = false,
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/${model.model}:generateContent?key=$_apiKey';

    final contents = <Map<String, dynamic>>[];

    // Build the user parts
    final userParts = <Map<String, dynamic>>[];

    // User prompt is ONLY the user's text — system instruction goes separately
    userParts.add({'text': prompt});

    // Add attachment if present and contains bytes (only image + PDF for Gemini inline)
    if (attachment != null && attachment.bytes != null) {
      if (attachment.type == DocumentType.image) {
        // Determine mimetype
        String mimeType = 'image/jpeg';
        final pathLower = attachment.path.toLowerCase();
        if (pathLower.endsWith('.png')) mimeType = 'image/png';
        else if (pathLower.endsWith('.webp')) mimeType = 'image/webp';
        else if (pathLower.endsWith('.gif')) mimeType = 'image/gif';

        userParts.add({
          'inlineData': {
            'mimeType': mimeType,
            'data': base64Encode(attachment.bytes!),
          }
        });
      } else if (attachment.type == DocumentType.pdf) {
        // Native Gemini PDF parsing via inlineData
        userParts.add({
          'inlineData': {
            'mimeType': 'application/pdf',
            'data': base64Encode(attachment.bytes!),
          }
        });
      }
      // Text/doc attachment text is already injected into the prompt by callLLM
    }

    contents.add({
      'role': 'user',
      'parts': userParts,
    });

    try {
      final response = await _dio.post(
        url,
        data: {
          // ── Proper Gemini system_instruction field ──
          // This is the official way to set system behaviour.
          // Gemini strongly respects this vs text mixed into user content.
          if (systemInstruction != null && systemInstruction.isNotEmpty)
            'system_instruction': {
              'parts': [
                {'text': systemInstruction}
              ]
            },
          'contents': contents,
          if (useWebSearch)
            'tools': [
              {
                'google_search': {}
              }
            ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 8192,
          },
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final candidate = candidates[0];
          final content = candidate['content'];
          final parts = content['parts'] as List?;
          String textResponse = 'No response generated.';
          if (parts != null && parts.isNotEmpty) {
            textResponse = parts[0]['text']?.toString() ?? 'No response generated.';
          }
          
          if (useWebSearch) {
            final groundingMetadata = candidate['groundingMetadata'] as Map<String, dynamic>?;
            if (groundingMetadata != null) {
              final chunks = groundingMetadata['groundingChunks'] as List?;
              if (chunks != null && chunks.isNotEmpty) {
                final sourceBuffer = StringBuffer();
                sourceBuffer.writeln('\n\n---\n**Sources:**');
                int sourceIndex = 1;
                final seenUrls = <String>{};
                for (var chunk in chunks) {
                  final web = chunk['web'] as Map<String, dynamic>?;
                  if (web != null) {
                    final uri = web['uri']?.toString() ?? '';
                    final title = web['title']?.toString() ?? uri;
                    if (uri.isNotEmpty && !seenUrls.contains(uri)) {
                      seenUrls.add(uri);
                      sourceBuffer.writeln('$sourceIndex. [$title]($uri)');
                      sourceIndex++;
                    }
                  }
                }
                if (sourceIndex > 1) {
                  textResponse += sourceBuffer.toString();
                }
              }
            }
          }
          return textResponse;
        }
        return 'No response generated.';
      } else {
        throw ApiException(
            'Gemini API error: ${response.statusCode} ${response.statusMessage}');
      }
    } on DioException catch (e) {
      _handleDioError(e, 'Gemini');
      rethrow; // unreachable, _handleDioError always throws
    }
  }

  // ── OpenAI-compatible API (OpenAI, DeepSeek, Groq) ──
  Future<String> _callOpenAICompatible({
    required String prompt,
    String? systemInstruction,
    required LLMModel model,
  }) async {
    final url = '${model.baseUrl}/chat/completions';

    final messages = <Map<String, String>>[];
    if (systemInstruction != null && systemInstruction.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemInstruction});
    }
    messages.add({'role': 'user', 'content': prompt});

    try {
      final response = await _dio.post(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
          },
        ),
        data: {
          'model': model.model,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 8192,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          return choices[0]['message']['content']?.toString() ??
              'No response generated.';
        }
        return 'No response generated.';
      } else {
        throw ApiException(
            '${model.providerName} API error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e, model.providerName);
      rethrow;
    }
  }

  // ── Anthropic Claude API ──
  Future<String> _callAnthropic({
    required String prompt,
    String? systemInstruction,
    required LLMModel model,
  }) async {
    const url = 'https://api.anthropic.com/v1/messages';

    final messages = <Map<String, String>>[];
    messages.add({'role': 'user', 'content': prompt});

    try {
      final response = await _dio.post(
        url,
        options: Options(
          headers: {
            'x-api-key': _apiKey,
            'anthropic-version': '2023-06-01',
          },
        ),
        data: {
          'model': model.model,
          'max_tokens': 8192,
          'messages': messages,
          if (systemInstruction != null && systemInstruction.isNotEmpty)
            'system': systemInstruction,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final content = data['content'] as List?;
        if (content != null && content.isNotEmpty) {
          return content[0]['text']?.toString() ?? 'No response generated.';
        }
        return 'No response generated.';
      } else {
        throw ApiException(
            'Claude API error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e, 'Claude');
      rethrow;
    }
  }

  // ── Error handling ──
  Never _handleDioError(DioException e, String providerName) {
    if (e.response?.statusCode == 400) {
      final errorMsg = e.response?.data is Map
          ? (e.response?.data?['error']?['message'] ?? e.message)
          : e.message;
      throw ApiException('$providerName error: $errorMsg');
    }
    if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
      throw ApiException(
          'Invalid API key for $providerName. Check your key in Settings.');
    }
    if (e.response?.statusCode == 404) {
      throw ApiException(
          'Model not found. The model "${_model.model}" may not be available. Try a different model.');
    }
    if (e.response?.statusCode == 429) {
      throw ApiException(
          'Rate limit exceeded for $providerName. Wait a moment and try again.');
    }
    throw ApiException('$providerName network error: ${e.message}');
  }

  // ── Convenience methods used by other screens ──

  /// Test API key with a simple request
  Future<String> testConnection() async {
    return callLLM(prompt: 'Say "OK" in one word.');
  }

  /// Solve a question using KB context
  Future<String> solveQuestion({
    required String question,
    String? kbContent,
    PickedDocument? attachment,
    bool useWebSearch = false,
  }) async {
    String systemPrompt = DeepTutorPrompts.smartSolver;

    if (kbContent != null && kbContent.isNotEmpty) {
      systemPrompt += '\n\nKNOWLEDGE BASE CONTENT (use this as context):\n$kbContent';
    }
    if (useWebSearch) {
      systemPrompt += '\n\nYour connection to Google Search is enabled. Use it to fetch the most recent and relevant information. If the prompt requires a specific location and it is not provided, ask the user.';
    }

    return callLLM(
      prompt: question,
      systemInstruction: systemPrompt,
      attachment: attachment,
      useWebSearch: useWebSearch,
    );
  }

  /// Generate questions from KB content
  Future<List<Map<String, dynamic>>> generateQuestions({
    required String topic,
    required int count,
    String? kbContent,
  }) async {
    final contextPart = kbContent != null && kbContent.isNotEmpty
        ? '\n\nUse the following knowledge base content to create relevant questions:\n$kbContent'
        : '';

    final prompt =
        'Generate exactly $count educational questions about "$topic".$contextPart';

    final response = await callLLM(
      prompt: prompt,
      systemInstruction: DeepTutorPrompts.questionGenerator,
    );

    try {
      String jsonStr = response.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceAll(RegExp(r'^```\w*\n?'), '');
        jsonStr = jsonStr.replaceAll(RegExp(r'\n?```$'), '');
      }
      jsonStr = jsonStr.trim();

      final parsed = jsonDecode(jsonStr);
      if (parsed is List) {
        return parsed.map((q) {
          if (q is Map<String, dynamic>) return q;
          return {'question': q.toString(), 'answer': 'N/A'};
        }).toList();
      }
    } catch (_) {
      return [
        {'question': topic, 'answer': response}
      ];
    }

    return [];
  }

  /// Deep research on a topic
  Future<String> deepResearch({
    required String topic,
    required String preset,
  }) async {
    final depthInstruction = switch (preset) {
      'quick' => 'Depth level: quick (~400 words). Concise overview with key points.',
      'medium' => 'Depth level: medium (~800 words). Thorough analysis with sections, examples, and key takeaways.',
      'deep' => 'Depth level: deep (~1500 words). Comprehensive report with introduction, background, detailed analysis, multiple perspectives, examples, case studies, tables, and conclusion.',
      _ => 'Decide the appropriate depth based on the complexity of the topic.',
    };

    return callLLM(
      prompt: 'Conduct in-depth research on the following topic.\n\nTopic: $topic\n\n$depthInstruction',
      systemInstruction: DeepTutorPrompts.deepResearch,
    );
  }

  /// Generate ideas
  Future<String> generateIdeas({
    required String topic,
    required String context,
  }) async {
    return callLLM(
      prompt: 'Topic: $topic${context.isNotEmpty ? '\nAdditional context: $context' : ''}',
      systemInstruction: DeepTutorPrompts.ideaGenCoWriter,
    );
  }

  /// Summarize text content
  Future<String> summarize(String content) async {
    return callLLM(
      prompt:
          '''Summarize the following content concisely but thoroughly. Use markdown formatting with key points and a brief conclusion.

Content:
$content''',
    );
  }

  /// Scan/analyze document content
  Future<String> analyzeDocument(String content, String fileName) async {
    return callLLM(
      prompt: 'Analyze the following document.\n\nDocument: $fileName\n\nContent:\n$content',
      systemInstruction: DeepTutorPrompts.smartSolver,
    );
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
