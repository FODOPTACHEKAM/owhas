import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A reusable signature capture widget using CustomPainter.
/// Users draw with their finger/mouse; the result can be exported to PNG bytes.
class SignaturePad extends StatefulWidget {
  final double height;
  final Color penColor;
  final double penStrokeWidth;
  final Color backgroundColor;

  const SignaturePad({
    super.key,
    this.height = 200,
    this.penColor = Colors.black,
    this.penStrokeWidth = 3.0,
    this.backgroundColor = Colors.white,
  });

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  final GlobalKey _repaintKey = GlobalKey();

  /// Clear all drawn strokes.
  void clear() {
    setState(() {
      _strokes.clear();
    });
  }

  /// Export the current signature as PNG bytes.
  /// Returns `null` if the canvas is empty or rendering fails.
  Future<Uint8List?> exportToPng() async {
    if (_strokes.isEmpty) return null;

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  /// Check whether the pad has any drawing.
  bool get isEmpty => _strokes.isEmpty;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _repaintKey,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: GestureDetector(
          onPanStart: (details) {
            setState(() {
              _strokes.add([details.localPosition]);
            });
          },
          onPanUpdate: (details) {
            setState(() {
              _strokes.last.add(details.localPosition);
            });
          },
          child: CustomPaint(
            painter: _SignaturePainter(
              strokes: _strokes,
              penColor: widget.penColor,
              penStrokeWidth: widget.penStrokeWidth,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color penColor;
  final double penStrokeWidth;

  _SignaturePainter({
    required this.strokes,
    required this.penColor,
    required this.penStrokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = penColor
      ..strokeWidth = penStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

