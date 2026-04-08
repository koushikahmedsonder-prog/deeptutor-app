import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ExportService {

  // ─── 1. EXPORT AS PDF ──────────────────────────────────────
  static Future<void> exportAsPdf({
    required String title,
    required List<ExportSlide> slides,
  }) async {
    final pdf = pw.Document();

    for (final slide in slides) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Title
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.indigo700,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  slide.title,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Bullet points
              ...slide.bulletPoints.map((point) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('- ',
                        style: pw.TextStyle(
                            color: PdfColors.indigo700, fontSize: 14)),
                    pw.Expanded(
                      child: pw.Text(point,
                          style: const pw.TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              )),

              // Image if exists
              if (slide.imageBytes != null) ...[
                pw.SizedBox(height: 16),
                pw.Image(
                  pw.MemoryImage(slide.imageBytes!),
                  height: 200,
                  fit: pw.BoxFit.contain,
                ),
              ],

              // Key term box
              if (slide.keyTerm != null && slide.keyTerm!.isNotEmpty)
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 16),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.indigo300),
                    borderRadius: pw.BorderRadius.circular(6),
                    color: PdfColors.indigo50,
                  ),
                  child: pw.Text(
                    '* ${slide.keyTerm}',
                    style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.indigo900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Save and share
    final bytes = await pdf.save();
    await _saveAndShare(bytes, '${title}_presentation.pdf', 'application/pdf');
  }

  // ─── 2. EXPORT AS PPTX ─────────────────────────────────────
  static Future<void> exportAsPptx({
    required String title,
    required List<ExportSlide> slides,
  }) async {
    // dart_pptx is discontinued and its API doesn't match. As a fallback,
    // we generate a landscape PDF presentation that looks like slides instead.
    final pdf = pw.Document();

    for (int i = 0; i < slides.length; i++) {
      final slide = slides[i];
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape, 
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange700,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  slide.title,
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(height: 32),
              ...slide.bulletPoints.map((point) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('- ',
                        style: pw.TextStyle(
                            color: PdfColors.orange700, fontSize: 18)),
                    pw.Expanded(
                      child: pw.Text(point,
                          style: const pw.TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              )),
              if (slide.keyTerm != null && slide.keyTerm!.isNotEmpty)
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 24),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.orange300),
                    borderRadius: pw.BorderRadius.circular(6),
                    color: PdfColors.orange50,
                  ),
                  child: pw.Text(
                    '* ${slide.keyTerm}',
                    style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.orange900,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final bytes = await pdf.save();
    // Share as PDF instead of PPTX for now
    await _saveAndShare(bytes, '${title}_slides.pdf', 'application/pdf');
  }

  // ─── 3. EXPORT FLASHCARDS AS PDF ───────────────────────────
  static Future<void> exportFlashcards({
    required String title,
    required List<Flashcard> flashcards,
  }) async {
    final pdf = pw.Document();

    // 2 flashcards per page
    for (int i = 0; i < flashcards.length; i += 2) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => pw.Column(
            children: [
              _buildFlashcardWidget(flashcards[i]),
              pw.SizedBox(height: 16),
              if (i + 1 < flashcards.length)
                _buildFlashcardWidget(flashcards[i + 1]),
            ],
          ),
        ),
      );
    }

    final bytes = await pdf.save();
    await _saveAndShare(bytes, '${title}_flashcards.pdf', 'application/pdf');
  }

  static pw.Widget _buildFlashcardWidget(Flashcard card) {
    return pw.Container(
      height: 180,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.indigo400, width: 2),
        borderRadius: pw.BorderRadius.circular(12),
        color: PdfColors.white,
      ),
      child: pw.Row(
        children: [
          // Front (question)
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: const pw.BoxDecoration(
                color: PdfColors.indigo700,
                borderRadius: pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(10),
                  bottomLeft: pw.Radius.circular(10),
                ),
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('QUESTION',
                      style: pw.TextStyle(
                          color: PdfColors.indigo100,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text(card.question,
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 13),
                      textAlign: pw.TextAlign.center),
                ],
              ),
            ),
          ),
          // Back (answer)
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(16),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('ANSWER',
                      style: pw.TextStyle(
                          color: PdfColors.indigo400,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text(card.answer,
                      style: const pw.TextStyle(fontSize: 12),
                      textAlign: pw.TextAlign.center),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4. EXPORT MIND MAP AS PDF ─────────────────────────────
  static Future<void> exportMindMap({
    required String title,
    required MindMapData mindMap,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Center topic
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.indigo700,
                  borderRadius: pw.BorderRadius.circular(30),
                ),
                child: pw.Text(
                  mindMap.centralTopic,
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
            pw.SizedBox(height: 24),

            // Branches in a grid
            pw.Wrap(
              spacing: 16,
              runSpacing: 16,
              children: mindMap.branches.map((branch) {
                return pw.Container(
                  width: 180,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.indigo300),
                    borderRadius: pw.BorderRadius.circular(8),
                    color: PdfColors.indigo50,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(branch.title,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.indigo800,
                              fontSize: 12)),
                      pw.SizedBox(height: 6),
                      ...branch.children.map((child) => pw.Text(
                            '  - $child',
                            style: const pw.TextStyle(fontSize: 10),
                          )),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    await _saveAndShare(bytes, '${title}_mindmap.pdf', 'application/pdf');
  }

  // ─── SAVE & SHARE HELPER ───────────────────────────────────
  static Future<void> _saveAndShare(
      Uint8List bytes, String filename, String mimeType) async {
    if (Platform.isWindows) {
      // On Windows: save to Downloads folder and open it natively
      final downloadsPath = '${Platform.environment['USERPROFILE']}\\Downloads';
      final file = File('$downloadsPath\\$filename');
      if (await file.exists()) {
        await file.delete();
      }
      await file.writeAsBytes(bytes);
      
      // Open the file automatically
      await Process.run('explorer', [file.path]);
      return;
    }

    // Map other platforms
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    // Ensure filename is unique or cleanly written by deleting an existing one
    if (await file.exists()) {
      await file.delete();
    }
    await file.writeAsBytes(bytes);

    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      subject: filename,
    );
  }
}

// ─── DATA MODELS ───────────────────────────────────────────────

class ExportSlide {
  final String title;
  final List<String> bulletPoints;
  final Uint8List? imageBytes;
  final String? keyTerm;

  ExportSlide({
    required this.title,
    required this.bulletPoints,
    this.imageBytes,
    this.keyTerm,
  });
}

class Flashcard {
  final String question;
  final String answer;
  Flashcard({required this.question, required this.answer});
}

class MindMapData {
  final String centralTopic;
  final List<MindMapBranch> branches;
  MindMapData({required this.centralTopic, required this.branches});
}

class MindMapBranch {
  final String title;
  final List<String> children;
  MindMapBranch({required this.title, required this.children});
}
