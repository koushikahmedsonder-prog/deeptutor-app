import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_theme.dart';
import '../utils/theme_helper.dart';
import '../services/image_fetch_service.dart';
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;

/// A powerful rich content renderer that handles:
/// - Standard Markdown (headers, bold, lists, tables, blockquotes)
/// - LaTeX math: inline `$...$` and display `$$...$$`
/// - Mermaid diagram code blocks (rendered as styled containers)
/// - `[FETCH_IMAGE: "query"]` tags (fetches and displays images)
/// - SVG code blocks (rendered as styled containers)
///
/// Use this widget anywhere AI-generated content needs to be displayed.
class RichContentRenderer extends StatefulWidget {
  final String content;
  final EdgeInsets padding;
  final bool selectable;

  const RichContentRenderer({
    super.key,
    required this.content,
    this.padding = EdgeInsets.zero,
    this.selectable = true,
  });

  @override
  State<RichContentRenderer> createState() => _RichContentRendererState();
}

class _RichContentRendererState extends State<RichContentRenderer> {
  late String _processedContent;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _processedContent = widget.content;
    _processImages();
  }

  @override
  void didUpdateWidget(RichContentRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _processedContent = widget.content;
      _processImages();
    }
  }

  Future<void> _processImages() async {
    if (!_processedContent.contains('[FETCH_IMAGE:')) return;
    setState(() => _isProcessing = true);
    try {
      final service = ImageFetchService();
      final processed = await service.processResponse(_processedContent);
      if (mounted) {
        setState(() {
          _processedContent = processed;
          _isProcessing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final segments = _parseContent(_processedContent);

    final child = Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isProcessing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accentCyan.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading images...',
                    style: TextStyle(
                      color: context.textTer,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ...segments.map((seg) => _buildSegment(seg)),
        ],
      ),
    );

    if (widget.selectable) {
      return SelectionArea(child: child);
    }
    return child;
  }

  Widget _buildSegment(_ContentSegment seg) {
    switch (seg.type) {
      case _SegmentType.markdown:
        return MarkdownBody(
          data: seg.content,
          selectable: false,
          styleSheet: context.isDark ? AppTheme.darkMarkdownStyle : AppTheme.markdownStyle,
          builders: {
            'code': CodeElementBuilder(context),
          },
          onTapLink: (text, href, title) {
            if (href != null) {
              launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
            }
          },
          imageBuilder: (uri, title, alt) {
            return _buildNetworkImage(uri.toString(), alt ?? '');
          },
        );

      case _SegmentType.latexInline:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: _buildInlineLatexContent(seg.content),
          ),
        );

      case _SegmentType.latexDisplay:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.accentIndigo.withValues(alpha: 0.3),
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                seg.content.trim(),
                textStyle: TextStyle(
                  color: context.textPri,
                  fontSize: 18,
                ),
                mathStyle: MathStyle.display,
                onErrorFallback: (err) => Text(
                  '\$\$${seg.content}\$\$',
                  style: TextStyle(
                    color: AppTheme.accentOrange,
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        );

      case _SegmentType.mermaid:
        return _MermaidWebViewBlock(mermaidCode: seg.content.trim());

      case _SegmentType.svg:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.image_rounded,
                      size: 16, color: AppTheme.accentGreen),
                  const SizedBox(width: 6),
                  Text(
                    'SVG Diagram',
                    style: TextStyle(
                      color: AppTheme.accentGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                seg.content.trim(),
                style: TextStyle(
                  color: context.textPri,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ],
          ),
        );

      case _SegmentType.image:
        return _buildNetworkImage(seg.content, seg.metadata ?? '');
    }
  }

  Widget _buildNetworkImage(String url, String altText) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            width: double.infinity,
            placeholder: (ctx, url) => Container(
              height: 150,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accentCyan,
                  ),
                  const SizedBox(height: 8),
                  Text('Loading image...',
                      style: TextStyle(
                          color: context.textTer, fontSize: 12)),
                ],
              ),
            ),
            errorWidget: (ctx, url, error) => Container(
              height: 100,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_rounded,
                      size: 32,
                      color: AppTheme.textTertiary),
                  const SizedBox(height: 6),
                  Text(
                    altText.isNotEmpty ? altText : 'Image unavailable',
                    style: TextStyle(
                        color: context.textTer, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (altText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Text(
                altText,
                style: TextStyle(
                  color: context.textTer,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  /// Build inline content that mixes text and LaTeX
  List<Widget> _buildInlineLatexContent(String text) {
    final widgets = <Widget>[];
    final pattern = RegExp(r'\$([^$]+?)\$');
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      // Text before the match
      if (match.start > lastEnd) {
        final before = text.substring(lastEnd, match.start);
        if (before.isNotEmpty) {
          widgets.add(
            MarkdownBody(
              data: before,
              selectable: false,
              styleSheet: context.isDark ? AppTheme.darkMarkdownStyle : AppTheme.markdownStyle,
              shrinkWrap: true,
            ),
          );
        }
      }

      // The LaTeX inline
      final latex = match.group(1)!;
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Math.tex(
            latex,
            textStyle: const TextStyle(
              color: AppTheme.accentCyan,
              fontSize: 15,
            ),
            mathStyle: MathStyle.text,
            onErrorFallback: (err) => Text(
              '\$$latex\$',
              style: TextStyle(
                color: AppTheme.accentOrange,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
      lastEnd = match.end;
    }

    // Remaining text
    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd);
      if (remaining.isNotEmpty) {
        widgets.add(
          MarkdownBody(
            data: remaining,
            selectable: false,
            styleSheet: context.isDark ? AppTheme.darkMarkdownStyle : AppTheme.markdownStyle,
            shrinkWrap: true,
          ),
        );
      }
    }

    return widgets;
  }

  /// Parse content into typed segments for rendering
  List<_ContentSegment> _parseContent(String text) {
    final segments = <_ContentSegment>[];
    // Pre-process: extract special blocks first
    // Order: display LaTeX, mermaid code blocks, SVG blocks, inline LaTeX lines

    // Regex patterns
    final displayLatex = RegExp(r'\$\$([\s\S]*?)\$\$');
    final mermaidBlock = RegExp(r'```mermaid\s*\n([\s\S]*?)```', multiLine: true);
    final svgBlock = RegExp(r'```svg\s*\n([\s\S]*?)```', multiLine: true);
    final fetchImage = RegExp(r'\[FETCH_IMAGE:\s*"([^"]+)"\]');

    // Collect all special ranges
    final specialRanges = <_SpecialRange>[];

    for (final m in displayLatex.allMatches(text)) {
      specialRanges.add(_SpecialRange(m.start, m.end, _SegmentType.latexDisplay, m.group(1)!));
    }
    for (final m in mermaidBlock.allMatches(text)) {
      specialRanges.add(_SpecialRange(m.start, m.end, _SegmentType.mermaid, m.group(1)!));
    }
    for (final m in svgBlock.allMatches(text)) {
      specialRanges.add(_SpecialRange(m.start, m.end, _SegmentType.svg, m.group(1)!));
    }
    for (final m in fetchImage.allMatches(text)) {
      specialRanges.add(_SpecialRange(m.start, m.end, _SegmentType.image, m.group(1)!, metadata: m.group(1)));
    }

    // Sort by start position
    specialRanges.sort((a, b) => a.start.compareTo(b.start));

    // Remove overlapping ranges (keep first)
    final cleaned = <_SpecialRange>[];
    for (final r in specialRanges) {
      if (cleaned.isEmpty || r.start >= cleaned.last.end) {
        cleaned.add(r);
      }
    }

    // Build segments
    int cursor = 0;
    for (final range in cleaned) {
      // Text before this special range
      if (cursor < range.start) {
        final before = text.substring(cursor, range.start).trim();
        if (before.isNotEmpty) {
          // Check if this text contains inline LaTeX ($...$)
          if (RegExp(r'(?<!\$)\$(?!\$)([^$]+?)\$(?!\$)').hasMatch(before)) {
            segments.add(_ContentSegment(_SegmentType.latexInline, _autoLink(before)));
          } else {
            segments.add(_ContentSegment(_SegmentType.markdown, _autoLink(before)));
          }
        }
      }
      segments.add(_ContentSegment(range.type, range.content, metadata: range.metadata));
      cursor = range.end;
    }

    // Remaining text after all special ranges
    if (cursor < text.length) {
      final remaining = text.substring(cursor).trim();
      if (remaining.isNotEmpty) {
        if (RegExp(r'(?<!\$)\$(?!\$)([^$]+?)\$(?!\$)').hasMatch(remaining)) {
          segments.add(_ContentSegment(_SegmentType.latexInline, _autoLink(remaining)));
        } else {
          segments.add(_ContentSegment(_SegmentType.markdown, _autoLink(remaining)));
        }
      }
    }

    // If no segments matched, treat entire content as markdown
    if (segments.isEmpty && text.trim().isNotEmpty) {
      segments.add(_ContentSegment(_SegmentType.markdown, _autoLink(text)));
    }

    return segments;
  }

  /// Automatically wraps bare URLs (like www.math.harvard.edu) in markdown links
  String _autoLink(String text) {
    // Matches www.xxxx.yyy or http(s)://xxxx
    final urlRegex = RegExp(r'(?<!\[)(?:https?:\/\/|www\.)[^\s<]+(?![^\[]*\])');
    return text.replaceAllMapped(urlRegex, (match) {
      final url = match.group(0)!;
      final fullUrl = url.startsWith('www.') ? 'https://$url' : url;
      return '[$url]($fullUrl)';
    });
  }
}

// ── Internal models ──

enum _SegmentType {
  markdown,
  latexInline,
  latexDisplay,
  mermaid,
  svg,
  image,
}

class _ContentSegment {
  final _SegmentType type;
  final String content;
  final String? metadata;

  _ContentSegment(this.type, this.content, {this.metadata});
}

class _SpecialRange {
  final int start;
  final int end;
  final _SegmentType type;
  final String content;
  final String? metadata;

  _SpecialRange(this.start, this.end, this.type, this.content, {this.metadata});
}

// ─────────────────────────────────────────────────
// MERMAID RENDERER (via WebView)
// ─────────────────────────────────────────────────
class _MermaidWebViewBlock extends StatefulWidget {
  final String mermaidCode;
  const _MermaidWebViewBlock({required this.mermaidCode});

  @override
  State<_MermaidWebViewBlock> createState() => _MermaidWebViewBlockState();
}

class _MermaidWebViewBlockState extends State<_MermaidWebViewBlock> {

  double _height = 200;

  String _buildHtml(String mermaidCode) {
    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { 
    background-color: #1a1a2e !important; 
    display: flex; 
    justify-content: center; 
    align-items: flex-start; 
    padding: 8px;
    color: white; 
  }
  .mermaid { 
    max-width: 100%; 
    font-family: sans-serif;
  }
  
  /* FORCE all text inside SVG to be bold and white */
  .mermaid svg text, 
  .mermaid svg .edgeLabel {
    font-size: 64px !important;
    font-weight: bold !important;
    fill: #ffffff !important;
    color: #ffffff !important;
  }
  
  /* Thicker, more pronounced node borders */
  .mermaid svg .node rect, 
  .mermaid svg .node circle, 
  .mermaid svg .node polygon,
  .mermaid svg .node path {
    stroke: #4F46E5 !important;
    stroke-width: 6px !important;
  }

  svg { max-width: 100%; height: auto !important; }
</style>
</head>
<body>
<div class="mermaid" id="diagram">
$mermaidCode
</div>
<script>
  mermaid.initialize({ 
    startOnLoad: true, 
    theme: 'dark',
    fontFamily: 'sans-serif',
    themeVariables: {
      fontSize: '42px',
      nodeBorder: '#4F46E5', // Make borders pop a bit more since it is bigger
    }
  });
  // After render, tell Flutter the actual height
  window.addEventListener('load', function() {
    setTimeout(function() {
      const h = document.body.scrollHeight;
      window.flutter_inappwebview.callHandler('onHeightChanged', h);
    }, 500);
  });
</script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentCyan.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_rounded,
                  size: 16, color: AppTheme.accentCyan),
              const SizedBox(width: 6),
              Text(
                'Diagram',
                style: TextStyle(
                  color: AppTheme.accentCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _height,
            child: InAppWebView(
              initialData: InAppWebViewInitialData(
                data: _buildHtml(widget.mermaidCode),
                mimeType: 'text/html',
                encoding: 'utf-8',
              ),
              initialSettings: InAppWebViewSettings(
                transparentBackground: true,
                javaScriptEnabled: true,
                scrollBarStyle: ScrollBarStyle.SCROLLBARS_OUTSIDE_OVERLAY,
                disableVerticalScroll: true,
              ),
              onWebViewCreated: (controller) {

                controller.addJavaScriptHandler(
                  handlerName: 'onHeightChanged',
                  callback: (args) {
                    if (args.isNotEmpty) {
                      final h = double.tryParse(args[0].toString());
                      if (h != null && h > 50 && mounted) {
                        setState(() => _height = h + 24);
                      }
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext ctx;
  CodeElementBuilder(this.ctx);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var language = '';
    if (element.attributes['class'] != null) {
      String lg = element.attributes['class'] as String;
      language = lg.substring(9);
    }
    
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkSurface : AppTheme.surface;
    final borderColor = isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder;

    if (language.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          element.textContent,
          style: GoogleFonts.firaCode(fontSize: 13, color: AppTheme.accentCyan),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: HighlightView(
        element.textContent,
        language: language,
        theme: atomOneDarkTheme,
        padding: const EdgeInsets.all(12),
        textStyle: GoogleFonts.firaCode(fontSize: 13),
      ),
    );
  }
}
