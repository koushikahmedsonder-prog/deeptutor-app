import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/app_theme.dart';
import '../providers/knowledge_provider.dart';
import '../widgets/doc_upload_sheet.dart';

class KnowledgeScreen extends ConsumerStatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  ConsumerState<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends ConsumerState<KnowledgeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(knowledgeProvider.notifier).loadKnowledgeBases());
  }

  void _showCreateDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Create Knowledge Base',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'e.g. Machine Learning',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final success = await ref
                    .read(knowledgeProvider.notifier)
                    .createKnowledgeBase(name);
                if (ctx.mounted) Navigator.pop(ctx);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('✅ "$name" created!'),
                        backgroundColor: Colors.green.shade800),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _uploadToKB(String kbName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DocUploadSheet(
        onDocumentPicked: (doc) async {
          final content = await doc.readContent();
          final success = await ref
              .read(knowledgeProvider.notifier)
              .uploadDocumentContent(kbName, doc.name, content);

          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ "${doc.name}" added to $kbName!'),
                  backgroundColor: Colors.green.shade800,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ Upload failed')),
              );
            }
          }
        },
      ),
    );
  }

  void _showKBDetail(Map<String, dynamic> kb) {
    final kbName = kb['name']?.toString() ?? 'Unknown';
    final docs = ref.read(knowledgeProvider.notifier).getDocuments(kbName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.folder_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kbName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          )),
                      Text('${docs.length} documents',
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 13,
                          )),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.upload_file_rounded,
                      color: AppTheme.accentCyan),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _uploadToKB(kbName);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.cardBorder),
            const SizedBox(height: 8),
            const Text('Documents',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: docs.isEmpty
                  ? const Center(
                      child: Text('No documents yet. Upload one!',
                          style: TextStyle(color: AppTheme.textTertiary)),
                    )
                  : ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (c, i) {
                        final docName = docs[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.description_rounded,
                                color: AppTheme.accentGreen, size: 18),
                          ),
                          title: Text(docName,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kbState = ref.watch(knowledgeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge Base')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New KB'),
        backgroundColor: AppTheme.accentIndigo,
      ),
      body: kbState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : kbState.knowledgeBases.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open_rounded,
                          size: 64,
                          color: AppTheme.accentViolet
                              .withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text(
                        'No Knowledge Bases yet',
                        style: TextStyle(
                            color: AppTheme.textTertiary, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a KB and upload documents\nto use with AI Solver and Question Gen',
                        style: TextStyle(
                            color: AppTheme.textTertiary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showCreateDialog,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create Knowledge Base'),
                      ),
                    ],
                  ).animate().fadeIn(duration: 600.ms),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: kbState.knowledgeBases.length,
                  itemBuilder: (context, index) {
                    final kb = kbState.knowledgeBases[index];
                    final name = kb['name']?.toString() ?? 'Unknown';
                    final docCount = kb['doc_count'] ?? 0;

                    return GestureDetector(
                      onTap: () => _showKBDetail(kb),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.folder_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      )),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.description_rounded,
                                          size: 14,
                                          color: AppTheme.textTertiary),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$docCount documents',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded,
                                  color: AppTheme.textTertiary),
                              color: AppTheme.surfaceDark,
                              onSelected: (action) {
                                switch (action) {
                                  case 'upload':
                                    _uploadToKB(name);
                                    break;
                                  case 'delete':
                                    ref
                                        .read(knowledgeProvider.notifier)
                                        .deleteKnowledgeBase(name);
                                    break;
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'upload',
                                  child: Row(
                                    children: [
                                      Icon(Icons.upload_file_rounded,
                                          size: 18,
                                          color: AppTheme.accentCyan),
                                      SizedBox(width: 8),
                                      Text('Upload Document',
                                          style: TextStyle(
                                              color:
                                                  AppTheme.textPrimary)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_rounded,
                                          size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete',
                                          style: TextStyle(
                                              color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                        .animate(delay: (80 * index).ms)
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: 0.05, end: 0);
                  },
                ),
    );
  }
}
