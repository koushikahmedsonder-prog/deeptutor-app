import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'file_reader_native.dart'
    if (dart.library.html) 'file_reader_web.dart' as file_io;

class DocumentService {
  /// Check if camera is available (mobile only, never on web)
  bool get isCameraAvailable => !kIsWeb;

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

    return result.files
        .map((f) => PickedDocument(
              path: f.path ?? f.name,
              name: f.name,
              type: _getDocumentType(f.extension ?? ''),
              size: f.size,
              bytes: f.bytes,
            ))
        .toList();
  }

  /// Pick image files only
  Future<PickedDocument?> pickImage() async {
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

  /// Take a photo using the device camera
  Future<PickedDocument?> takePhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.camera);
      
      if (file == null) return null;
      
      final bytes = await file.readAsBytes();
      final size = await file.length();
      
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
        return _extractTextFromPdfBytes(bytes!);
      }
      if (type == DocumentType.image) {
        return '[Image file: $name — use Analyze with AI for image analysis]';
      }
      if (type == DocumentType.doc) {
        try {
          return docxToText(bytes!);
        } catch (e) {
          return '[Binary file: $name. Error: $e]';
        }
      }
      try {
        return _decodeTextBytes(bytes!);
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
            return _extractTextFromPdfBytes(fileBytes);
          }
        }
        if (type == DocumentType.image) {
          return '[Image file: $name — use Analyze with AI for image analysis]';
        }
        final content = await file_io.readFileAsString(path);
        if (content != null) return content;
      } catch (_) {}
    }

    return '[Could not read file: $name]';
  }

  /// Decode text bytes handling UTF-8 and Latin-1 fallback
  String _decodeTextBytes(Uint8List bytes) {
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
      if (result.isEmpty) return '[Binary file: $name]';
      return result;
    }
  }

  /// Simple PDF text extraction by scanning for readable text streams
  String _extractTextFromPdfBytes(Uint8List pdfBytes) {
    try {
      // Convert bytes to string, filtering non-printable chars
      // PDF stores text between BT/ET markers and in Tj/TJ operators
      final rawStr = String.fromCharCodes(
        pdfBytes.where((b) => b >= 9 && b <= 126),
      );

      final textParts = <String>[];

      // Method 1: Extract text from parentheses in text objects (Tj operator)
      final tjRegex = RegExp(r'\(([^)]*)\)');
      final matches = tjRegex.allMatches(rawStr);

      for (final match in matches) {
        final text = match.group(1) ?? '';
        // Filter out short garbage strings and binary-looking content
        if (text.length > 2 &&
            !text.contains(RegExp(r'[\x00-\x08\x0E-\x1F]')) &&
            text.contains(RegExp(r'[a-zA-Z]'))) {
          // Unescape PDF escape sequences
          final unescaped = text
              .replaceAll(r'\n', '\n')
              .replaceAll(r'\r', '\r')
              .replaceAll(r'\t', '\t')
              .replaceAll(r'\\', '\\')
              .replaceAll(r'\(', '(')
              .replaceAll(r'\)', ')');
          textParts.add(unescaped);
        }
      }

      if (textParts.isNotEmpty) {
        final combined = textParts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        if (combined.length > 50) {
          return combined;
        }
      }

      // Method 2: Look for readable text between stream/endstream markers
      final streamRegex = RegExp(r'stream\s*([\s\S]*?)\s*endstream');
      final streamMatches = streamRegex.allMatches(rawStr);

      final streamTexts = <String>[];
      for (final match in streamMatches) {
        final streamContent = match.group(1) ?? '';
        // Extract text from Tj/TJ operators within streams
        final innerTj = RegExp(r'\(([^)]+)\)');
        for (final tjMatch in innerTj.allMatches(streamContent)) {
          final t = tjMatch.group(1) ?? '';
          if (t.length > 2 && t.contains(RegExp(r'[a-zA-Z]'))) {
            streamTexts.add(t);
          }
        }
      }

      if (streamTexts.isNotEmpty) {
        return streamTexts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      }

      // Method 3: Just pull all readable strings as fallback
      final readableRegex = RegExp('[A-Za-z][A-Za-z0-9 .,;:!?-]{10,}');
      final readableMatches = readableRegex.allMatches(rawStr);
      final readableTexts =
          readableMatches.map((m) => m.group(0)!.trim()).toList();

      if (readableTexts.isNotEmpty) {
        return readableTexts.join('\n').trim();
      }

      return '[PDF file: $name — text extraction limited. Use Analyze with AI to process this document.]';
    } catch (e) {
      return '[PDF file: $name — could not extract text: $e]';
    }
  }
}
