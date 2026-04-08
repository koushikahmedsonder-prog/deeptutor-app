import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_provider.dart';
import 'knowledge_provider.dart';
import '../services/storage_service.dart';
import '../services/document_service.dart';
import '../config/models_config.dart';
import '../services/duckduckgo_service.dart';

// ── Chat Message ──
class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? citations;
  final bool isStreaming;
  final PickedDocument? attachment;

  ChatMessage({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.citations,
    this.isStreaming = false,
    this.attachment,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith(
      {String? content, bool? isStreaming, List<String>? citations, PickedDocument? attachment}) {
    return ChatMessage(
      content: content ?? this.content,
      isUser: isUser,
      timestamp: timestamp,
      citations: citations ?? this.citations,
      isStreaming: isStreaming ?? this.isStreaming,
      attachment: attachment ?? this.attachment,
    );
  }
}

// ── Chat State ──
class ChatState {
  final String? id;
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.id,
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    String? id,
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      id: id ?? this.id,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Chat Notifier ──
class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    _loadActiveSession();
    return const ChatState();
  }

  Future<void> _loadActiveSession() async {
    final sessionId = StorageService.getActiveSessionId() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    await StorageService.saveActiveSessionId(sessionId);

    final session = StorageService.getChatSession(sessionId);
    if (session != null) {
      final loadedMessages = session.messages
          .map((sMsg) => ChatMessage(
                content: sMsg.content,
                isUser: sMsg.role == 'user',
                timestamp: sMsg.timestamp,
                citations: sMsg.citations,
              ))
          .toList();
      state = state.copyWith(id: sessionId, messages: loadedMessages);
    } else {
      state = state.copyWith(id: sessionId);
    }
  }

  Future<void> _persistMessage(ChatMessage msg) async {
    final sessionId = StorageService.getActiveSessionId();
    if (sessionId == null) return;

    final sMsg = StorageChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: msg.isUser ? 'user' : 'assistant',
      content: msg.content,
      timestamp: msg.timestamp,
      citations: msg.citations,
    );
    await StorageService.appendMessage(sessionId, sMsg);
  }

  void addUserMessage(String content, {PickedDocument? attachment}) {
    final msg = ChatMessage(content: content, isUser: true, attachment: attachment);
    state = state.copyWith(messages: [...state.messages, msg]);
    _persistMessage(msg);
  }

  /// KB-based question — uses interactive engine with single-call (fast)
  Future<void> sendQuestion(String kbName, String question,
      {PickedDocument? attachment, bool useWebSearch = false}) async {
    addUserMessage(question, attachment: attachment);
    state = state.copyWith(isLoading: true, error: null);

    final aiMessage = ChatMessage(
      content: 'Analyzing your question...',
      isUser: false,
      isStreaming: true,
    );
    state = state.copyWith(messages: [...state.messages, aiMessage]);

    try {
      final engine = ref.read(interactiveAnswerEngineProvider);
      final kbNotifier = ref.read(knowledgeProvider.notifier);
      final kbContent = kbNotifier.getKnowledgeBaseContent(kbName);

      final pastContext = _buildPastContext();

      // Use single-call interactive engine (fast, no dual-loop overhead)
      final interactiveAnswer = await engine.answerSingleCall(
        question: question,
        pastContext: kbContent.isNotEmpty
            ? 'KB Context:\n$kbContent\n\n$pastContext'
            : pastContext,
        attachment: attachment,
        useWebSearch: useWebSearch,
      );

      // Store the formatted Markdown instead of raw JSON
      final messageContent = interactiveAnswer.isRichFormat 
          ? interactiveAnswer.toMarkdown() 
          : interactiveAnswer.rawText;
      _updateLastAIMessage(messageContent, false, []);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      _updateLastAIMessage('Error: ${e.toString()}', false, []);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// General question (no KB) — also uses interactive engine
  Future<void> sendGeneralQuestion(String question, {
    PickedDocument? attachment,
    bool useWebSearch = false,
    bool useCode = false,
    bool useReason = false,
    LLMModel? modelOverride,
  }) async {
    addUserMessage(question, attachment: attachment);
    state = state.copyWith(isLoading: true, error: null);

    final aiMessage = ChatMessage(
      content: 'Searching and thinking...',
      isUser: false,
      isStreaming: true,
    );
    state = state.copyWith(messages: [...state.messages, aiMessage]);

    try {
      final api = ref.read(apiServiceProvider);
      final pastContext = _buildPastContext();

      // ── STEP 1: Auto-decide if web search is needed ──────────
      final shouldSearch = useWebSearch || await _shouldUseWebSearch(question, api);

      // ── STEP 2: Fetch web content if needed ──────────────────
      String webContext = '';
      List<String> sourceCitations = [];

      if (shouldSearch) {
        _updateLastAIMessage('🔍 Searching the web...', true, []);
        try {
          webContext = await DuckDuckGoService.searchWithContent(question);
          // Extract source URLs for citation chips
          final urlRegex = RegExp(r'Source:\s*(https?://[^\s\)]+)');
          sourceCitations = urlRegex
              .allMatches(webContext)
              .map((m) => m.group(1)!)
              .take(3)
              .toList();
        } catch (_) {
          webContext = '';
        }
      }

      // ── STEP 3: Build prompt with web context ─────────────────
      _updateLastAIMessage('💡 Generating answer...', true, []);

      final enhancedContext = [
        if (pastContext.isNotEmpty) pastContext,
        if (webContext.isNotEmpty) 'WEB SEARCH RESULTS (use these as primary source, cite URLs):\n$webContext',
      ].join('\n\n');

      final engine = ref.read(interactiveAnswerEngineProvider);
      final interactiveAnswer = await engine.answerSingleCall(
        question: question,
        pastContext: enhancedContext,
        attachment: attachment,
        useWebSearch: false, // manually handled above
      );

      final messageContent = interactiveAnswer.isRichFormat 
          ? interactiveAnswer.toMarkdown() 
          : interactiveAnswer.rawText;

      _updateLastAIMessage(messageContent, false, sourceCitations);
      state = state.copyWith(isLoading: false);

    } catch (e) {
      _updateLastAIMessage('Error: ${e.toString()}', false, []);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Auto-detect if question needs web search ─────────────────
  Future<bool> _shouldUseWebSearch(String question, dynamic api) async {
    // Fast keyword check first (no API call needed)
    final webKeywords = [
      'latest', 'news', 'today', 'current', 'price', 'who is',
      'what is', 'how to', 'best', 'top', 'recent', '2024', '2025',
      'where', 'when', 'find', 'search', 'show me',
    ];
    final lower = question.toLowerCase();
    if (webKeywords.any((k) => lower.contains(k))) return true;

    // For ambiguous questions, ask AI
    try {
      final decision = await api.callLLM(
        prompt: 'Does this need a web search for current/factual info? "$question"\nReply YES or NO only.',
        systemInstruction: 'Reply with only YES or NO.',
      );
      return decision.trim().toUpperCase().startsWith('Y');
    } catch (_) {
      return false;
    }
  }

  String _buildPastContext() {
    if (state.messages.length <= 2) return '';
    return state.messages
        .sublist(0, state.messages.length - 2)
        .take(6) // last 6 messages for context
        .map((m) => '${m.isUser ? "User" : "Assistant"}: ${m.content}')
        .join('\n');
  }

  void _updateLastAIMessage(
    String content,
    bool isStreaming,
    List<String> citations,
  ) {
    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isNotEmpty && !messages.last.isUser) {
      final updatedMsg = messages.last.copyWith(
        content: content,
        isStreaming: isStreaming,
        citations: citations,
      );
      messages[messages.length - 1] = updatedMsg;
      state = state.copyWith(messages: messages);

      if (!isStreaming) {
        _persistMessage(updatedMsg);
      }
    }
  }

  void loadSession(String sessionId) {
    StorageService.saveActiveSessionId(sessionId);
    state = const ChatState();
    _loadActiveSession();
  }

  void clearChat() {
    state = const ChatState();
    StorageService.clearActiveSession();
    _loadActiveSession();
  }
}

// ── Provider ──
final chatProvider =
    NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
