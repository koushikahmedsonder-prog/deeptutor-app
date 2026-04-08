enum AIProvider {
  groq,
  cerebras,
  sambanova,
  gemini,
  openai,
  anthropic,
  deepseek,
}

class LLMModel {
  final String name;
  final String model;
  final AIProvider provider;
  final String baseUrl;
  final String description;
  final int tier; // 1 = highest quality, 2 = mid, 3 = budget/fast
  final bool isFree;
  final String apiKeyUrl; // Direct link to get API key

  const LLMModel({
    required this.name,
    required this.model,
    required this.provider,
    required this.baseUrl,
    this.description = '',
    this.tier = 2,
    this.isFree = false,
    this.apiKeyUrl = '',
  });

  /// Provider display name for API key labeling
  String get providerName => switch (provider) {
        AIProvider.groq => 'Groq',
        AIProvider.cerebras => 'Cerebras',
        AIProvider.sambanova => 'SambaNova',
        AIProvider.gemini => 'Gemini',
        AIProvider.openai => 'OpenAI',
        AIProvider.anthropic => 'Anthropic',
        AIProvider.deepseek => 'DeepSeek',
      };

  /// Hint text for the API key field
  String get apiKeyHint => switch (provider) {
        AIProvider.groq => 'gsk_...',
        AIProvider.cerebras => 'csk-...',
        AIProvider.sambanova => 'sk-...',
        AIProvider.gemini => 'AIzaSy...',
        AIProvider.openai => 'sk-...',
        AIProvider.anthropic => 'sk-ant-...',
        AIProvider.deepseek => 'sk-...',
      };

  /// Storage key for this provider's API key
  String get providerKey => provider.name; // e.g. 'groq', 'gemini', etc.
}

/// Provider metadata for UI display
class ProviderInfo {
  final AIProvider provider;
  final String name;
  final String description;
  final String apiKeyUrl;
  final bool isFree;
  final String freeNote;

  const ProviderInfo({
    required this.provider,
    required this.name,
    required this.description,
    required this.apiKeyUrl,
    this.isFree = false,
    this.freeNote = '',
  });
}

/// All supported providers with their info
const List<ProviderInfo> providerInfoList = [
  ProviderInfo(
    provider: AIProvider.groq,
    name: 'Groq',
    description: 'Ultra-fast inference, free tier',
    apiKeyUrl: 'https://console.groq.com/keys',
    isFree: true,
    freeNote: '✨ Free — No credit card',
  ),
  ProviderInfo(
    provider: AIProvider.cerebras,
    name: 'Cerebras',
    description: 'Fastest AI inference, 1M tokens/day free',
    apiKeyUrl: 'https://cloud.cerebras.ai/',
    isFree: true,
    freeNote: '✨ Free — 1M tokens/day',
  ),
  ProviderInfo(
    provider: AIProvider.sambanova,
    name: 'SambaNova',
    description: 'High-performance, free tier available',
    apiKeyUrl: 'https://cloud.sambanova.ai/apis',
    isFree: true,
    freeNote: '✨ Free tier available',
  ),
  ProviderInfo(
    provider: AIProvider.gemini,
    name: 'Gemini',
    description: 'Google AI, free tier available',
    apiKeyUrl: 'https://aistudio.google.com/apikey',
    isFree: true,
    freeNote: '✨ Free tier available',
  ),
  ProviderInfo(
    provider: AIProvider.openai,
    name: 'OpenAI',
    description: 'GPT models, pay-as-you-go',
    apiKeyUrl: 'https://platform.openai.com/api-keys',
    isFree: false,
    freeNote: '💳 Pay-as-you-go',
  ),
  ProviderInfo(
    provider: AIProvider.anthropic,
    name: 'Anthropic',
    description: 'Claude models, pay-as-you-go',
    apiKeyUrl: 'https://console.anthropic.com/settings/keys',
    isFree: false,
    freeNote: '💳 Pay-as-you-go',
  ),
  ProviderInfo(
    provider: AIProvider.deepseek,
    name: 'DeepSeek',
    description: 'Powerful open-weight models, very affordable',
    apiKeyUrl: 'https://platform.deepseek.com/api_keys',
    isFree: false,
    freeNote: '💰 Very affordable',
  ),
];

/// Get provider info by provider enum
ProviderInfo getProviderInfo(AIProvider provider) {
  return providerInfoList.firstWhere((p) => p.provider == provider);
}

/// All available models — Groq first (default), ordered by provider then tier
final List<LLMModel> availableModels = [
  // ══════════════════════════════════════════
  //  GROQ — FREE, Ultra-fast inference
  // ══════════════════════════════════════════
  const LLMModel(
    name: 'Llama 4 Maverick',
    model: 'meta-llama/llama-4-maverick-17b-128e-instruct',
    provider: AIProvider.groq,
    baseUrl: 'https://api.groq.com/openai/v1',
    description: 'Latest & most capable',
    tier: 1,
    isFree: true,
    apiKeyUrl: 'https://console.groq.com/keys',
  ),
  const LLMModel(
    name: 'Llama 4 Scout',
    model: 'meta-llama/llama-4-scout-17b-16e-instruct',
    provider: AIProvider.groq,
    baseUrl: 'https://api.groq.com/openai/v1',
    description: 'Fast & efficient',
    tier: 2,
    isFree: true,
    apiKeyUrl: 'https://console.groq.com/keys',
  ),
  const LLMModel(
    name: 'Llama 3.3 70B',
    model: 'llama-3.3-70b-versatile',
    provider: AIProvider.groq,
    baseUrl: 'https://api.groq.com/openai/v1',
    description: 'Versatile open-source',
    tier: 2,
    isFree: true,
    apiKeyUrl: 'https://console.groq.com/keys',
  ),
  const LLMModel(
    name: 'Gemma 2 9B',
    model: 'gemma2-9b-it',
    provider: AIProvider.groq,
    baseUrl: 'https://api.groq.com/openai/v1',
    description: 'Lightweight & fast',
    tier: 3,
    isFree: true,
    apiKeyUrl: 'https://console.groq.com/keys',
  ),

  // ══════════════════════════════════════════
  //  CEREBRAS — FREE, 1M tokens/day
  // ══════════════════════════════════════════
  const LLMModel(
    name: 'Qwen3 235B',
    model: 'qwen-3-235b',
    provider: AIProvider.cerebras,
    baseUrl: 'https://api.cerebras.ai/v1',
    description: 'Most capable, 235B params',
    tier: 1,
    isFree: true,
    apiKeyUrl: 'https://cloud.cerebras.ai/',
  ),
  const LLMModel(
    name: 'Llama 3.3 70B',
    model: 'llama-3.3-70b',
    provider: AIProvider.cerebras,
    baseUrl: 'https://api.cerebras.ai/v1',
    description: 'Fast open-source via Cerebras',
    tier: 2,
    isFree: true,
    apiKeyUrl: 'https://cloud.cerebras.ai/',
  ),

  // ══════════════════════════════════════════
  //  SAMBANOVA — FREE tier
  // ══════════════════════════════════════════
  const LLMModel(
    name: 'Llama 3.3 70B',
    model: 'Meta-Llama-3.3-70B-Instruct',
    provider: AIProvider.sambanova,
    baseUrl: 'https://api.sambanova.ai/v1',
    description: 'High-performance inference',
    tier: 1,
    isFree: true,
    apiKeyUrl: 'https://cloud.sambanova.ai/apis',
  ),
  const LLMModel(
    name: 'DeepSeek V3',
    model: 'DeepSeek-V3-0324',
    provider: AIProvider.sambanova,
    baseUrl: 'https://api.sambanova.ai/v1',
    description: 'DeepSeek via SambaNova',
    tier: 2,
    isFree: true,
    apiKeyUrl: 'https://cloud.sambanova.ai/apis',
  ),

  // ══════════════════════════════════════════
  //  GEMINI — Free tier available
  // ══════════════════════════════════════════
  const LLMModel(
    name: 'Gemini 3.1 Pro',
    model: 'gemini-3.1-pro',
    provider: AIProvider.gemini,
    baseUrl: 'https://generativelanguage.googleapis.com',
    description: 'Latest & most capable',
    tier: 1,
    isFree: true,
    apiKeyUrl: 'https://aistudio.google.com/apikey',
  ),
  const LLMModel(
    name: 'Gemini 2.5 Pro',
    model: 'gemini-2.5-pro-preview-05-06',
    provider: AIProvider.gemini,
    baseUrl: 'https://generativelanguage.googleapis.com',
    description: 'Advanced reasoning',
    tier: 1,
    isFree: true,
    apiKeyUrl: 'https://aistudio.google.com/apikey',
  ),
  const LLMModel(
    name: 'Gemini 2.5 Flash',
    model: 'gemini-2.5-flash-preview-05-20',
    provider: AIProvider.gemini,
    baseUrl: 'https://generativelanguage.googleapis.com',
    description: 'Fast & efficient',
    tier: 2,
    isFree: true,
    apiKeyUrl: 'https://aistudio.google.com/apikey',
  ),
  const LLMModel(
    name: 'Gemini 2.0 Flash',
    model: 'gemini-2.0-flash',
    provider: AIProvider.gemini,
    baseUrl: 'https://generativelanguage.googleapis.com',
    description: 'Stable & reliable',
    tier: 3,
    isFree: true,
    apiKeyUrl: 'https://aistudio.google.com/apikey',
  ),

  // ══════════════════════════════════════════
  //  OPENAI — Pay-as-you-go
  // ══════════════════════════════════════════
  const LLMModel(
    name: 'GPT-5.3',
    model: 'gpt-5.3',
    provider: AIProvider.openai,
    baseUrl: 'https://api.openai.com/v1',
    description: 'Most capable OpenAI model',
    tier: 1,
    apiKeyUrl: 'https://platform.openai.com/api-keys',
  ),
  const LLMModel(
    name: 'GPT-4.1',
    model: 'gpt-4.1',
    provider: AIProvider.openai,
    baseUrl: 'https://api.openai.com/v1',
    description: 'Advanced reasoning',
    tier: 1,
    apiKeyUrl: 'https://platform.openai.com/api-keys',
  ),
  const LLMModel(
    name: 'GPT-4.1 Mini',
    model: 'gpt-4.1-mini',
    provider: AIProvider.openai,
    baseUrl: 'https://api.openai.com/v1',
    description: 'Fast & affordable',
    tier: 2,
    apiKeyUrl: 'https://platform.openai.com/api-keys',
  ),
  const LLMModel(
    name: 'GPT-4o',
    model: 'gpt-4o',
    provider: AIProvider.openai,
    baseUrl: 'https://api.openai.com/v1',
    description: 'Multimodal flagship',
    tier: 2,
    apiKeyUrl: 'https://platform.openai.com/api-keys',
  ),
  const LLMModel(
    name: 'GPT-4o Mini',
    model: 'gpt-4o-mini',
    provider: AIProvider.openai,
    baseUrl: 'https://api.openai.com/v1',
    description: 'Budget-friendly',
    tier: 3,
    apiKeyUrl: 'https://platform.openai.com/api-keys',
  ),

  // ══════════════════════════════════════════
  //  ANTHROPIC — Pay-as-you-go
  // ══════════════════════════════════════════
  const LLMModel(
    name: 'Claude Opus 4',
    model: 'claude-opus-4-20250514',
    provider: AIProvider.anthropic,
    baseUrl: 'https://api.anthropic.com/v1',
    description: 'Most powerful Claude',
    tier: 1,
    apiKeyUrl: 'https://console.anthropic.com/settings/keys',
  ),
  const LLMModel(
    name: 'Claude Sonnet 4',
    model: 'claude-sonnet-4-20250514',
    provider: AIProvider.anthropic,
    baseUrl: 'https://api.anthropic.com/v1',
    description: 'Best balance of speed & quality',
    tier: 2,
    apiKeyUrl: 'https://console.anthropic.com/settings/keys',
  ),
  const LLMModel(
    name: 'Claude Haiku 3.5',
    model: 'claude-3-5-haiku-20241022',
    provider: AIProvider.anthropic,
    baseUrl: 'https://api.anthropic.com/v1',
    description: 'Fastest Claude model',
    tier: 3,
    apiKeyUrl: 'https://console.anthropic.com/settings/keys',
  ),

  // ══════════════════════════════════════════
  //  DEEPSEEK — Very affordable
  // ══════════════════════════════════════════
  const LLMModel(
    name: 'DeepSeek Chat',
    model: 'deepseek-chat',
    provider: AIProvider.deepseek,
    baseUrl: 'https://api.deepseek.com/v1',
    description: 'Powerful open-weight model',
    tier: 1,
    apiKeyUrl: 'https://platform.deepseek.com/api_keys',
  ),
  const LLMModel(
    name: 'DeepSeek Reasoner',
    model: 'deepseek-reasoner',
    provider: AIProvider.deepseek,
    baseUrl: 'https://api.deepseek.com/v1',
    description: 'Advanced reasoning',
    tier: 2,
    apiKeyUrl: 'https://platform.deepseek.com/api_keys',
  ),
];

/// Get all models for a specific provider
List<LLMModel> getModelsForProvider(AIProvider provider) {
  return availableModels.where((m) => m.provider == provider).toList();
}

/// Get fallback models (same provider, lower or equal tier, sorted by tier)
List<LLMModel> getFallbackModels(LLMModel current) {
  return availableModels
      .where((m) =>
          m.provider == current.provider &&
          m.model != current.model &&
          m.tier >= current.tier)
      .toList()
    ..sort((a, b) => a.tier.compareTo(b.tier));
}

/// Get fallback models across ALL providers that have API keys
List<LLMModel> getCrossProviderFallbacks(
    LLMModel current, Map<String, String> apiKeys) {
  return availableModels
      .where((m) =>
          m.model != current.model &&
          apiKeys.containsKey(m.providerKey) &&
          apiKeys[m.providerKey]!.isNotEmpty)
      .toList()
    ..sort((a, b) => a.tier.compareTo(b.tier));
}
