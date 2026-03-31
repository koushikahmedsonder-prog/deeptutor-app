enum AIProvider {
  gemini,
  openai,
  anthropic,
  deepseek,
  groq,
}

class LLMModel {
  final String name;
  final String model;
  final AIProvider provider;
  final String baseUrl;
  final String description;

  const LLMModel({
    required this.name,
    required this.model,
    required this.provider,
    required this.baseUrl,
    this.description = '',
  });

  /// Provider display name for API key labeling
  String get providerName => switch (provider) {
        AIProvider.gemini => 'Gemini',
        AIProvider.openai => 'OpenAI',
        AIProvider.anthropic => 'Anthropic',
        AIProvider.deepseek => 'DeepSeek',
        AIProvider.groq => 'Groq',
      };

  /// Hint text for the API key field
  String get apiKeyHint => switch (provider) {
        AIProvider.gemini => 'AIzaSy...',
        AIProvider.openai => 'sk-...',
        AIProvider.anthropic => 'sk-ant-...',
        AIProvider.deepseek => 'sk-...',
        AIProvider.groq => 'gsk_...',
      };
}

final List<LLMModel> availableModels = [
  // ── Gemini Models ──
  const LLMModel(
    name: 'Gemini 2.5 Pro',
    model: 'gemini-2.5-pro-preview-05-06',
    provider: AIProvider.gemini,
    baseUrl: 'https://generativelanguage.googleapis.com',
    description: 'Most capable Gemini model',
  ),
  const LLMModel(
    name: 'Gemini 2.5 Flash',
    model: 'gemini-2.5-flash-preview-05-20',
    provider: AIProvider.gemini,
    baseUrl: 'https://generativelanguage.googleapis.com',
    description: 'Fast & efficient',
  ),
  const LLMModel(
    name: 'Gemini 2.0 Flash',
    model: 'gemini-2.0-flash',
    provider: AIProvider.gemini,
    baseUrl: 'https://generativelanguage.googleapis.com',
    description: 'Stable & reliable',
  ),

  // ── OpenAI Models ──
  const LLMModel(
    name: 'GPT-4.1',
    model: 'gpt-4.1',
    provider: AIProvider.openai,
    baseUrl: 'https://api.openai.com/v1',
    description: 'Most capable OpenAI model',
  ),
  const LLMModel(
    name: 'GPT-4.1 Mini',
    model: 'gpt-4.1-mini',
    provider: AIProvider.openai,
    baseUrl: 'https://api.openai.com/v1',
    description: 'Fast & affordable',
  ),
  const LLMModel(
    name: 'GPT-4o',
    model: 'gpt-4o',
    provider: AIProvider.openai,
    baseUrl: 'https://api.openai.com/v1',
    description: 'Multimodal flagship',
  ),

  // ── Anthropic Models ──
  const LLMModel(
    name: 'Claude Sonnet 4',
    model: 'claude-sonnet-4-20250514',
    provider: AIProvider.anthropic,
    baseUrl: 'https://api.anthropic.com/v1',
    description: 'Best balance of speed & quality',
  ),
  const LLMModel(
    name: 'Claude Haiku 3.5',
    model: 'claude-3-5-haiku-20241022',
    provider: AIProvider.anthropic,
    baseUrl: 'https://api.anthropic.com/v1',
    description: 'Fastest Claude model',
  ),

  // ── DeepSeek Models ──
  const LLMModel(
    name: 'DeepSeek Chat',
    model: 'deepseek-chat',
    provider: AIProvider.deepseek,
    baseUrl: 'https://api.deepseek.com/v1',
    description: 'Powerful open-weight model',
  ),
  const LLMModel(
    name: 'DeepSeek Reasoner',
    model: 'deepseek-reasoner',
    provider: AIProvider.deepseek,
    baseUrl: 'https://api.deepseek.com/v1',
    description: 'Advanced reasoning',
  ),

  // ── Groq Models ──
  const LLMModel(
    name: 'Llama 3.3 70B',
    model: 'llama-3.3-70b-versatile',
    provider: AIProvider.groq,
    baseUrl: 'https://api.groq.com/openai/v1',
    description: 'Fast open-source via Groq',
  ),
  const LLMModel(
    name: 'Llama 4 Scout',
    model: 'meta-llama/llama-4-scout-17b-16e-instruct',
    provider: AIProvider.groq,
    baseUrl: 'https://api.groq.com/openai/v1',
    description: 'Latest Meta model via Groq',
  ),
];
