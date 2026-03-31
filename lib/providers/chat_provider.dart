import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_provider.dart';
import 'knowledge_provider.dart';
import '../services/storage_service.dart';
import '../services/document_service.dart';
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
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
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
    final sessionId = StorageService.getActiveSessionId() ?? DateTime.now().millisecondsSinceEpoch.toString();
    await StorageService.saveActiveSessionId(sessionId);
    
    final session = StorageService.getChatSession(sessionId);
    if (session != null) {
      final loadedMessages = session.messages.map((sMsg) => ChatMessage(
        content: sMsg.content,
        isUser: sMsg.role == 'user',
        timestamp: sMsg.timestamp,
        citations: sMsg.citations,
      )).toList();
      state = state.copyWith(messages: loadedMessages);
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

  Future<void> sendQuestion(String kbName, String question, {PickedDocument? attachment, bool useWebSearch = false}) async {
    addUserMessage(question, attachment: attachment);
    state = state.copyWith(isLoading: true, error: null);

    // Add placeholder AI message
    final aiMessage = ChatMessage(
      content: 'Thinking...',
      isUser: false,
      isStreaming: true,
    );
    state = state.copyWith(messages: [...state.messages, aiMessage]);

    try {
      final api = ref.read(apiServiceProvider);
      final kbNotifier = ref.read(knowledgeProvider.notifier);

      // Get KB content for context
      final kbContent = kbNotifier.getKnowledgeBaseContent(kbName);

      // Call Gemini API
      final answer = await api.solveQuestion(
        question: question,
        kbContent: kbContent.isNotEmpty ? kbContent : null,
        attachment: attachment,
        useWebSearch: useWebSearch,
      );

      _updateLastAIMessage(answer, false, []);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      _updateLastAIMessage(
        'Error: ${e.toString()}',
        false,
        [],
      );
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Send a general question without KB context
  Future<void> sendGeneralQuestion(String question, {PickedDocument? attachment, bool useWebSearch = false}) async {
    addUserMessage(question, attachment: attachment);
    state = state.copyWith(isLoading: true, error: null);

    final aiMessage = ChatMessage(
      content: 'Thinking...',
      isUser: false,
      isStreaming: true,
    );
    state = state.copyWith(messages: [...state.messages, aiMessage]);

    try {
      final api = ref.read(apiServiceProvider);
      final answer = await api.solveQuestion(
        question: question,
        attachment: attachment,
        useWebSearch: useWebSearch,
      );

      _updateLastAIMessage(answer, false, []);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      _updateLastAIMessage(
        'Error: ${e.toString()}',
        false,
        [],
      );
      state = state.copyWith(isLoading: false, error: e.toString());
    }
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
      
      // Persist when the response finishes streaming
      if (!isStreaming) {
        _persistMessage(updatedMsg);
      }
    }
  }

  void clearChat() {
    state = const ChatState();
    StorageService.clearActiveSession();
    _loadActiveSession(); // start a new isolated session
  }
}

// ── Provider ──
final chatProvider =
    NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
