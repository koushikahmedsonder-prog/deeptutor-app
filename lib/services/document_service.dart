import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'file_reader_native.dart'
    if (dart.library.html) 'file_reader_web.dart' as file_io;

class DocumentService {
  /// Check if camera is available (mobile only, never on web)
  bool get isCameraAvailable => !kIsWeb;

  // Max file size: 15MB — prevents OOM on phones
  static const _maxFileSizeBytes = 15 * 1024 * 1024;

  /// Pick document files (PDF, TXT, MD, images)
  Future<PickedDocument?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'txt', 'md', 'doc', 'docx',
        'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp',
      ],
      withData: true, // Always get bytes for reliable reading
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    
    // Guard against huge files that would crash the phone
    if (file.size > _maxFileSizeBytes) {
      return PickedDocument(
        path: file.path ?? file.name,
        name: file.name,
        type: _getDocumentType(file.extension ?? ''),
        size: file.size,
        bytes: null, // Don't load bytes for oversized files
      );
    }

    final path = file.path ?? file.name;

    return PickedDocument(
      path: path,
      name: file.name,
      type: _getDocumentType(file.extension ?? ''),
      size: file.size,
      bytes: file.bytes,
    );
  }

  /// Pick multiple documents
  Future<List<PickedDocument>> pickMultipleDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'txt', 'md', 'doc', 'docx',
        'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp',
      ],
      allowMultiple: true,
      withData: true,
    );

    if (result == null) return [];

    // Filter out files that are too large (>15MB) to prevent crash
    return result.files
        .where((f) => f.size <= _maxFileSizeBytes)
        .map((f) => PickedDocument(
              path: f.path ?? f.name,
              name: f.name,
              type: _getDocumentType(f.extension ?? ''),
              size: f.size,
              bytes: f.bytes,
            ))
        .toList();
  }

  /// Pick image files only (compressed to prevent OOM crash)
  Future<PickedDocument?> pickImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70,
      );
      
      if (file == null) return null;
      
      final bytes = await file.readAsBytes();
      return PickedDocument(
        path: file.path,
        name: file.name,
        type: DocumentType.image,
        size: bytes.length,
        bytes: bytes,
      );
    } catch (e) {
      // Fallback to FilePicker if ImagePicker fails
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.single;
      return PickedDocument(
        path: file.path ?? file.name,
        name: file.name,
        type: DocumentType.image,
        size: file.size,
        bytes: file.bytes,
      );
    }
  }

  /// Take a photo using the device camera (compressed to prevent OOM crash)
  Future<PickedDocument?> takePhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,       // Downscale to 1280px wide max
        maxHeight: 1280,      // Downscale to 1280px tall max
        imageQuality: 70,     // JPEG quality 70% — great for text recognition
      );
      
      if (file == null) return null;
      
      final bytes = await file.readAsBytes();
      final size = bytes.length;
      
      return PickedDocument(
        path: file.path,
        name: file.name,
        type: DocumentType.image,
        size: size,
        bytes: bytes,
      );
    } catch (e) {
      // Fallback if camera is unavailable (e.g., Windows Desktop without delegates)
      return await pickImage();
    }
  }

  DocumentType _getDocumentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return DocumentType.pdf;
      case 'txt':
      case 'md':
        return DocumentType.text;
      case 'doc':
      case 'docx':
        return DocumentType.doc;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'bmp':
      case 'webp':
        return DocumentType.image;
      default:
        return DocumentType.other;
    }
  }
}

enum DocumentType { pdf, text, image, doc, other }

class PickedDocument {
  final String path;
  final String name;
  final DocumentType type;
  final int? size;
  final Uint8List? bytes; // Available when withData: true

  PickedDocument({
    required this.path,
    required this.name,
    required this.type,
    this.size,
    this.bytes,
  });

  String get sizeFormatted {
    if (size == null) return 'Unknown';
    if (size! < 1024) return '${size}B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)}KB';
    return '${(size! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get icon {
    switch (type) {
      case DocumentType.pdf:
        return '📄';
      case DocumentType.text:
        return '📝';
      case DocumentType.image:
        return '🖼️';
      case DocumentType.doc:
        return '📋';
      case DocumentType.other:
        return '📎';
    }
  }

  /// Read text content from the file
  Future<String> readContent() async {
    // ── 1. Try in-memory bytes first (most reliable, works everywhere) ──
    if (bytes != null && bytes!.isNotEmpty) {
      if (type == DocumentType.pdf) {
        return await compute(_extractTextFromPdfBytesIsolated, bytes!);
      }
      if (type == DocumentType.image) {
        final base64Image = base64Encode(bytes!);
        final ext = name.split('.').last.toLowerCase();
        final mimeType = ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'image/$ext';
        return '[BASE64_IMAGE:$mimeType:$base64Image]';
      }
      if (type == DocumentType.doc) {
        if (name.toLowerCase().endsWith('.doc')) {
          return '[Legacy Document: $name. Please convert to .docx, .txt, or .pdf to read its contents.]';
        }
        final extracted = await compute(_extractTextFromDocxIsolated, bytes!);
        if (extracted.startsWith('[Binary file Error')) {
          return '[Binary file: $name. Error: $extracted]';
        }
        return extracted;
      }
      try {
        return await compute(_decodeTextBytesIsolated, bytes!);
      } catch (_) {
        return '[Binary file: $name]';
      }
    }

    // ── 2. Fallback: Read from file system on native ──
    if (!kIsWeb) {
      try {
        if (type == DocumentType.pdf) {
          final fileBytes = await file_io.readFileAsBytes(path);
          if (fileBytes != null) {
            return await compute(_extractTextFromPdfBytesIsolated, fileBytes);
          }
        }
        if (type == DocumentType.image) {
          // Native file fallback (if bytes aren't pre-loaded)
          final fileBytes = await file_io.readFileAsBytes(path);
          if (fileBytes != null) {
            final base64Image = base64Encode(fileBytes);
            final ext = name.split('.').last.toLowerCase();
            final mimeType = ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'image/$ext';
            return '[BASE64_IMAGE:$mimeType:$base64Image]';
          }
          return '[Image file: $name — could not read file]';
        }
        final content = await file_io.readFileAsString(path);
        if (content != null) return content;
      } catch (_) {}
    }

    return '[Could not read file: $name]';
  }
}

// ─────────────────────────────────────────────
// TOP LEVEL ISOLATE FUNCTIONS (For Heavy Computation)
// ─────────────────────────────────────────────

/// Proper PDF text extraction using syncfusion_flutter_pdf
String _extractTextFromPdfBytesIsolated(Uint8List pdfBytes) {
  try {
    final document = PdfDocument(inputBytes: pdfBytes);
    final extractor = PdfTextExtractor(document);
    final text = extractor.extractText();
    document.dispose();
    
    if (text.trim().isEmpty) {
        return '[PDF file appears to be image-based/scanned. Use Analyze with AI to process images directly.]';
    }
    return text;
  } catch (e) {
    return '[PDF file — could not extract text: $e]';
  }
}

String _extractTextFromDocxIsolated(Uint8List docxBytes) {
  try {
    return docxToText(docxBytes);
  } catch (e) {
    return '[Binary file Error: $e]';
  }
}

/// Decode text bytes handling UTF-8 and Latin-1 fallback
String _decodeTextBytesIsolated(Uint8List bytes) {
  try {
    // Try UTF-8 first
    return String.fromCharCodes(bytes);
  } catch (_) {
    // Fallback: filter to printable ASCII/Latin-1
    final buffer = StringBuffer();
    for (final byte in bytes) {
      if (byte >= 32 && byte < 127 || byte == 10 || byte == 13 || byte == 9) {
        buffer.writeCharCode(byte);
      }
    }
    final result = buffer.toString().trim();
    if (result.isEmpty) return '[Binary file]';
    return result;
  }
}
