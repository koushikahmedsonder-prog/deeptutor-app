import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_provider.dart';
import 'knowledge_provider.dart';
import '../services/document_service.dart';
import '../services/deeptutor_prompts.dart';
import 'chat_provider.dart'; // reuse ChatMessage / ChatState

/// Separate provider for Deep Solve — independent chat state from general Chat.
class SolverNotifier extends Notifier<ChatState> {
  @override
  ChatState build() => const ChatState();

  void addUserMessage(String content, {PickedDocument? attachment}) {
    final msg = ChatMessage(content: content, isUser: true, attachment: attachment);
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  Future<String> _ensureComplete(
    String answer,
    String question,
    dynamic api,
  ) async {
    // Detect incomplete answer patterns
    final incompletePatterns = [
      RegExp(r'continue (this |the )?(process|iteration|calculation)', caseSensitive: false),
      RegExp(r'use a (computer|program|calculator)', caseSensitive: false),
      RegExp(r'(repeat|continue) until convergence', caseSensitive: false),
      RegExp(r'and so on\.?$', caseSensitive: false),
      RegExp(r'etc\.?\s*$', caseSensitive: false),
      RegExp(r'\.\.\.+\s*$'),
      RegExp(r'(left as|is an) exercise', caseSensitive: false),
      RegExp(r'similarly,? (we can|you can)', caseSensitive: false),
      RegExp(r'rest of the (code|implementation|steps)', caseSensitive: false),
      RegExp(r'// ?TODO', caseSensitive: false),
      RegExp(r'complete the (remaining|rest)', caseSensitive: false),
    ];

    bool isIncomplete = incompletePatterns.any((p) => p.hasMatch(answer));

    // Also check if numerical problem has no final numerical answer
    final hasNumericalQuestion = RegExp(
      r'(solve|calculate|find|compute|evaluate|determine)',
      caseSensitive: false,
    ).hasMatch(question);

    final hasFinalAnswer = RegExp(
      r'(therefore|∴|final answer|=\s*[\d\.\-]+)',
      caseSensitive: false,
    ).hasMatch(answer);

    if (hasNumericalQuestion && !hasFinalAnswer) {
      isIncomplete = true;
    }

    if (!isIncomplete) return answer;

    // Answer is incomplete — continue it
    _updateLastAIMessage(
      '$answer\n\n_Continuing solution..._',
      true,
      [],
    );

    try {
      final continuationPrompt = '''
The following answer to this question was cut off or incomplete:

QUESTION: $question

INCOMPLETE ANSWER SO FAR:
$answer

INSTRUCTIONS:
- Continue EXACTLY from where the answer stopped
- Do NOT repeat what was already said
- Complete ALL remaining steps
- Give the final numerical/concrete answer
- End with a clear "Final Answer:" line
''';

      final continuation = await api.callLLM(
        prompt: continuationPrompt,
        systemInstruction: '''
You are completing an unfinished solution.
Continue from exactly where it stopped.
NEVER say "as I mentioned" or repeat previous content.
Go straight to the next step and complete the solution fully.
${DeepTutorPrompts.universalCompletionRules}
''',
      );

      return '$answer\n\n$continuation';
    } catch (_) {
      return answer;
    }
  }

  Future<void> sendSolverQuestion(String question,
      {String? kbName, PickedDocument? attachment, bool useWebSearch = false}) async {
    addUserMessage(question, attachment: attachment);
    state = state.copyWith(isLoading: true, error: null);

    final aiMessage = ChatMessage(
      content: 'Running DeepTutor Dual-Loop Analysis...',
      isUser: false,
      isStreaming: true,
    );
    state = state.copyWith(messages: [...state.messages, aiMessage]);

    try {
      final engine = ref.read(interactiveAnswerEngineProvider);
      final api = ref.read(apiServiceProvider);
      String? kbContent;

      if (kbName != null && kbName.isNotEmpty) {
        final kbNotifier = ref.read(knowledgeProvider.notifier);
        kbContent = kbNotifier.getKnowledgeBaseContent(kbName);
      }

      final pastContext = state.messages.length > 2 
          ? state.messages.sublist(0, state.messages.length - 2).map((m) => '${m.isUser ? "User" : "System"}: ${m.content}').join('\n')
          : '';

      final interactiveAnswer = await engine.answerWithDualLoop(
        question: question,
        pastContext: pastContext,
        kbContent: kbContent,
        attachment: attachment,
        useWebSearch: useWebSearch,
      );

      String messageContent = interactiveAnswer.isRichFormat 
          ? interactiveAnswer.toMarkdown() 
          : interactiveAnswer.rawText;
          
      // Check and complete if answer was cut off
      messageContent = await _ensureComplete(messageContent, question, api);

      _updateLastAIMessage(messageContent, false, []);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      _updateLastAIMessage('Error: ${e.toString()}', false, []);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
  void _updateLastAIMessage(String content, bool isStreaming, List<String> citations) {
    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isNotEmpty && !messages.last.isUser) {
      final updatedMsg = messages.last.copyWith(
        content: content,
        isStreaming: isStreaming,
        citations: citations,
      );
      messages[messages.length - 1] = updatedMsg;
      state = state.copyWith(messages: messages);
    }
  }

  void clearChat() {
    state = const ChatState();
  }
}

final solverProvider =
    NotifierProvider<SolverNotifier, ChatState>(SolverNotifier.new);
