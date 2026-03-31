import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/app_theme.dart';
import '../providers/chat_provider.dart';
import '../services/document_service.dart';
import 'streaming_text.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final int index;

  const ChatBubble({super.key, required this.message, required this.index});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.accentIndigo.withValues(alpha: 0.15)
                    : AppTheme.cardDark,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? AppTheme.accentIndigo.withValues(alpha: 0.3)
                      : AppTheme.cardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser && message.attachment != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.attachment!.bytes != null && message.attachment!.type == DocumentType.image)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                message.attachment!.bytes!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppTheme.cardDark,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(message.attachment!.icon, style: const TextStyle(fontSize: 24)),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              message.attachment!.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isUser)
                    SelectableText(
                      message.content,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                    )
                  else if (message.isStreaming)
                    StreamingText(
                      text: message.content,
                      isStreaming: true,
                    )
                  else
                    SelectionArea(
                      child: MarkdownBody(
                        data: message.content,
                        selectable: true,
                        styleSheet: AppTheme.markdownStyle,
                      ),
                    ),

                  // Citations
                  if (message.citations != null &&
                      message.citations!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: message.citations!
                          .map((c) => Chip(
                                label: Text(
                                  c,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.accentCyan,
                                  ),
                                ),
                                backgroundColor:
                                    AppTheme.accentCyan.withValues(alpha: 0.1),
                                side: BorderSide(
                                  color: AppTheme.accentCyan
                                      .withValues(alpha: 0.3),
                                ),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentIndigo.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person,
                  size: 18, color: AppTheme.accentIndigo),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(
        begin: 0.1, end: 0, duration: 300.ms);
  }
}
