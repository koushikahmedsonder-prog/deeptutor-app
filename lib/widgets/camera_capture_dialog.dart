import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/document_service.dart';

/// Shows a live camera preview dialog and returns a [PickedDocument] on capture,
/// or null if cancelled. Works on Windows, Android, and iOS.
Future<PickedDocument?> showCameraCapture(BuildContext context) async {
  try {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      // No camera — fall back to image picker
      return DocumentService().pickImage();
    }
    if (!context.mounted) return null;
    return showDialog<PickedDocument>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CameraCaptureDialog(cameras: cameras),
    );
  } on CameraException {
    // Windows with no camera hardware or driver issue → use file picker
    return DocumentService().pickImage();
  }
}

class _CameraCaptureDialog extends StatefulWidget {
  final List<CameraDescription> cameras;
  const _CameraCaptureDialog({required this.cameras});

  @override
  State<_CameraCaptureDialog> createState() => _CameraCaptureDialogState();
}

class _CameraCaptureDialogState extends State<_CameraCaptureDialog> {
  late CameraController _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  int _cameraIndex = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _controller = CameraController(
        widget.cameras[_cameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2) return;
    setState(() => _isInitialized = false);
    await _controller.dispose();
    _cameraIndex = (_cameraIndex + 1) % widget.cameras.length;
    await _initCamera();
  }

  Future<void> _capture() async {
    if (!_isInitialized || _isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final xFile = await _controller.takePicture();
      final bytes = await xFile.readAsBytes();
      final size = await File(xFile.path).length();
      final doc = PickedDocument(
        path: xFile.path,
        name: 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        type: DocumentType.image,
        size: size,
        bytes: bytes,
      );
      if (mounted) Navigator.of(context).pop(doc);
    } catch (e) {
      if (mounted) setState(() { _isCapturing = false; _error = e.toString(); });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
              child: Row(
                children: [
                  const Icon(Icons.camera_alt_rounded, color: AppTheme.accentCyan, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Take Photo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const Spacer(),
                  if (widget.cameras.length > 1)
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios_rounded, color: AppTheme.textSecondary),
                      tooltip: 'Switch camera',
                      onPressed: _switchCamera,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
            ),

            // Camera preview
            Flexible(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: _error != null
                    ? _ErrorView(error: _error!)
                    : !_isInitialized
                        ? const _LoadingView()
                        : Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              // Preview fills available space
                              AspectRatio(
                                aspectRatio: _controller.value.aspectRatio,
                                child: CameraPreview(_controller),
                              ),

                              // Capture button overlay
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: GestureDetector(
                                  onTap: _capture,
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.15),
                                      border: Border.all(color: Colors.white, width: 3),
                                    ),
                                    child: _isCapturing
                                        ? const Padding(
                                            padding: EdgeInsets.all(20),
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Icon(Icons.camera, color: Colors.white, size: 32),
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 300,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.accentCyan),
          SizedBox(height: 16),
          Text('Initializing camera...', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 200,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, color: AppTheme.accentOrange, size: 40),
            const SizedBox(height: 12),
            const Text('Camera not available', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            Text(error, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
