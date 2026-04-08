import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:convert';
import 'web_downloader_stub.dart'
    if (dart.library.html) 'web_downloader_web.dart';

/// Service that generates real PDF files from markdown/text content.
class PdfExportService {
  /// Export content as a properly formatted PDF file
  static Future<String?> exportAsFile({
    required String title,
    required String content,
    String format = 'pdf',
  }) async {
    try {
      final sanitizedTitle = title
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${sanitizedTitle}_$timestamp.pdf';

      String? dirPath;

      if (!kIsWeb) {
        // Try Downloads folder first (works on desktop)
        try {
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
            final home = Platform.environment['USERPROFILE'] ??
                Platform.environment['HOME'] ??
                '';
            final downloadsDir = Directory('$home${Platform.pathSeparator}Downloads');
            if (await downloadsDir.exists()) {
              dirPath = downloadsDir.path;
            }
          }
        } catch (_) {}

        // Fallback to app documents directory
        if (dirPath == null) {
          final docsDir = await getApplicationDocumentsDirectory();
          dirPath = docsDir.path;
        }

        final filePath = '$dirPath${Platform.pathSeparator}$fileName';

        // Generate PDF
        final pdfBytes = await _generatePdf(title, content);
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        return file.path;
      } else {
        // Trigger web browser download
        final pdfBytes = await _generatePdf(title, content);
        downloadFileWeb(fileName, Uint8List.fromList(pdfBytes));
        return 'Downloads folder';
      }
    } catch (e) {
      debugPrint('Export error: $e');
      return null;
    }
  }

  /// Export content as a .doc file (HTML format readable by Word processors)
  static Future<String?> exportAsDoc({
    required String title,
    required String content,
  }) async {
    try {
      final sanitizedTitle = title
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${sanitizedTitle}_$timestamp.doc';

      // 1. Escape HTML
      String htmlContent = content.replaceAll('&', '&amp;')
                                  .replaceAll('<', '&lt;')
                                  .replaceAll('>', '&gt;');
      
      // 2. Convert headers
      htmlContent = htmlContent.replaceAllMapped(RegExp(r'^### (.*?)$', multiLine: true), (m) => '<h3>${m[1]}</h3>');
      htmlContent = htmlContent.replaceAllMapped(RegExp(r'^## (.*?)$', multiLine: true), (m) => '<h2>${m[1]}</h2>');
      htmlContent = htmlContent.replaceAllMapped(RegExp(r'^# (.*?)$', multiLine: true), (m) => '<h1>${m[1]}</h1>');
      
      // 3. Convert bold & italic
      htmlContent = htmlContent.replaceAllMapped(RegExp(r'\*\*([^\*]+)\*\*'), (m) => '<strong>${m[1]}</strong>');
      htmlContent = htmlContent.replaceAllMapped(RegExp(r'\*([^\*]+)\*'), (m) => '<em>${m[1]}</em>');
      
      // 4. Convert Horizontal Rule
      htmlContent = htmlContent.replaceAll(RegExp(r'^---$', multiLine: true), '<hr/>');

      // 4.5. Convert lists & code blocks
      htmlContent = htmlContent.replaceAllMapped(RegExp(r'^\s*[\-\*] (.*?)$', multiLine: true), (m) => '<li>${m[1]}</li>');
      htmlContent = htmlContent.replaceAllMapped(RegExp(r'^\s*\d+\. (.*?)$', multiLine: true), (m) => '<li>${m[1]}</li>');
      htmlContent = htmlContent.replaceAllMapped(RegExp(r'```(.*?)```', dotAll: true), (m) => '<div style="background-color: #f4f4f4; padding: 10px; font-family: monospace;">${(m[1] ?? '').replaceAll('\n', '<br/>')}</div>');
      htmlContent = htmlContent.replaceAllMapped(RegExp(r'`(.*?)`'), (m) => '<span style="font-family: monospace; background-color: #f0f0f0;">${m[1]}</span>');

      // 5. Wrap paragraphs and parse tables/images
      htmlContent = htmlContent.replaceAllMapped(RegExp(r'!\[([^\]]*)\]\(([^\)]+)\)'), (m) => '<div style="margin: 10px 0;"><img src="${m[2]}" alt="${m[1]}" style="max-width: 100%; max-height: 300px; border: 1px solid #ccc;"/></div>');

      final lines = htmlContent.split('\n');
      final sb = StringBuffer();
      for (int i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.isEmpty) continue;
        
        if (line.startsWith('|') && line.endsWith('|')) {
          sb.writeln('<table border="1" cellpadding="5" cellspacing="0" style="border-collapse: collapse; width: 100%; font-size: 10pt; margin-bottom: 12px; border-color: #DDDDDD;">');
          int r = 0;
          while (i < lines.length && lines[i].trim().startsWith('|')) {
            final rowLine = lines[i].trim();
            if (RegExp(r'^\|[\s\-\:]+\|').hasMatch(rowLine)) {
              i++;
              continue;
            }
            final cells = rowLine.split('|').map((c) => c.trim()).toList();
            if (cells.isNotEmpty) cells.removeAt(0);
            if (cells.isNotEmpty && rowLine.endsWith('|')) cells.removeLast();
            sb.writeln('<tr>');
            for (var cell in cells) {
               if (r == 0) {
                 sb.writeln('<th style="background-color: #f0f0f0; text-align: left;">$cell</th>');
               } else {
                 sb.writeln('<td>$cell</td>');
               }
            }
            sb.writeln('</tr>');
            r++;
            i++;
          }
          sb.writeln('</table>');
          i--;
          continue;
        }

        if (line.startsWith('<h') || line.startsWith('<hr') || line.startsWith('<li') || line.startsWith('<div') || line.startsWith('<table')) {
          sb.writeln(line);
        } else {
          sb.writeln('<p>$line</p>');
        }
      }

      final bodyContent = sb.toString();

      final docHtml = '''
<html xmlns:o="urn:schemas-microsoft-com:office:office"
      xmlns:w="urn:schemas-microsoft-com:office:word"
      xmlns="http://www.w3.org/TR/REC-html40">
<head>
<meta charset="utf-8">
<title>$title</title>
<style>
  body { font-family: 'Calibri', 'Arial', sans-serif; font-size: 11.5pt; color: #000000; }
  h1 { color: #2F5496; font-size: 20pt; border-bottom: 2px solid #2F5496; padding-bottom: 6px; margin-bottom: 16px; margin-top: 10px; }
  h2 { color: #2F5496; font-size: 16pt; margin-top: 24px; margin-bottom: 10px; }
  h3 { color: #1F3763; font-size: 14pt; margin-top: 20px; margin-bottom: 8px; }
  p { line-height: 1.5; margin-bottom: 12px; margin-top: 0; }
  strong { font-weight: bold; }
  em { font-style: italic; }
  hr { border: 0; border-bottom: 1px solid #E0E0E0; margin: 24px 0; }
</style>
</head>
<body>
$bodyContent
</body>
</html>
''';

      String? dirPath;

      if (!kIsWeb) {
        try {
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
            final home = Platform.environment['USERPROFILE'] ??
                Platform.environment['HOME'] ??
                '';
            final downloadsDir = Directory('$home${Platform.pathSeparator}Downloads');
            if (await downloadsDir.exists()) {
              dirPath = downloadsDir.path;
            }
          }
        } catch (_) {}

        if (dirPath == null) {
          final docsDir = await getApplicationDocumentsDirectory();
          dirPath = docsDir.path;
        }

        final filePath = '$dirPath${Platform.pathSeparator}$fileName';

        final file = File(filePath);
        await file.writeAsString(docHtml);

        return file.path;
      } else {
        // Trigger web browser download
        final bytes = utf8.encode(docHtml);
        downloadFileWeb(fileName, Uint8List.fromList(bytes));
        return 'Downloads folder';
      }
    } catch (e) {
      debugPrint('Export error: $e');
      return null;
    }
  }

  /// Generate PDF bytes from markdown content
  static Future<List<int>> _generatePdf(String title, String markdown) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(),
    );

    // Parse markdown into styled widgets
    final contentWidgets = _parseMarkdownToPdfWidgets(markdown);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(title, context),
        footer: (context) => _buildFooter(context),
        build: (context) => contentWidgets,
      ),
    );

    return await pdf.save();
  }

  /// Build PDF header
  static pw.Widget _buildHeader(String title, pw.Context context) {
    if (context.pageNumber == 1) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColor.fromInt(0xFF6C63FF),
                  width: 2,
                ),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title.replaceAll('_', ' '),
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF6C63FF),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generated by DeepTutor • ${DateTime.now().toString().split('.')[0]}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromInt(0xFF9E97B8),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
        ],
      );
    }
    return pw.SizedBox.shrink();
  }

  /// Build PDF footer
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColor.fromInt(0xFFDDDDDD), width: 0.5),
        ),
      ),
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'DeepTutor — AI-Powered Learning Assistant',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColor.fromInt(0xFF999999),
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColor.fromInt(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }

  /// Parse markdown text into PDF widgets
  static List<pw.Widget> _parseMarkdownToPdfWidgets(String markdown) {
    final widgets = <pw.Widget>[];
    final lines = markdown.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        continue;
      }

      // Horizontal rule
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColor.fromInt(0xFFCCCCCC),
                  width: 0.5,
                ),
              ),
            ),
          ),
        );
        continue;
      }

      // Headers
      if (trimmed.startsWith('### ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.Text(
            _stripInlineMarkdown(trimmed.substring(4)),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF00A0CC),
            ),
          ),
        ));
        continue;
      }
      if (trimmed.startsWith('## ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
          child: pw.Text(
            _stripInlineMarkdown(trimmed.substring(3)),
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF7C3DB3),
            ),
          ),
        ));
        continue;
      }
      if (trimmed.startsWith('# ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
          child: pw.Text(
            _stripInlineMarkdown(trimmed.substring(2)),
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF4A40CC),
            ),
          ),
        ));
        continue;
      }

      // Bullet points
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 16, bottom: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 5,
                height: 5,
                margin: const pw.EdgeInsets.only(top: 5, right: 8),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF6C63FF),
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.Expanded(
                child: _buildRichText(trimmed.substring(2)),
              ),
            ],
          ),
        ));
        continue;
      }

      // Numbered list
      final numMatch = RegExp(r'^(\d+)\.\s+(.+)$').firstMatch(trimmed);
      if (numMatch != null) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 16, bottom: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 20,
                margin: const pw.EdgeInsets.only(right: 6),
                child: pw.Text(
                  '${numMatch.group(1)}.',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF6C63FF),
                  ),
                ),
              ),
              pw.Expanded(
                child: _buildRichText(numMatch.group(2)!),
              ),
            ],
          ),
        ));
        continue;
      }

      // Code block (```...```)
      if (trimmed.startsWith('```')) {
        final codeLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        if (codeLines.isNotEmpty) {
          widgets.add(pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.symmetric(vertical: 6),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF5F5F5),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(
                color: const PdfColor.fromInt(0xFFDDDDDD),
              ),
            ),
            child: pw.Text(
              codeLines.join('\n'),
              style: pw.TextStyle(
                font: pw.Font.courier(),
                fontSize: 9,
                color: const PdfColor.fromInt(0xFF333333),
              ),
            ),
          ));
        }
        continue;
      }

      // Table support
      if (trimmed.startsWith('|') && trimmed.endsWith('|') && trimmed.contains('|', 1)) {
        final tableLines = <String>[];
        int j = i;
        while (j < lines.length && lines[j].trim().startsWith('|')) {
          tableLines.add(lines[j].trim());
          j++;
        }
        i = j - 1; 
        
        final rows = <pw.TableRow>[];
        for (int r = 0; r < tableLines.length; r++) {
          final rowLine = tableLines[r];
          if (RegExp(r'^\|[\s\-\:]+\|').hasMatch(rowLine)) continue;
          
          final cells = rowLine.split('|').map((c) => c.trim()).toList();
          if (cells.isNotEmpty) cells.removeAt(0); 
          if (cells.isNotEmpty && rowLine.endsWith('|')) cells.removeLast(); 
          
          final isHeader = r == 0;
          rows.add(pw.TableRow(
            decoration: isHeader ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0F0FF)) : null,
            children: cells.map((c) => pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: _buildRichText(isHeader ? '**$c**' : c),
            )).toList(),
          ));
        }

        if (rows.isNotEmpty) {
          widgets.add(pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Table(
               border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCCCCCC), width: 0.5),
               children: rows,
            ),
          ));
        }
        continue;
      }
      
      // Image support
      final imgMatch = RegExp(r'^!\[([^\]]*)\]\(([^\)]+)\)$').firstMatch(trimmed);
      if (imgMatch != null) {
         widgets.add(pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 6),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: const PdfColor.fromInt(0xFFDDDDDD)), color: const PdfColor.fromInt(0xFFF9F9F9)),
            child: pw.UrlLink(
               destination: imgMatch.group(2)!,
               child: pw.Text('View Image attached: ${imgMatch.group(1)}', style: const pw.TextStyle(color: PdfColor.fromInt(0xFF0066CC), decoration: pw.TextDecoration.underline, fontSize: 11))
            )
         ));
         continue;
      }

      // Regular paragraph
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: _buildRichText(trimmed),
      ));
    }

    return widgets;
  }

  /// Build rich text with bold/italic support
  static pw.Widget _buildRichText(String text) {
    final spans = <pw.InlineSpan>[];
    final parts = text.split(RegExp(r'(\*\*.*?\*\*|\*.*?\*|`[^`]+`)'));

    for (final part in parts) {
      if (part.startsWith('**') && part.endsWith('**')) {
        spans.add(pw.TextSpan(
          text: part.substring(2, part.length - 2),
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 11,
            color: const PdfColor.fromInt(0xFF222222),
          ),
        ));
      } else if (part.startsWith('*') && part.endsWith('*') && part.length > 2) {
        spans.add(pw.TextSpan(
          text: part.substring(1, part.length - 1),
          style: pw.TextStyle(
            fontStyle: pw.FontStyle.italic,
            fontSize: 11,
            color: const PdfColor.fromInt(0xFF555555),
          ),
        ));
      } else if (part.startsWith('`') && part.endsWith('`')) {
        spans.add(pw.TextSpan(
          text: part.substring(1, part.length - 1),
          style: pw.TextStyle(
            font: pw.Font.courier(),
            fontSize: 10,
            color: const PdfColor.fromInt(0xFF0099BB),
          ),
        ));
      } else if (part.isNotEmpty) {
        spans.add(pw.TextSpan(
          text: part,
          style: const pw.TextStyle(
            fontSize: 11,
            color: PdfColor.fromInt(0xFF333333),
          ),
        ));
      }
    }

    if (spans.isEmpty) {
      return pw.Text(
        text,
        style: const pw.TextStyle(
          fontSize: 11,
          color: PdfColor.fromInt(0xFF333333),
          lineSpacing: 4,
        ),
      );
    }

    return pw.RichText(
      text: pw.TextSpan(children: spans),
    );
  }

  /// Strip markdown formatting for plain text
  static String _stripInlineMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1');
  }
}
