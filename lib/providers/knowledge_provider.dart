import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_provider.dart';
import '../services/document_service.dart';

// ── Knowledge Base State ──
class KnowledgeState {
  final List<Map<String, dynamic>> knowledgeBases;
  final bool isLoading;
  final String? error;
  final String? selectedKb;
  final double uploadProgress;
  final bool isUploading;

  const KnowledgeState({
    this.knowledgeBases = const [],
    this.isLoading = false,
    this.error,
    this.selectedKb,
    this.uploadProgress = 0,
    this.isUploading = false,
  });

  KnowledgeState copyWith({
    List<Map<String, dynamic>>? knowledgeBases,
    bool? isLoading,
    String? error,
    String? selectedKb,
    bool clearSelectedKb = false,
    double? uploadProgress,
    bool? isUploading,
  }) {
    return KnowledgeState(
      knowledgeBases: knowledgeBases ?? this.knowledgeBases,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedKb: clearSelectedKb ? null : (selectedKb ?? this.selectedKb),
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isUploading: isUploading ?? this.isUploading,
    );
  }
}

// ── Knowledge Notifier (Local Storage) ──
class KnowledgeNotifier extends Notifier<KnowledgeState> {
  static const _kbListKey = 'local_kb_list';
  static const _kbDocsPrefix = 'local_kb_docs_';
  static const _kbContentPrefix = 'local_kb_content_';

  @override
  KnowledgeState build() {
    // Load on first access
    Future.microtask(() => loadKnowledgeBases());
    return const KnowledgeState();
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  /// Load all KBs from local storage
  Future<void> loadKnowledgeBases() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final kbListJson = _prefs.getStringList(_kbListKey) ?? [];
      final kbs = kbListJson
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
      state = state.copyWith(knowledgeBases: kbs, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load: $e');
    }
  }

  /// Create a new KB locally
  Future<bool> createKnowledgeBase(String name) async {
    try {
      final kbListJson = _prefs.getStringList(_kbListKey) ?? [];
      final existing = kbListJson
          .map((j) => jsonDecode(j) as Map<String, dynamic>)
          .toList();

      // Check for duplicate
      if (existing.any((kb) => kb['name'] == name)) {
        state = state.copyWith(error: 'Knowledge base "$name" already exists');
        return false;
      }

      final newKb = {
        'name': name,
        'doc_count': 0,
        'documents': <String>[],
        'created_at': DateTime.now().toIso8601String(),
      };

      existing.add(newKb);
      await _prefs.setStringList(
        _kbListKey,
        existing.map((kb) => jsonEncode(kb)).toList(),
      );
      await loadKnowledgeBases();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Upload a picked document — reads content from PickedDocument
  Future<bool> uploadPickedDocument(
      String kbName, PickedDocument doc) async {
    state = state.copyWith(isUploading: true, uploadProgress: 0);
    try {
      state = state.copyWith(uploadProgress: 0.3);

      // Read content from the picked document
      String content = await doc.readContent();

      state = state.copyWith(uploadProgress: 0.6);

      // Store the document content
      final docsKey = '$_kbDocsPrefix$kbName';
      final contentKey = '$_kbContentPrefix${kbName}_${doc.name}';

      final existingDocs = _prefs.getStringList(docsKey) ?? [];
      if (!existingDocs.contains(doc.name)) {
        existingDocs.add(doc.name);
        await _prefs.setStringList(docsKey, existingDocs);
      }

      await _prefs.setString(contentKey, content);

      state = state.copyWith(uploadProgress: 0.9);

      // Update KB metadata
      final kbListJson = _prefs.getStringList(_kbListKey) ?? [];
      final kbs = kbListJson
          .map((j) => jsonDecode(j) as Map<String, dynamic>)
          .toList();
      final kbIndex = kbs.indexWhere((kb) => kb['name'] == kbName);
      if (kbIndex != -1) {
        kbs[kbIndex]['doc_count'] = existingDocs.length;
        kbs[kbIndex]['documents'] = existingDocs;
        await _prefs.setStringList(
          _kbListKey,
          kbs.map((kb) => jsonEncode(kb)).toList(),
        );
      }

      state = state.copyWith(isUploading: false, uploadProgress: 1.0);
      await loadKnowledgeBases();
      return true;
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
      return false;
    }
  }

  /// Upload document content directly (text)
  Future<bool> uploadDocumentContent(
      String kbName, String fileName, String content) async {
    state = state.copyWith(isUploading: true, uploadProgress: 0);
    try {
      state = state.copyWith(uploadProgress: 0.5);

      final docsKey = '$_kbDocsPrefix$kbName';
      final contentKey = '$_kbContentPrefix${kbName}_$fileName';

      final existingDocs = _prefs.getStringList(docsKey) ?? [];
      if (!existingDocs.contains(fileName)) {
        existingDocs.add(fileName);
        await _prefs.setStringList(docsKey, existingDocs);
      }

      await _prefs.setString(contentKey, content);

      // Update KB metadata
      final kbListJson = _prefs.getStringList(_kbListKey) ?? [];
      final kbs = kbListJson
          .map((j) => jsonDecode(j) as Map<String, dynamic>)
          .toList();
      final kbIndex = kbs.indexWhere((kb) => kb['name'] == kbName);
      if (kbIndex != -1) {
        kbs[kbIndex]['doc_count'] = existingDocs.length;
        kbs[kbIndex]['documents'] = existingDocs;
        await _prefs.setStringList(
          _kbListKey,
          kbs.map((kb) => jsonEncode(kb)).toList(),
        );
      }

      state = state.copyWith(isUploading: false, uploadProgress: 1.0);
      await loadKnowledgeBases();
      return true;
    } catch (e) {
      state = state.copyWith(isUploading: false, error: e.toString());
      return false;
    }
  }

  /// Get combined content of all documents in a KB
  String getKnowledgeBaseContent(String kbName) {
    final docsKey = '$_kbDocsPrefix$kbName';
    final docs = _prefs.getStringList(docsKey) ?? [];
    final buffer = StringBuffer();

    for (final doc in docs) {
      final contentKey = '$_kbContentPrefix${kbName}_$doc';
      final content = _prefs.getString(contentKey) ?? '';
      if (content.isNotEmpty) {
        buffer.writeln('--- Document: $doc ---');
        buffer.writeln(content);
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Get list of documents in a KB
  List<String> getDocuments(String kbName) {
    final docsKey = '$_kbDocsPrefix$kbName';
    return _prefs.getStringList(docsKey) ?? [];
  }

  void selectKnowledgeBase(String? kbName) {
    if (kbName == null) {
      state = state.copyWith(clearSelectedKb: true);
    } else {
      state = state.copyWith(selectedKb: kbName);
    }
  }

  Future<void> deleteKnowledgeBase(String kbName) async {
    try {
      // Remove documents
      final docsKey = '$_kbDocsPrefix$kbName';
      final docs = _prefs.getStringList(docsKey) ?? [];
      for (final doc in docs) {
        await _prefs.remove('$_kbContentPrefix${kbName}_$doc');
      }
      await _prefs.remove(docsKey);

      // Remove from list
      final kbListJson = _prefs.getStringList(_kbListKey) ?? [];
      final kbs = kbListJson
          .map((j) => jsonDecode(j) as Map<String, dynamic>)
          .toList();
      kbs.removeWhere((kb) => kb['name'] == kbName);
      await _prefs.setStringList(
        _kbListKey,
        kbs.map((kb) => jsonEncode(kb)).toList(),
      );

      if (state.selectedKb == kbName) {
        state = state.copyWith(clearSelectedKb: true);
      }

      await loadKnowledgeBases();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// ── Provider ──
final knowledgeProvider =
    NotifierProvider<KnowledgeNotifier, KnowledgeState>(KnowledgeNotifier.new);
