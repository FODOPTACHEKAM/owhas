import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/face_recognition_service.dart';

/// Returned by [FaceCapturePage] on success.
/// The captured image is deleted immediately; only the descriptor is kept.
class FaceCaptureResult {
  final List<double> descriptor;
  FaceCaptureResult(this.descriptor);
}

/// Full-screen camera page that captures a selfie, validates that exactly one
/// face is visible, and returns a [FaceCaptureResult] with the face descriptor.
class FaceCapturePage extends StatefulWidget {
  const FaceCapturePage({super.key});

  @override
  State<FaceCapturePage> createState() => _FaceCapturePageState();
}

class _FaceCapturePageState extends State<FaceCapturePage> {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _fatalError;
  String _guide = 'Position your face inside the oval, then tap capture';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _setFatalError('No camera found on this device.');
        return;
      }

      // Prefer front camera for selfie; fall back to first available
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (e) {
      _setFatalError(
        'Camera unavailable. Please grant camera permission in Settings and try again.',
      );
    }
  }

  void _setFatalError(String message) {
    if (!mounted) return;
    setState(() {
      _fatalError = message;
      _isInitializing = false;
    });
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _guide = 'Analysing face…';
    });

    File? tempFile;
    try {
      final xFile = await controller.takePicture();
      tempFile = File(xFile.path);

      final result = await FaceRecognitionService().detectAndDescribe(tempFile);

      if (!mounted) return;

      if (result.error != null) {
        setState(() {
          _isCapturing = false;
          _guide = result.error!;
        });
        return;
      }

      // Success — delete temp file and return descriptor
      try {
        await tempFile.delete();
      } catch (_) {}

      if (mounted) {
        Navigator.pop(context, FaceCaptureResult(result.descriptor!));
      }
    } catch (_) {
      // Clean up temp file on unexpected error
      try {
        await tempFile?.delete();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isCapturing = false;
          _guide = 'Something went wrong. Please try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraLayer(),
          _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraLayer() {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_fatalError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white70, size: 64),
              const SizedBox(height: 16),
              Text(
                _fatalError!,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller != null) {
      return CameraPreview(_controller!);
    }

    return const SizedBox.shrink();
  }

  Widget _buildOverlay() {
    return SafeArea(
      child: Column(
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _IconButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Face Verification',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Oval face guide
          Container(
            width: 210,
            height: 270,
            decoration: BoxDecoration(
              border: Border.all(
                color: _isCapturing ? Colors.orange : Colors.white,
                width: 2.5,
              ),
              borderRadius: BorderRadius.circular(105),
            ),
          ),

          const Spacer(),

          // Guide text + capture button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GuideChip(text: _guide),
                const SizedBox(height: 28),
                _CaptureButton(
                  onTap: (_isCapturing || _fatalError != null || _isInitializing)
                      ? null
                      : _capture,
                  isProcessing: _isCapturing,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small helper widgets
// ---------------------------------------------------------------------------

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _GuideChip extends StatelessWidget {
  final String text;
  const _GuideChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isProcessing;

  const _CaptureButton({required this.onTap, required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 4,
          ),
        ),
        child: isProcessing
            ? const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Icon(Icons.camera_alt, color: Colors.black, size: 32),
      ),
    );
  }
}
