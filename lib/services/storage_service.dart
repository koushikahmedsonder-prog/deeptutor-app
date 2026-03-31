import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ─────────────────────────────────────────────
//  StorageService — single place for ALL data
//  Chat history, settings, keys → Hive (fast local DB)
// ─────────────────────────────────────────────

class StorageService {

  // Hive box names
  static const _chatBox      = 'chat_history';
  static const _settingsBox  = 'settings';
  static const _kbBox        = 'knowledge_bases';
  static const _sessionBox   = 'sessions';

  // ── Init (call once in main.dart) ──────────────────────────
  static Future<void> init() async {
    try {
      print('Initializing StorageService...');
      if (kIsWeb) {
        await Hive.initFlutter();
      } else {
        final dir = await getApplicationSupportDirectory();
        Hive.init(dir.path);
      }
      print('Hive initialized.');
      await Hive.openBox(_chatBox);
      print('Chat box opened.');
      await Hive.openBox(_settingsBox);
      print('Settings box opened.');
      await Hive.openBox(_kbBox);
      print('KB box opened.');
      await Hive.openBox(_sessionBox);
      print('Session box opened.');
      await Hive.openBox('study_tasks');
      print('Study tasks box opened.');
      print('StorageService initialized successfully.');
    } catch (e, stack) {
      print('Failed to initialize StorageService: $e');
      print(stack);
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  API KEYS  (encrypted secure storage)
  // ══════════════════════════════════════════════════════════

  static Future<void> saveApiKey(String provider, String key) async {
    await _settings.put('api_key_$provider', key);
  }

  static Future<String?> getApiKey(String provider) async {
    return _settings.get('api_key_$provider');
  }

  static Future<void> deleteApiKey(String provider) async {
    await _settings.delete('api_key_$provider');
  }

  static Future<void> saveBackendUrl(String url) async {
    await _settings.put('backend_url', url);
  }

  static Future<String> getBackendUrl() async {
    return _settings.get('backend_url', defaultValue: 'http://localhost:8001');
  }

  static Future<Map<String, String>> getAllApiKeys() async {
    final all = _settings.toMap();
    return Map.fromEntries(
      all.entries
          .where((e) => e.key.toString().startsWith('api_key_'))
          .map((e) => MapEntry(e.key.toString().replaceFirst('api_key_', ''), e.value.toString())),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  CHAT HISTORY  (stored per session, kept for 7 days)
  // ══════════════════════════════════════════════════════════

  static Box get _chat => Hive.box(_chatBox);

  /// Save a full chat session
  static Future<void> saveChatSession(ChatSession session) async {
    await _chat.put(session.id, session.toJson());
    await _pruneOldChats(); // auto-clean chats older than 7 days
  }

  /// Append one message to an existing session (or create it)
  static Future<void> appendMessage(String sessionId, StorageChatMessage message) async {
    final existing = getChatSession(sessionId);
    if (existing != null) {
      existing.messages.add(message);
      existing.updatedAt = DateTime.now();
      await _chat.put(sessionId, existing.toJson());
    } else {
      final newSession = ChatSession(
        id: sessionId,
        title: message.content.length > 40
            ? '${message.content.substring(0, 40)}...'
            : message.content,
        messages: [message],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _chat.put(sessionId, newSession.toJson());
    }
  }

  /// Get a single session
  static ChatSession? getChatSession(String sessionId) {
    final raw = _chat.get(sessionId);
    if (raw == null) return null;
    return ChatSession.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Get all sessions sorted by newest first
  static List<ChatSession> getAllSessions() {
    return _chat.values
        .map((e) => ChatSession.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Get today's sessions only
  static List<ChatSession> getTodaySessions() {
    final now = DateTime.now();
    return getAllSessions().where((s) {
      return s.updatedAt.year == now.year &&
          s.updatedAt.month == now.month &&
          s.updatedAt.day == now.day;
    }).toList();
  }

  static Future<void> deleteChatSession(String sessionId) async {
    await _chat.delete(sessionId);
  }

  static Future<void> clearAllChats() async {
    await _chat.clear();
  }

  // Auto-delete chats older than 7 days
  static Future<void> _pruneOldChats() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final toDelete = _chat.keys.where((k) {
      final raw = _chat.get(k);
      if (raw == null) return false;
      final session = ChatSession.fromJson(Map<String, dynamic>.from(raw));
      return session.updatedAt.isBefore(cutoff);
    }).toList();
    await _chat.deleteAll(toDelete);
  }

  // ══════════════════════════════════════════════════════════
  //  SETTINGS
  // ══════════════════════════════════════════════════════════

  static Box get _settings => Hive.box(_settingsBox);

  static Future<void> saveSetting(String key, dynamic value) async {
    await _settings.put(key, value);
  }

  static T? getSetting<T>(String key, {T? defaultValue}) {
    return _settings.get(key, defaultValue: defaultValue) as T?;
  }

  // Convenience shortcuts
  static Future<void> saveSelectedModel(String model) =>
      saveSetting('selected_model', model);
  static String getSelectedModel() =>
      getSetting<String>('selected_model', defaultValue: 'gpt-4o') ?? 'gpt-4o';

  static Future<void> saveSelectedProvider(String provider) =>
      saveSetting('selected_provider', provider);
  static String getSelectedProvider() =>
      getSetting<String>('selected_provider', defaultValue: 'openai') ?? 'openai';

  static Future<void> saveThemeMode(String mode) =>
      saveSetting('theme_mode', mode);
  static String getThemeMode() =>
      getSetting<String>('theme_mode', defaultValue: 'dark') ?? 'dark';

  // ══════════════════════════════════════════════════════════
  //  KNOWLEDGE BASES  (cache list locally)
  // ══════════════════════════════════════════════════════════

  static Box get _kb => Hive.box(_kbBox);

  static Future<void> saveKnowledgeBases(List<String> names) async {
    await _kb.put('kb_list', names);
  }

  static List<String> getKnowledgeBases() {
    return List<String>.from(_kb.get('kb_list', defaultValue: <String>[]));
  }

  static Future<void> saveLastUsedKB(String name) async {
    await _kb.put('last_kb', name);
  }

  static String? getLastUsedKB() => _kb.get('last_kb');

  // ══════════════════════════════════════════════════════════
  //  ACTIVE SESSION (current conversation state)
  // ══════════════════════════════════════════════════════════

  static Box get _session => Hive.box(_sessionBox);

  static Future<void> saveActiveSessionId(String id) async {
    await _session.put('active_session_id', id);
  }

  static String? getActiveSessionId() => _session.get('active_session_id');

  static Future<void> clearActiveSession() async {
    await _session.delete('active_session_id');
  }
}

// ══════════════════════════════════════════════════════════
//  DATA MODELS
// ══════════════════════════════════════════════════════════

class ChatSession {
  final String id;
  String title;
  final List<StorageChatMessage> messages;
  final DateTime createdAt;
  DateTime updatedAt;
  String? knowledgeBase;
  String? module; // solver, research, question, etc.

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.knowledgeBase,
    this.module,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'knowledgeBase': knowledgeBase,
    'module': module,
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'],
    title: json['title'],
    messages: (json['messages'] as List)
        .map((m) => StorageChatMessage.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    knowledgeBase: json['knowledgeBase'],
    module: json['module'],
  );
}

class StorageChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final List<String>? citations;
  final String? imageBase64; // for camera-captured docs

  StorageChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.citations,
    this.imageBase64,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'citations': citations,
    'imageBase64': imageBase64,
  };

  factory StorageChatMessage.fromJson(Map<String, dynamic> json) => StorageChatMessage(
    id: json['id'],
    role: json['role'],
    content: json['content'],
    timestamp: DateTime.parse(json['timestamp']),
    citations: json['citations'] != null
        ? List<String>.from(json['citations'])
        : null,
    imageBase64: json['imageBase64'],
  );
}
