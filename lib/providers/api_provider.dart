import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/document_service.dart';
import 'settings_provider.dart';

// ── API Service Provider (Multi-model) ──
final apiServiceProvider = Provider<ApiService>((ref) {
  final settings = ref.watch(settingsProvider);
  return ApiService(
    apiKey: settings.apiKey,
    model: settings.selectedModel,
  );
});

// ── Document Service Provider ──
final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService();
});
