import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/app_theme.dart';
import '../services/document_service.dart';

class DocUploadSheet extends StatelessWidget {
  final void Function(PickedDocument document) onDocumentPicked;

  const DocUploadSheet({
    super.key,
    required this.onDocumentPicked,
  });

  @override
  Widget build(BuildContext context) {
    final docService = DocumentService();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppTheme.cardBorder),
          left: BorderSide(color: AppTheme.cardBorder),
          right: BorderSide(color: AppTheme.cardBorder),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const Text(
            'Upload Document',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose how to add your document',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Pick file option
          _UploadOption(
            icon: Icons.description_rounded,
            title: 'Pick File',
            subtitle: 'PDF, TXT, MD, DOC files',
            color: AppTheme.accentIndigo,
            index: 0,
            onTap: () async {
              final doc = await docService.pickDocument();
              if (doc != null && context.mounted) {
                Navigator.pop(context);
                onDocumentPicked(doc);
              }
            },
          ),
          const SizedBox(height: 12),

          // Pick multiple files
          _UploadOption(
            icon: Icons.folder_open_rounded,
            title: 'Pick Multiple Files',
            subtitle: 'Upload several documents at once',
            color: AppTheme.accentCyan,
            index: 1,
            onTap: () async {
              final docs = await docService.pickMultipleDocuments();
              if (docs.isNotEmpty && context.mounted) {
                Navigator.pop(context);
                // Upload the first one for now, the caller can handle multiple
                onDocumentPicked(docs.first);
              }
            },
          ),
          
          if (docService.isCameraAvailable) ...[
            const SizedBox(height: 12),
            // Take Photo option
            _UploadOption(
              icon: Icons.camera_alt_rounded,
              title: 'Take Photo',
              subtitle: 'Use camera to scan a document',
              color: AppTheme.accentOrange,
              index: 2,
              onTap: () async {
                final doc = await docService.takePhoto();
                if (doc != null && context.mounted) {
                  Navigator.pop(context);
                  onDocumentPicked(doc);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _UploadOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final int index;
  final VoidCallback onTap;

  const _UploadOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
            color: color.withValues(alpha: 0.05),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: (100 * index).ms)
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.1, end: 0, duration: 300.ms);
  }
}
