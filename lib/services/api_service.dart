import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/models_config.dart';
import 'document_service.dart';
import 'deeptutor_prompts.dart';
import 'duckduckgo_service.dart';

class ApiService {
  late final Dio _dio;
  Map<String, String> _apiKeys;
  LLMModel _model;
  bool _autoFallback;
  final String _preferredLanguage;

  /// Track the last model actually used (may differ from _model if fallback occurred)
  LLMModel? _lastUsedModel;
  LLMModel? get lastUsedModel => _lastUsedModel;

  ApiService({
    required Map<String, String> apiKeys,
    required LLMModel model,
    bool autoFallback = true,
    String preferredLanguage = 'English',
  })  : _apiKeys = apiKeys,
        _model = model,
        _autoFallback = autoFallback,
        _preferredLanguage = preferredLanguage {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      headers: {
        'Content-Type': 'application/json',
      },
    ));
  }

  void updateApiKeys(Map<String, String> keys) => _apiKeys = keys;
  void updateApiKey(String key) {
    _apiKeys[_model.providerKey] = key;
  }
  void updateModel(LLMModel model) => _model = model;
  void updateAutoFallback(bool enabled) => _autoFallback = enabled;

  String get apiKey => _apiKeys[_model.providerKey] ?? '';
  LLMModel get currentModel => _model;
  bool get hasApiKey => apiKey.isNotEmpty;

  /// Get API key for a specific provider
  String _getApiKey(AIProvider provider) {
    return _apiKeys[provider.name] ?? '';
  }

  // ── Unified call method — routes to the correct provider with auto-fallback ──
  Future<String> callLLM({
    required String prompt,
    String? systemInstruction,
    LLMModel? modelOverride,
    PickedDocument? attachment,
    bool useWebSearch = false,
    int? maxTokens,
  }) async {
    LLMModel model = modelOverride ?? _model;
    String finalPrompt = prompt;

    // Apply language constraint if missing
    String finalSystemInstruction = systemInstruction ?? '';
    if (_preferredLanguage != 'English') {
      finalSystemInstruction += '\n\nCRITICAL INSTRUCTION: You MUST generate your response entirely in $_preferredLanguage language.';
      // We also enforce it slightly on the prompt so basic models understand.
      finalPrompt = '[RESPOND STRICTLY IN $_preferredLanguage] $finalPrompt';
    }

    // ⚡ Custom DuckDuckGo Web Search for explicit grounding!
    if (useWebSearch) {
      print('🦆 Web Search requested on ${model.name}. Fetching search results...');
      final searchResults = await DuckDuckGoService.search(prompt);
      if (searchResults.isNotEmpty) {
        finalPrompt = '$searchResults\n\nUser Question: $prompt';
      }
    }

    final key = _getApiKey(model.provider);

    if (key.isEmpty) {
      // If auto-fallback, try to find any provider with a key
      if (_autoFallback) {
        final fallback = _findAnyAvailableModel();
        if (fallback != null) {
          return _callWithFallback(
            prompt: finalPrompt,
            systemInstruction: finalSystemInstruction,
            model: fallback,
            attachment: attachment,
            useWebSearch: useWebSearch,
            maxTokens: maxTokens,
          );
        }
      }
      throw ApiException(
          'No API key configured. [Get your free ${model.providerName} API key](${model.apiKeyUrl}) and add it in Settings.');
    }

    return _callWithFallback(
      prompt: finalPrompt,
      systemInstruction: finalSystemInstruction,
      model: model,
      attachment: attachment,
      useWebSearch: useWebSearch,
      maxTokens: maxTokens,
    );
  }

  /// Call with auto-fallback on rate limit / token exhaustion
  Future<String> _callWithFallback({
    required String prompt,
    String? systemInstruction,
    required LLMModel model,
    PickedDocument? attachment,
    bool useWebSearch = false,
    int? maxTokens,
    int retryCount = 0,
    Set<String>? triedModels,
  }) async {
    final currentlyTried = triedModels ?? {model.name};
    currentlyTried.add(model.name);

    try {
      final result = await _executeCall(
        prompt: prompt,
        systemInstruction: systemInstruction,
        model: model,
        attachment: attachment,
        useWebSearch: useWebSearch,
        maxTokens: maxTokens,
      );
      _lastUsedModel = model;
      return result;
    } catch (e) {
      // Check if this is a rate-limit, quota, or model not found error that we can fall back from
      if (_autoFallback && retryCount < 3 && _isFallbackableError(e)) {
        final fallbackModel = _findFallbackModel(model, currentlyTried);
        if (fallbackModel != null) {
          print('⚡ Auto-fallback: ${model.name} → ${fallbackModel.name} (error...)');
          return _callWithFallback(
            prompt: prompt,
            systemInstruction: systemInstruction,
            model: fallbackModel,
            attachment: attachment,
            useWebSearch: useWebSearch,
            maxTokens: maxTokens,
            retryCount: retryCount + 1,
            triedModels: currentlyTried,
          );
        }
      }
      rethrow;
    }
  }

  /// Check if error is a rate-limit, quota exhaustion, or model not found error
  bool _isFallbackableError(Object e) {
    if (e is ApiException) {
      final msg = e.message.toLowerCase();
      return msg.contains('rate limit') ||
          msg.contains('429') ||
          msg.contains('quota') ||
          msg.contains('tokens') ||
          msg.contains('exceeded') ||
          msg.contains('too many requests') ||
          msg.contains('resource_exhausted') ||
          msg.contains('model not found') ||
          msg.contains('404') ||
          msg.contains('invalid argument');
    }
    if (e is DioException) {
      return e.response?.statusCode == 429 || e.response?.statusCode == 404 || e.response?.statusCode == 400;
    }
    return false;
  }

  /// Find a fallback model — first try same provider (lower tier), then cross-provider
  LLMModel? _findFallbackModel(LLMModel current, Set<String> triedModels) {
    // 1. Try same provider, next tier down
    final sameProvider = availableModels
        .where((m) =>
            m.provider == current.provider &&
            !triedModels.contains(m.name) &&
            m.tier >= current.tier &&
            _getApiKey(m.provider).isNotEmpty)
        .toList()
      ..sort((a, b) => a.tier.compareTo(b.tier));

    if (sameProvider.isNotEmpty) return sameProvider.first;

    // 2. Try any other provider that has a key
    final crossProvider = availableModels
        .where((m) =>
            m.provider != current.provider &&
            !triedModels.contains(m.name) &&
            _getApiKey(m.provider).isNotEmpty)
        .toList()
      ..sort((a, b) => a.tier.compareTo(b.tier));

    if (crossProvider.isNotEmpty) return crossProvider.first;

    return null;
  }

  /// Find any model that has an API key
  LLMModel? _findAnyAvailableModel() {
    for (final model in availableModels) {
      if (_getApiKey(model.provider).isNotEmpty) {
        return model;
      }
    }
    return null;
  }

  /// Execute the actual API call — routes to the correct provider
  Future<String> _executeCall({
    required String prompt,
    String? systemInstruction,
    required LLMModel model,
    PickedDocument? attachment,
    bool useWebSearch = false,
    int? maxTokens,
  }) async {
    // ── Pre-extract text from non-image documents
    String enrichedPrompt = prompt;
    PickedDocument? imageAttachment;

    if (attachment != null) {
      if (attachment.type == DocumentType.image) {
        if (model.provider == AIProvider.gemini) {
          imageAttachment = attachment;
        } else {
          // Send base64 marker directly into the prompt for OpenAI vision extraction
          final extractedMarker = await attachment.readContent();
          enrichedPrompt = '$prompt\n\n$extractedMarker';
        }
      } else {
        final extractedText = await attachment.readContent();
        enrichedPrompt =
            '$prompt\n\n---\n**Attached document: ${attachment.name}**\n$extractedText\n---';

        if (model.provider == AIProvider.gemini &&
            attachment.type == DocumentType.pdf &&
            attachment.bytes != null) {
          imageAttachment = attachment;
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
          maxTokens: maxTokens,
        ),
      AIProvider.anthropic => _callAnthropic(
          prompt: enrichedPrompt,
          systemInstruction: systemInstruction,
          model: model,
          maxTokens: maxTokens,
        ),
      // OpenAI, DeepSeek, Groq, Cerebras, SambaNova all use OpenAI-compatible API
      _ => _callOpenAICompatible(
          prompt: enrichedPrompt,
          systemInstruction: systemInstruction,
          model: model,
          maxTokens: maxTokens,
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
    int? maxTokens,
  }) async {
    final key = _getApiKey(model.provider);
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/${model.model}:generateContent?key=$key';

    final contents = <Map<String, dynamic>>[];
    final userParts = <Map<String, dynamic>>[];

    userParts.add({'text': prompt});

    if (attachment != null && attachment.bytes != null) {
      if (attachment.type == DocumentType.image) {
        String mimeType = 'image/jpeg';
        final pathLower = attachment.path.toLowerCase();
        if (pathLower.endsWith('.png')) {
          mimeType = 'image/png';
        } else if (pathLower.endsWith('.webp')) mimeType = 'image/webp';
        else if (pathLower.endsWith('.gif')) mimeType = 'image/gif';

        userParts.add({
          'inlineData': {
            'mimeType': mimeType,
            'data': base64Encode(attachment.bytes!),
          }
        });
      } else if (attachment.type == DocumentType.pdf) {
        userParts.add({
          'inlineData': {
            'mimeType': 'application/pdf',
            'data': base64Encode(attachment.bytes!),
          }
        });
      }
    }

    contents.add({
      'role': 'user',
      'parts': userParts,
    });

    try {
      final response = await _dio.post(
        url,
        data: {
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
                'googleSearch': {}
              }
            ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': maxTokens ?? 8192,
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
    }
  }

  // ── OpenAI-compatible API (OpenAI, DeepSeek, Groq, Cerebras, SambaNova) ──
  Future<String> _callOpenAICompatible({
    required String prompt,
    String? systemInstruction,
    required LLMModel model,
    int? maxTokens,
  }) async {
    final key = _getApiKey(model.provider);
    final url = '${model.baseUrl}/chat/completions';

    final messages = <dynamic>[];
    if (systemInstruction != null && systemInstruction.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemInstruction});
    }

    // Detect BASE64_IMAGE marker for Vision APIs
    final imageRegex = RegExp(r'\[BASE64_IMAGE:([^:]+):([^\]]+)\]');
    final match = imageRegex.firstMatch(prompt);

    if (match != null) {
      final mimeType = match.group(1)!;
      final base64Data = match.group(2)!;
      final cleanPrompt = prompt.replaceAll(match.group(0)!, '').trim();

      messages.add({
        'role': 'user',
        'content': [
          if (cleanPrompt.isNotEmpty)
            {
              'type': 'text',
              'text': cleanPrompt,
            },
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:$mimeType;base64,$base64Data'
            }
          }
        ]
      });
    } else {
      messages.add({'role': 'user', 'content': prompt});
    }

    try {
      final response = await _dio.post(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $key',
          },
        ),
        data: {
          'model': model.model,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': ?maxTokens,
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
    }
  }

  Future<String> _callAnthropic({
    required String prompt,
    String? systemInstruction,
    required LLMModel model,
    int? maxTokens,
  }) async {
    final key = _getApiKey(model.provider);
    const url = 'https://api.anthropic.com/v1/messages';

    final messages = <Map<String, String>>[];
    messages.add({'role': 'user', 'content': prompt});

    try {
      final response = await _dio.post(
        url,
        options: Options(
          headers: {
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
          },
        ),
        data: {
          'model': model.model,
          'max_tokens': maxTokens ?? 4096,
          if (systemInstruction != null && systemInstruction.isNotEmpty)
            'system': systemInstruction,
          'messages': messages,
          'temperature': 0.7,
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

  /// General chat question without structured solver requirements
  Future<String> chatQuestion({
    required String question,
    PickedDocument? attachment,
    bool useWebSearch = false,
  }) async {
    String systemPrompt = '''
You are DeepTutor, a helpful, intelligent learning assistant.
Provide clear, accurate, and concise answers directly addressing the user's prompt, behaving like a smart search engine or conversational tutor.
Use rich markdown formatting (bold, bullet points, simple headers) to make the answer highly readable.
Use LaTeX for math or science formulas when appropriate.
If the question is conversational, provide a conversational answer.
DO NOT use the elaborate "Concept Map", "Problem Analysis", or "Solution Strategy" structures. Just answer the question directly.
''';

    if (useWebSearch) {
      systemPrompt += '\n\nYour connection to Google Search is enabled. Use it to fetch the most recent and relevant information.';
    }

    return callLLM(
      prompt: question,
      systemInstruction: systemPrompt,
      attachment: attachment,
      useWebSearch: useWebSearch,
    );
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
      print('=== GEMINI RAW ===\n$jsonStr\n=== END ===');
      
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
        if (jsonStr.endsWith('```')) {
          jsonStr = jsonStr.substring(0, jsonStr.length - 3);
        }
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'^```[a-zA-Z]*'), '');
        if (jsonStr.endsWith('```')) {
          jsonStr = jsonStr.substring(0, jsonStr.length - 3);
        }
      }
      
      jsonStr = jsonStr.trim();
      if (jsonStr.startsWith('[') && jsonStr.lastIndexOf(']') != -1) {
        jsonStr = jsonStr.substring(jsonStr.indexOf('['), jsonStr.lastIndexOf(']') + 1);
      }
      
      // Fix trailing commas which dart:convert rejects
      jsonStr = jsonStr.replaceAll(RegExp(r',\s*}'), '}');
      jsonStr = jsonStr.replaceAll(RegExp(r',\s*]'), ']');
      
      print('=== GEMINI PARSED ===\n$jsonStr\n=== END ===');

      final parsed = jsonDecode(jsonStr);
      if (parsed is List) {
        return parsed.map((q) {
          if (q is Map<String, dynamic>) return q;
          return {'question': q.toString(), 'answer': 'N/A'};
        }).toList();
      }
    } catch (e) {
      print('=== JSON ERROR ===\n$e\n==================');
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

    // Step 1: Ask AI to decompose topic into subtopics
    final decompositionPrompt = '''
Break this research topic into 4 specific search queries for web research.
Topic: $topic

CRITICAL: Return ONLY a raw JSON array of 4 search query strings. Do not include markdown formatting, backticks, or introduction text. Example exactly like this:
["query 1", "query 2", "query 3", "query 4"]
''';

    final raw = await callLLM(prompt: decompositionPrompt);
    List<String> queries;
    try {
      String jsonStr = raw.trim();
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
        if (jsonStr.endsWith('```')) jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.substring(3);
        if (jsonStr.endsWith('```')) jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      jsonStr = jsonStr.trim();
      if (jsonStr.startsWith('[') && jsonStr.lastIndexOf(']') != -1) {
        jsonStr = jsonStr.substring(jsonStr.indexOf('['), jsonStr.lastIndexOf(']') + 1);
      }
      queries = (jsonDecode(jsonStr) as List).cast<String>();
      if (queries.isEmpty) queries = [topic];
    } catch (e) {
      print('🦆 Decomposition parse error: $e. Using original topic.');
      queries = [topic];
    }

    // Step 2: Search all subtopics in parallel
    print('🦆 Deep Research searching subtopics: $queries');
    final futures = queries.map((q) => DuckDuckGoService.searchWithContent(q));
    final results = await Future.wait(futures);

    // Step 3: Combine all research
    final combinedResearch = results
      .asMap()
      .entries
      .map((e) => '## Subtopic ${e.key + 1}: ${queries[e.key]}\n${e.value}')
      .join('\n\n');

    final enrichedPrompt = '''
      Research Topic: $topic
      
      $depthInstruction
      
      REAL WEB RESEARCH DATA (use this as your primary source):
      $combinedResearch
      
      Write a comprehensive deep research report using ONLY 
      the above data. Cite real URLs from the sources above.
    ''';

    return callLLM(
      prompt: enrichedPrompt,
      systemInstruction: DeepTutorPrompts.deepResearch,
      maxTokens: 4000,
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
