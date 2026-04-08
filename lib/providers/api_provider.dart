import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/interactive_answer_engine.dart';
import '../services/document_service.dart';
import 'settings_provider.dart';

// ── API Service Provider (Multi-model, Multi-key) ──
final apiServiceProvider = Provider<ApiService>((ref) {
  final settings = ref.watch(settingsProvider);
  return ApiService(
    apiKeys: settings.apiKeys,
    model: settings.selectedModel,
    autoFallback: settings.autoFallback,
    preferredLanguage: settings.preferredLanguage,
  );
});

// ── Document Service Provider ──
final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService();
});


// ── Interactive Answer Engine Provider ──
final interactiveAnswerEngineProvider = Provider<InteractiveAnswerEngine>((ref) {
  final api = ref.watch(apiServiceProvider);
  return InteractiveAnswerEngine(api);
});
