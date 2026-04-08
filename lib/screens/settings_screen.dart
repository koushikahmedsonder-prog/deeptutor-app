import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../utils/theme_helper.dart';
import '../config/models_config.dart';
import '../providers/settings_provider.dart';
import '../providers/api_provider.dart';
import '../services/image_fetch_service.dart';



class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // One controller per provider
  final Map<String, TextEditingController> _keyControllers = {};
  final Map<String, bool> _showKey = {};

  // Google CSE controllers
  late TextEditingController _googleApiKeyController;
  late TextEditingController _googleCseIdController;
  bool _showGoogleKey = false;

  bool _isTestingKey = false;
  bool? _keyValid;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _googleApiKeyController = TextEditingController();
    _googleCseIdController = TextEditingController();

    // Initialize a controller for each provider
    for (final provider in AIProvider.values) {
      _keyControllers[provider.name] = TextEditingController();
      _showKey[provider.name] = false;
    }

    // Load saved keys into controllers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadKeys();
    });
  }

  void _loadKeys() {
    final settings = ref.read(settingsProvider);
    for (final provider in AIProvider.values) {
      final savedKey = settings.apiKeys[provider.name] ?? '';
      _keyControllers[provider.name]?.text = savedKey;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    _googleApiKeyController.text = prefs.getString('google_cse_api_key') ?? '';
    _googleCseIdController.text = prefs.getString('google_cse_id') ?? '';
  }

  @override
  void dispose() {
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    _googleApiKeyController.dispose();
    _googleCseIdController.dispose();
    super.dispose();
  }

  Future<void> _testApiKey() async {
    setState(() {
      _isTestingKey = true;
      _keyValid = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final currentProvider = ref.read(settingsProvider).selectedModel.providerKey;
      final newKey = _keyControllers[currentProvider]?.text.trim() ?? '';
      if (newKey.isNotEmpty) {
        api.updateApiKey(newKey);
      }
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

  Future<void> _saveAllKeys() async {
    final keys = <String, String>{};
    for (final provider in AIProvider.values) {
      final key = _keyControllers[provider.name]?.text.trim() ?? '';
      if (key.isNotEmpty) {
        keys[provider.name] = key;
      }
    }

    await ref.read(settingsProvider.notifier).saveAllApiKeys(keys);
    setState(() => _hasUnsavedChanges = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 18),
              SizedBox(width: 8),
              Text('${keys.length} API key${keys.length == 1 ? '' : 's'} saved! 🎉'),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Color _providerColor(AIProvider provider) {
    return switch (provider) {
      AIProvider.groq => const Color(0xFFF55036),
      AIProvider.cerebras => const Color(0xFF00B4D8),
      AIProvider.sambanova => const Color(0xFFFF6B35),
      AIProvider.gemini => const Color(0xFF4285F4),
      AIProvider.openai => const Color(0xFF10A37F),
      AIProvider.anthropic => const Color(0xFFD97757),
      AIProvider.deepseek => const Color(0xFF536DFE),
    };
  }

  IconData _providerIcon(AIProvider provider) {
    return switch (provider) {
      AIProvider.groq => Icons.bolt_rounded,
      AIProvider.cerebras => Icons.memory_rounded,
      AIProvider.sambanova => Icons.speed_rounded,
      AIProvider.gemini => Icons.diamond_rounded,
      AIProvider.openai => Icons.auto_awesome_rounded,
      AIProvider.anthropic => Icons.psychology_rounded,
      AIProvider.deepseek => Icons.explore_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final selectedModel = settings.selectedModel;

    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Active Model Indicator ──
          _buildActiveModelCard(selectedModel, settings),

          SizedBox(height: 24),

          // ── API Keys Section (All Providers) ──
          _SectionTitle(title: '🔑 API Keys', index: 0),
          SizedBox(height: 4),
          Text(
            'Add your API keys below. Free providers are marked — no credit card needed!',
            style: TextStyle(color: context.textTer, fontSize: 13),
          ),
          SizedBox(height: 12),

          ..._buildApiKeyCards(settings),

          // Save All Button
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saveAllKeys,
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasUnsavedChanges
                    ? AppTheme.accentGreen
                    : AppTheme.accentIndigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(
                _hasUnsavedChanges ? Icons.save_rounded : Icons.check_circle_rounded,
                size: 20,
              ),
              label: Text(
                _hasUnsavedChanges ? 'Save All API Keys' : 'All Keys Saved ✓',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

          SizedBox(height: 24),

          // ── Auto-Fallback Toggle ──
          _buildAutoFallbackCard(settings),

          SizedBox(height: 24),

          // ── Google Custom Search Section ──
          _SectionTitle(title: '🖼️ Visual Assets (Google CSE)', index: 1),
          SizedBox(height: 4),
          Text(
            'Enables [FETCH_IMAGE] tag resolution for dynamic AI visuals.',
            style: TextStyle(color: context.textTer, fontSize: 13),
          ),
          SizedBox(height: 12),
          _buildGoogleCseCard(),

          SizedBox(height: 24),

          // ── Model Selection ──
          _SectionTitle(title: '🤖 Choose Model', index: 2),
          SizedBox(height: 4),
          Text(
            'Select your AI model. ${settings.configuredProviderCount} provider${settings.configuredProviderCount == 1 ? '' : 's'} configured.',
            style: TextStyle(color: context.textTer, fontSize: 13),
          ),
          SizedBox(height: 12),

          ..._buildModelGroups(settings),

          SizedBox(height: 32),

          // App info
          Center(
            child: Column(
              children: [
                Text(
                  'DeepTutor',
                  style: TextStyle(
                    color: context.textTer,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'v2.0.0 • Multi-Provider AI Learning',
                  style: TextStyle(
                    color: context.textTer.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Active Model Card ──
  Widget _buildActiveModelCard(LLMModel selectedModel, SettingsState settings) {
    final color = _providerColor(selectedModel.provider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            context.surfaceColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_providerIcon(selectedModel.provider), color: color, size: 24),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Active Model',
                      style: TextStyle(color: context.textTer, fontSize: 12),
                    ),
                    if (selectedModel.isFree)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'FREE',
                          style: TextStyle(color: AppTheme.accentGreen, fontSize: 9, fontWeight: FontWeight.w700),
                        ),
                      ),
                    if (settings.autoFallback)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '🔄 Auto-fallback',
                          style: TextStyle(color: AppTheme.accentCyan, fontSize: 9, fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (settings.isConnected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
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
                SizedBox(height: 4),
                Text(
                  selectedModel.name,
                  style: TextStyle(
                    color: context.textPri,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${selectedModel.providerName} • ${selectedModel.model}',
                  style: TextStyle(color: context.textSec, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  // ── Auto-Fallback Card ──
  Widget _buildAutoFallbackCard(SettingsState settings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: settings.autoFallback
              ? AppTheme.accentCyan.withValues(alpha: 0.3)
              : context.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.auto_mode_rounded, color: AppTheme.accentCyan, size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-Fallback',
                  style: TextStyle(
                    color: context.textPri,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  settings.autoFallback
                      ? 'If tokens run out, auto-switches to a lower model'
                      : 'Will show error when model limit is reached',
                  style: TextStyle(color: context.textTer, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: settings.autoFallback,
            onChanged: (v) => ref.read(settingsProvider.notifier).setAutoFallback(v),
            activeColor: AppTheme.accentCyan,
          ),
        ],
      ),
    ).animate(delay: 250.ms).fadeIn(duration: 400.ms);
  }

  // ── API Key Cards — one per provider ──
  List<Widget> _buildApiKeyCards(SettingsState settings) {
    final widgets = <Widget>[];
    int delay = 100;

    for (final pInfo in providerInfoList) {
      final provider = pInfo.provider;
      final color = _providerColor(provider);
      final hasKey = (settings.apiKeys[provider.name]?.isNotEmpty ?? false) ||
          (_keyControllers[provider.name]?.text.trim().isNotEmpty ?? false);
      final isCurrentProvider = settings.selectedModel.provider == provider;

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrentProvider
                  ? color.withValues(alpha: 0.5)
                  : hasKey
                      ? AppTheme.accentGreen.withValues(alpha: 0.3)
                      : context.cardBorder,
              width: isCurrentProvider ? 1.5 : 1,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_providerIcon(provider), color: color, size: 20),
              ),
              title: Row(
                children: [
                  Text(
                    pInfo.name,
                    style: TextStyle(
                      color: context.textPri,
                      fontSize: 15,
                      fontWeight: isCurrentProvider ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 8),
                  if (pInfo.isFree)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'FREE',
                        style: TextStyle(
                          color: AppTheme.accentGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (hasKey)
                    Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 16),
                ],
              ),
              subtitle: Text(
                pInfo.description,
                style: TextStyle(color: context.textTer, fontSize: 11),
              ),
              children: [
                // API Key field
                TextField(
                  controller: _keyControllers[provider.name],
                  obscureText: !(_showKey[provider.name] ?? false),
                  style: TextStyle(
                    color: context.textPri,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  onChanged: (_) => setState(() => _hasUnsavedChanges = true),
                  decoration: InputDecoration(
                    hintText: LLMModel(
                      name: '', model: '', provider: provider,
                      baseUrl: '',
                    ).apiKeyHint,
                    labelText: '${pInfo.name} API Key',
                    labelStyle: TextStyle(color: context.textTer, fontSize: 13),
                    suffixIcon: IconButton(
                      icon: Icon(
                        (_showKey[provider.name] ?? false)
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: context.textTer,
                        size: 18,
                      ),
                      onPressed: () => setState(() {
                        _showKey[provider.name] = !(_showKey[provider.name] ?? false);
                      }),
                    ),
                  ),
                ),
                SizedBox(height: 10),

                // Actions row — Get Key + Test (if current provider)
                Row(
                  children: [
                    // Get Key button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openUrl(pInfo.apiKeyUrl),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: color.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: Icon(Icons.open_in_new_rounded, size: 15, color: color),
                        label: Text(
                          'Get Key →',
                          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    if (isCurrentProvider) ...[
                      SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTestingKey ? null : _testApiKey,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: context.cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: _isTestingKey
                              ? SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(Icons.wifi_find_rounded, size: 15),
                          label: Text(
                            _keyValid == true ? 'Valid ✓' : 'Test Key',
                            style: TextStyle(
                              fontSize: 13,
                              color: _keyValid == true ? AppTheme.accentGreen : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (pInfo.isFree) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.accentGreen),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            pInfo.freeNote,
                            style: TextStyle(color: AppTheme.accentGreen, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ).animate(delay: Duration(milliseconds: delay)).fadeIn(duration: 400.ms),
      );
      delay += 50;
    }

    return widgets;
  }

  // ── Google CSE Card ──
  Widget _buildGoogleCseCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        children: [
          TextField(
            controller: _googleApiKeyController,
            obscureText: !_showGoogleKey,
            style: TextStyle(color: context.textPri, fontFamily: 'monospace', fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Google API Key',
              labelStyle: TextStyle(color: context.textTer),
              suffixIcon: IconButton(
                icon: Icon(_showGoogleKey ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: context.textTer, size: 20),
                onPressed: () => setState(() => _showGoogleKey = !_showGoogleKey),
              ),
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _googleCseIdController,
            style: TextStyle(color: context.textPri, fontFamily: 'monospace', fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Custom Search Engine ID',
              labelStyle: TextStyle(color: context.textTer),
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final apiKey = _googleApiKeyController.text.trim();
                final cseId = _googleCseIdController.text.trim();
                final prefs = ref.read(sharedPreferencesProvider);
                await prefs.setString('google_cse_api_key', apiKey);
                await prefs.setString('google_cse_id', cseId);
                ImageFetchService().updateKeys(apiKey: apiKey, cseId: cseId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🖼️ Image Search keys saved')),
                  );
                }
              },
              icon: Icon(Icons.save_rounded, size: 18),
              label: Text('Save Google Keys'),
            ),
          ),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn(duration: 400.ms);
  }

  // ── Model Groups ──
  List<Widget> _buildModelGroups(SettingsState settings) {
    final widgets = <Widget>[];
    AIProvider? lastProvider;

    for (int i = 0; i < availableModels.length; i++) {
      final model = availableModels[i];
      final isSelected = settings.selectedModelIndex == i;
      final hasKey = settings.hasKeyForProvider(model.provider);

      // Provider header
      if (model.provider != lastProvider) {
        lastProvider = model.provider;
        final color = _providerColor(model.provider);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4),
            child: Row(
              children: [
                Icon(_providerIcon(model.provider), size: 16, color: color),
                SizedBox(width: 6),
                Text(
                  model.providerName,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!hasKey) ...[
                  SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'No key',
                      style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
                if (model.isFree) ...[
                  SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'FREE',
                      style: TextStyle(color: AppTheme.accentGreen, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }

      final color = _providerColor(model.provider);
      final tierIcon = switch (model.tier) {
        1 => '⭐',
        2 => '🔥',
        _ => '💨',
      };

      widgets.add(
        Opacity(
          opacity: hasKey ? 1.0 : 0.5,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.1)
                  : context.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.5)
                    : context.cardBorder,
              ),
            ),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.2)
                      : context.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _providerIcon(model.provider),
                  color: isSelected ? color : context.textTer,
                  size: 18,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      model.name,
                      style: TextStyle(
                        color: isSelected ? context.textPri : context.textSec,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(tierIcon, style: TextStyle(fontSize: 12)),
                ],
              ),
              subtitle: Text(
                '${model.model} ${model.description.isNotEmpty ? "• ${model.description}" : ""}',
                style: TextStyle(color: context.textTer, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: isSelected
                  ? Icon(Icons.check_rounded, color: color, size: 20)
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setModel(i);
                setState(() => _keyValid = null);
              },
            ),
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
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: context.textPri,
      ),
    ).animate(delay: (index * 100).ms).fadeIn(duration: 400.ms);
  }
}
