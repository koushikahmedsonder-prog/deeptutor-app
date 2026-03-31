import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/app_theme.dart';
import '../config/models_config.dart';
import '../providers/settings_provider.dart';
import '../providers/api_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _apiKeyController;
  bool _isTestingKey = false;
  bool? _keyValid;
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _apiKeyController = TextEditingController(text: settings.apiKey);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _testApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() => _keyValid = false);
      return;
    }

    setState(() {
      _isTestingKey = true;
      _keyValid = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      api.updateApiKey(key);
      final response = await api.testConnection();
      setState(() {
        _keyValid = response.isNotEmpty;
        _isTestingKey = false;
      });
      ref.read(settingsProvider.notifier).setConnected(response.isNotEmpty);
    } catch (e) {
      setState(() {
        _keyValid = false;
        _isTestingKey = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e')),
        );
      }
    }
  }

  Color _providerColor(AIProvider provider) {
    return switch (provider) {
      AIProvider.gemini => const Color(0xFF4285F4),
      AIProvider.openai => const Color(0xFF10A37F),
      AIProvider.anthropic => const Color(0xFFD97757),
      AIProvider.deepseek => const Color(0xFF536DFE),
      AIProvider.groq => const Color(0xFFF55036),
    };
  }

  IconData _providerIcon(AIProvider provider) {
    return switch (provider) {
      AIProvider.gemini => Icons.diamond_rounded,
      AIProvider.openai => Icons.auto_awesome_rounded,
      AIProvider.anthropic => Icons.psychology_rounded,
      AIProvider.deepseek => Icons.explore_rounded,
      AIProvider.groq => Icons.bolt_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final selectedModel = settings.selectedModel;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Active Model indicator ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _providerColor(selectedModel.provider).withValues(alpha: 0.15),
                  AppTheme.cardDark,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _providerColor(selectedModel.provider).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _providerColor(selectedModel.provider).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _providerIcon(selectedModel.provider),
                    color: _providerColor(selectedModel.provider),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Model',
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedModel.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${selectedModel.providerName} • ${selectedModel.model}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (settings.isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.accentGreen),
                        SizedBox(width: 4),
                        Text('Ready', style: TextStyle(color: AppTheme.accentGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // ── API Key Section ──
          _SectionTitle(title: 'API Key', index: 0),
          const SizedBox(height: 4),
          Text(
            'Enter your ${selectedModel.providerName} API key',
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _apiKeyController,
                  obscureText: !_showApiKey,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: selectedModel.apiKeyHint,
                    labelText: '${selectedModel.providerName} API Key',
                    labelStyle: const TextStyle(color: AppTheme.textTertiary),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _showApiKey
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: AppTheme.textTertiary,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _showApiKey = !_showApiKey),
                        ),
                        if (_keyValid != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              _keyValid!
                                  ? Icons.check_circle_rounded
                                  : Icons.error_rounded,
                              color: _keyValid!
                                  ? AppTheme.accentGreen
                                  : Colors.red,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isTestingKey ? null : _testApiKey,
                        icon: _isTestingKey
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_find_rounded, size: 18),
                        label: const Text('Test Key'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.cardBorder),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final key = _apiKeyController.text.trim();
                          ref
                              .read(settingsProvider.notifier)
                              .setApiKey(key);
                          setState(() => _keyValid = null);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('🔑 API Key saved')),
                          );
                        },
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),
                if (_keyValid != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _keyValid!
                          ? AppTheme.accentGreen.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _keyValid!
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          size: 16,
                          color:
                              _keyValid! ? AppTheme.accentGreen : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _keyValid!
                                ? '${selectedModel.providerName} API key is valid! AI features ready.'
                                : 'Invalid key for ${selectedModel.providerName}. Check your key.',
                            style: TextStyle(
                              fontSize: 13,
                              color: _keyValid!
                                  ? AppTheme.accentGreen
                                  : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // ── Model Selection (grouped by provider) ──
          _SectionTitle(title: 'Choose Model', index: 1),
          const SizedBox(height: 4),
          const Text(
            'Select the AI provider and model to use',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
          ),
          const SizedBox(height: 12),

          // Group models by provider
          ..._buildModelGroups(settings),

          const SizedBox(height: 24),

          // ── Quick Setup Guide ──
          _SectionTitle(title: 'Getting API Keys', index: 2),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentIndigo.withValues(alpha: 0.05),
                  AppTheme.accentCyan.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.accentIndigo.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ApiKeyGuideItem(
                  provider: 'Gemini',
                  url: 'ai.google.dev',
                  color: const Color(0xFF4285F4),
                  freeNote: 'Free tier available',
                ),
                const Divider(color: AppTheme.cardBorder, height: 20),
                _ApiKeyGuideItem(
                  provider: 'OpenAI',
                  url: 'platform.openai.com',
                  color: const Color(0xFF10A37F),
                  freeNote: 'Pay-as-you-go',
                ),
                const Divider(color: AppTheme.cardBorder, height: 20),
                _ApiKeyGuideItem(
                  provider: 'Anthropic',
                  url: 'console.anthropic.com',
                  color: const Color(0xFFD97757),
                  freeNote: 'Pay-as-you-go',
                ),
                const Divider(color: AppTheme.cardBorder, height: 20),
                _ApiKeyGuideItem(
                  provider: 'DeepSeek',
                  url: 'platform.deepseek.com',
                  color: const Color(0xFF536DFE),
                  freeNote: 'Very affordable',
                ),
                const Divider(color: AppTheme.cardBorder, height: 20),
                _ApiKeyGuideItem(
                  provider: 'Groq',
                  url: 'console.groq.com',
                  color: const Color(0xFFF55036),
                  freeNote: 'Free tier available',
                ),
              ],
            ),
          ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 32),

          // App info
          Center(
            child: Column(
              children: [
                const Text(
                  'DeepTutor',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v1.1.0 • Multi-model AI Learning',
                  style: TextStyle(
                    color: AppTheme.textTertiary.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _buildModelGroups(SettingsState settings) {
    final widgets = <Widget>[];
    AIProvider? lastProvider;

    for (int i = 0; i < availableModels.length; i++) {
      final model = availableModels[i];
      final isSelected = settings.selectedModelIndex == i;

      // Provider header
      if (model.provider != lastProvider) {
        lastProvider = model.provider;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6, left: 4),
            child: Row(
              children: [
                Icon(
                  _providerIcon(model.provider),
                  size: 16,
                  color: _providerColor(model.provider),
                ),
                const SizedBox(width: 6),
                Text(
                  model.providerName,
                  style: TextStyle(
                    color: _providerColor(model.provider),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final color = _providerColor(model.provider);

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.1)
                : AppTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.5)
                  : AppTheme.cardBorder,
            ),
          ),
          child: ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.2)
                    : AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _providerIcon(model.provider),
                color: isSelected ? color : AppTheme.textTertiary,
                size: 18,
              ),
            ),
            title: Text(
              model.name,
              style: TextStyle(
                color: isSelected
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${model.model} ${model.description.isNotEmpty ? "• ${model.description}" : ""}',
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check_rounded, color: color, size: 20)
                : null,
            onTap: () {
              ref.read(settingsProvider.notifier).setModel(i);
              // Reset key validation when changing provider
              setState(() => _keyValid = null);
            },
          ),
        ),
      );
    }

    return widgets;
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int index;

  const _SectionTitle({required this.title, required this.index});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    ).animate(delay: (index * 100).ms).fadeIn(duration: 400.ms);
  }
}

class _ApiKeyGuideItem extends StatelessWidget {
  final String provider;
  final String url;
  final Color color;
  final String freeNote;

  const _ApiKeyGuideItem({
    required this.provider,
    required this.url,
    required this.color,
    required this.freeNote,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13),
              children: [
                TextSpan(
                  text: '$provider: ',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: url,
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            freeNote,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
