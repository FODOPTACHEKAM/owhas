import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class _FaceData {
  final List<double> descriptor;
  final String studentName;
  _FaceData(this.descriptor, this.studentName);
}

/// Session-scoped in-memory face recognition service.
/// Stores face descriptors only for the active session; cleared on session end.
class FaceRecognitionService {
  static final FaceRecognitionService _instance =
      FaceRecognitionService._internal();
  factory FaceRecognitionService() => _instance;

  FaceRecognitionService._internal() {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: false,
        enableLandmarks: false,
        enableTracking: false,
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  late FaceDetector _detector;

  // sessionId → { matricule → FaceData }
  final Map<String, Map<String, _FaceData>> _sessions = {};

  // Cosine similarity threshold: faces above this are considered the same person
  static const double _threshold = 0.82;

  void clearSession(String sessionId) => _sessions.remove(sessionId);

  void removeFace(String sessionId, String matricule) =>
      _sessions[sessionId]?.remove(matricule);

  /// Detect face in [imageFile] and compute its descriptor.
  /// Returns a named record: descriptor (null on failure) + error message.
  Future<({List<double>? descriptor, String? error})> detectAndDescribe(
    File imageFile,
  ) async {
    try {
      final faces = await _detector.processImage(
        InputImage.fromFilePath(imageFile.path),
      );

      if (faces.isEmpty) {
        return (
          descriptor: null,
          error: 'No face detected. Look directly at the camera.'
        );
      }
      if (faces.length > 1) {
        return (
          descriptor: null,
          error: 'Multiple faces detected. Only one face should be visible.'
        );
      }

      final descriptor = await _buildDescriptor(faces.first, imageFile);
      return (descriptor: descriptor, error: null);
    } catch (_) {
      return (
        descriptor: null,
        error: 'Face processing failed. Please try again.'
      );
    }
  }

  Future<List<double>> _buildDescriptor(Face face, File imageFile) async {
    final descriptor = <double>[];
    final bbox = face.boundingBox;
    final fw = bbox.width.clamp(1.0, double.infinity);
    final fh = bbox.height.clamp(1.0, double.infinity);

    // --- Geometric features from ML Kit contour points ---
    // Each contour is normalized relative to the face bounding box, then
    // padded to a fixed count so the descriptor length is always consistent.
    void addContour(FaceContourType type, int maxPts) {
      final pts = face.contours[type]?.points ?? [];
      final count = min(maxPts, pts.length);
      for (int i = 0; i < count; i++) {
        descriptor.add((pts[i].x - bbox.left) / fw);
        descriptor.add((pts[i].y - bbox.top) / fh);
      }
      for (int i = count; i < maxPts; i++) {
        descriptor..add(0.0)..add(0.0);
      }
    }

    addContour(FaceContourType.face, 36);          // 72 values
    addContour(FaceContourType.leftEye, 16);        // 32 values
    addContour(FaceContourType.rightEye, 16);       // 32 values
    addContour(FaceContourType.noseBridge, 4);      // 8 values
    addContour(FaceContourType.noseBottom, 8);      // 16 values
    addContour(FaceContourType.upperLipTop, 10);    // 20 values
    addContour(FaceContourType.lowerLipBottom, 10); // 20 values
    // Geometric subtotal: 200 values

    // --- Pixel average-hash of face crop ---
    // Resize face crop to 16×16, compute luminance per pixel, then binarize
    // against the mean. This adds 256 texture-based values to the descriptor.
    final bytes = await imageFile.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image != null) {
      image = img.bakeOrientation(image);
      final x = bbox.left.round().clamp(0, image.width - 1);
      final y = bbox.top.round().clamp(0, image.height - 1);
      final w = bbox.width.round().clamp(1, image.width - x);
      final h = bbox.height.round().clamp(1, image.height - y);
      final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);
      final resized = img.copyResize(cropped, width: 16, height: 16);

      final pixels = <double>[];
      double pixelSum = 0;
      for (int py = 0; py < 16; py++) {
        for (int px = 0; px < 16; px++) {
          final p = resized.getPixel(px, py);
          final lum = p.r.toDouble() * 0.299 +
              p.g.toDouble() * 0.587 +
              p.b.toDouble() * 0.114;
          pixels.add(lum);
          pixelSum += lum;
        }
      }
      final avg = pixelSum / pixels.length;
      descriptor.addAll(pixels.map((v) => v >= avg ? 1.0 : 0.0));
    } else {
      descriptor.addAll(List.filled(256, 0.0));
    }

    return descriptor; // Total: 456 values
  }

  /// Returns the matching student's name if a duplicate face is found in the
  /// session, or null if this face is unique and registration can proceed.
  String? findDuplicate(String sessionId, List<double> descriptor) {
    final faces = _sessions[sessionId];
    if (faces == null || faces.isEmpty) return null;
    for (final entry in faces.entries) {
      if (_cosineSimilarity(descriptor, entry.value.descriptor) >= _threshold) {
        return entry.value.studentName;
      }
    }
    return null;
  }

  /// Store a face descriptor for the session after successful registration.
  void storeFace(
    String sessionId,
    String matricule,
    String studentName,
    List<double> descriptor,
  ) {
    _sessions.putIfAbsent(sessionId, () => {})[matricule] =
        _FaceData(descriptor, studentName);
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    final len = min(a.length, b.length);
    if (len == 0) return 0.0;
    double dot = 0, na = 0, nb = 0;
    for (int i = 0; i < len; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    final denom = sqrt(na) * sqrt(nb);
    return denom == 0 ? 0.0 : dot / denom;
  }

  Future<void> close() async => _detector.close();
}
