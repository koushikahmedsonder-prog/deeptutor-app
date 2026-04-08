import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/models_config.dart';
import '../services/storage_service.dart';

// ── Settings State ──
class SettingsState {
  final int selectedModelIndex;
  final Map<String, String> apiKeys; // keyed by provider name: {'groq': 'gsk_...', 'gemini': 'AIza...'}
  final bool isConnected;
  final bool isDarkMode;
  final bool autoFallback; // auto-switch to lower model on token exhaustion
  final String preferredLanguage;

  const SettingsState({
    this.selectedModelIndex = 0,
    this.apiKeys = const {},
    this.isConnected = false,
    this.isDarkMode = false,
    this.autoFallback = true,
    this.preferredLanguage = 'English',
  });

  LLMModel get selectedModel =>
      availableModels[selectedModelIndex.clamp(0, availableModels.length - 1)];

  /// Get API key for the currently selected provider
  String get apiKey => apiKeys[selectedModel.providerKey] ?? '';

  /// Get API key for a specific provider
  String getApiKeyForProvider(AIProvider provider) {
    return apiKeys[provider.name] ?? '';
  }

  /// Check if a provider has an API key configured
  bool hasKeyForProvider(AIProvider provider) {
    final key = apiKeys[provider.name];
    return key != null && key.isNotEmpty;
  }

  /// Count of configured providers
  int get configuredProviderCount =>
      apiKeys.values.where((k) => k.isNotEmpty).length;

  SettingsState copyWith({
    int? selectedModelIndex,
    Map<String, String>? apiKeys,
    bool? isConnected,
    bool? isDarkMode,
    bool? autoFallback,
    String? preferredLanguage,
  }) {
    return SettingsState(
      selectedModelIndex: selectedModelIndex ?? this.selectedModelIndex,
      apiKeys: apiKeys ?? this.apiKeys,
      isConnected: isConnected ?? this.isConnected,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      autoFallback: autoFallback ?? this.autoFallback,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }
}

// ── Settings Notifier ──
class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    // Load settings SYNCHRONOUSLY from SharedPreferences (already initialized)
    final prefs = ref.read(sharedPreferencesProvider);
    
    final modelIndex = prefs.getInt('model_index') ?? 0;
    final isDarkMode = prefs.getBool('dark_mode') ?? false;
    final autoFallback = prefs.getBool('auto_fallback') ?? true;
    final clampedIndex = modelIndex.clamp(0, availableModels.length - 1);
    final prefLang = StorageService.getPreferredLanguage();

    // Load API keys SYNCHRONOUSLY from SharedPreferences
    final Map<String, String> allKeys = {};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('api_key_')) {
        final val = prefs.getString(key);
        if (val != null && val.isNotEmpty) {
          allKeys[key.replaceFirst('api_key_', '')] = val;
        }
      }
    }

    final selectedModel = availableModels[clampedIndex];
    final currentKey = allKeys[selectedModel.providerKey] ?? '';

    // Run async Hive migration in background (merges old Hive keys into SharedPreferences)
    _migrateFromHive(prefs);

    return SettingsState(
      selectedModelIndex: clampedIndex,
      apiKeys: allKeys,
      isDarkMode: isDarkMode,
      autoFallback: autoFallback,
      isConnected: currentKey.isNotEmpty,
      preferredLanguage: prefLang,
    );
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  /// One-time migration: copy any keys that exist in Hive but not in SharedPreferences
  Future<void> _migrateFromHive(SharedPreferences prefs) async {
    try {
      final hiveKeys = await StorageService.getAllApiKeys();
      bool changed = false;
      final currentKeys = Map<String, String>.from(state.apiKeys);
      
      for (final entry in hiveKeys.entries) {
        if (!currentKeys.containsKey(entry.key) || (currentKeys[entry.key]?.isEmpty ?? true)) {
          if (entry.value.isNotEmpty) {
            currentKeys[entry.key] = entry.value;
            await prefs.setString('api_key_${entry.key}', entry.value);
            changed = true;
          }
        }
      }

      if (changed) {
        final selectedModel = state.selectedModel;
        final currentKey = currentKeys[selectedModel.providerKey] ?? '';
        state = state.copyWith(
          apiKeys: currentKeys,
          isConnected: currentKey.isNotEmpty,
        );
      }
    } catch (e) {
      print('Hive migration (non-critical): $e');
    }
  }

  /// Set API key for a specific provider
  Future<void> setProviderApiKey(AIProvider provider, String key) async {
    // Save to both SharedPreferences (primary) and StorageService (backup)
    await _prefs.setString('api_key_${provider.name}', key);
    await StorageService.saveApiKey(provider.name, key);
    final newKeys = Map<String, String>.from(state.apiKeys);
    newKeys[provider.name] = key;
    state = state.copyWith(
      apiKeys: newKeys,
      isConnected: newKeys[state.selectedModel.providerKey]?.isNotEmpty ?? false,
    );
  }

  /// Save ALL api keys at once
  Future<void> saveAllApiKeys(Map<String, String> keys) async {
    for (final entry in keys.entries) {
      if (entry.value.isNotEmpty) {
        // Write directly to SharedPreferences for guaranteed persistence
        await _prefs.setString('api_key_${entry.key}', entry.value);
        await StorageService.saveApiKey(entry.key, entry.value);
      }
    }
    final currentKey = keys[state.selectedModel.providerKey] ?? state.apiKey;
    state = state.copyWith(
      apiKeys: keys,
      isConnected: currentKey.isNotEmpty,
    );
  }

  Future<void> setModel(int index) async {
    await _prefs.setInt('model_index', index);
    final newModel = availableModels[index.clamp(0, availableModels.length - 1)];
    final hasKey = state.apiKeys[newModel.providerKey]?.isNotEmpty ?? false;
    state = state.copyWith(
      selectedModelIndex: index,
      isConnected: hasKey,
    );
  }

  /// Legacy setter — saves under current provider
  Future<void> setApiKey(String key) async {
    await setProviderApiKey(state.selectedModel.provider, key);
  }

  void setConnected(bool connected) {
    state = state.copyWith(isConnected: connected);
  }

  Future<void> setAutoFallback(bool enabled) async {
    await _prefs.setBool('auto_fallback', enabled);
    state = state.copyWith(autoFallback: enabled);
  }

  Future<void> toggleDarkMode() async {
    final newVal = !state.isDarkMode;
    await _prefs.setBool('dark_mode', newVal);
    state = state.copyWith(isDarkMode: newVal);
  }

  Future<void> setPreferredLanguage(String lang) async {
    await StorageService.savePreferredLanguage(lang);
    state = state.copyWith(preferredLanguage: lang);
  }
}

// ── Providers ──
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden at startup');
});

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
