import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/models_config.dart';
import '../services/storage_service.dart';
// ── Settings State ──
class SettingsState {
  final int selectedModelIndex;
  final String apiKey;
  final bool isConnected;
  final bool isDarkMode;

  const SettingsState({
    this.selectedModelIndex = 0,
    this.apiKey = '',
    this.isConnected = false,
    this.isDarkMode = true,
  });

  LLMModel get selectedModel =>
      availableModels[selectedModelIndex.clamp(0, availableModels.length - 1)];

  SettingsState copyWith({
    int? selectedModelIndex,
    String? apiKey,
    bool? isConnected,
    bool? isDarkMode,
  }) {
    return SettingsState(
      selectedModelIndex: selectedModelIndex ?? this.selectedModelIndex,
      apiKey: apiKey ?? this.apiKey,
      isConnected: isConnected ?? this.isConnected,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }
}

// ── Settings Notifier ──
class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _loadSettings();
    return const SettingsState();
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Future<void> _loadSettings() async {
    final modelIndex = _prefs.getInt('model_index') ?? 0;
    final apiKey = await StorageService.getApiKey('openai') ?? '';
    final isDarkMode = _prefs.getBool('dark_mode') ?? true;

    state = state.copyWith(
      selectedModelIndex: modelIndex.clamp(0, availableModels.length - 1),
      apiKey: apiKey,
      isDarkMode: isDarkMode,
      isConnected: apiKey.isNotEmpty,
    );
  }

  Future<void> setModel(int index) async {
    await _prefs.setInt('model_index', index);
    state = state.copyWith(selectedModelIndex: index);
  }

  Future<void> setApiKey(String key) async {
    await StorageService.saveApiKey('openai', key);
    state = state.copyWith(apiKey: key, isConnected: key.isNotEmpty);
  }

  void setConnected(bool connected) {
    state = state.copyWith(isConnected: connected);
  }

  Future<void> toggleDarkMode() async {
    final newVal = !state.isDarkMode;
    await _prefs.setBool('dark_mode', newVal);
    state = state.copyWith(isDarkMode: newVal);
  }
}

// ── Providers ──
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden at startup');
});

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
