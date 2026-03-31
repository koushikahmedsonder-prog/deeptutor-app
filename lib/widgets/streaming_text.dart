import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class StreamingText extends StatefulWidget {
  final String text;
  final bool isStreaming;
  final TextStyle? style;

  const StreamingText({
    super.key,
    required this.text,
    this.isStreaming = false,
    this.style,
  });

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: widget.style ??
            const TextStyle(
              fontSize: 15,
              color: AppTheme.textPrimary,
              height: 1.6,
            ),
        children: [
          TextSpan(text: widget.text),
          if (widget.isStreaming)
            WidgetSpan(
              child: AnimatedBuilder(
                animation: _cursorController,
                builder: (context, _) {
                  return Opacity(
                    opacity: _cursorController.value,
                    child: Container(
                      width: 2,
                      height: 18,
                      margin: const EdgeInsets.only(left: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentIndigo,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
