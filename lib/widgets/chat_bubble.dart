import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../utils/theme_helper.dart';
import '../providers/chat_provider.dart';
import '../services/document_service.dart';
import 'rich_content_renderer.dart';
import 'streaming_text.dart';

/// Optimized chat bubble with:
/// - AutomaticKeepAlive to avoid rebuilding off-screen messages
/// - Removed per-item .animate() to prevent rebuild cascades in ListView
/// - Copy-on-long-press for AI messages
class ChatBubble extends StatefulWidget {
  final ChatMessage message;
  final int index;

  const ChatBubble({super.key, required this.message, required this.index});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // ⚡ Prevent off-screen rebuilds

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    final isUser = widget.message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: widget.message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📋 Copied to clipboard'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppTheme.accentIndigo.withValues(alpha: 0.15)
                      : context.cardColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: Border.all(
                    color: isUser
                        ? AppTheme.accentIndigo.withValues(alpha: 0.3)
                        : context.cardBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Attachment preview
                    if (isUser && widget.message.attachment != null) ...[
                      _AttachmentPreview(attachment: widget.message.attachment!),
                      const SizedBox(height: 10),
                    ],
                    // Message content
                    if (isUser)
                      SelectableText(
                        widget.message.content,
                        style: TextStyle(
                          color: context.textPri,
                          fontSize: 15,
                        ),
                      )
                    else if (widget.message.isStreaming)
                      StreamingText(
                        text: widget.message.content,
                        isStreaming: true,
                      )
                    else
                      RichContentRenderer(
                        content: widget.message.content,
                        selectable: true,
                      ),


                    // Citations
                    if (widget.message.citations != null &&
                        widget.message.citations!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: widget.message.citations!
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

                    if (!isUser && !widget.message.isStreaming) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.copy_rounded, size: 16, color: context.textTer),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: widget.message.content));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied to clipboard'), 
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            tooltip: 'Copy',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
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
    );
  }
}

/// Extracted reusable attachment preview widget
class _AttachmentPreview extends StatelessWidget {
  final PickedDocument attachment;

  const _AttachmentPreview({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachment.bytes != null && attachment.type == DocumentType.image)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                attachment.bytes!,
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
                color: context.cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(attachment.icon,
                    style: const TextStyle(fontSize: 24)),
              ),
            ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              attachment.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.textSec,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
