import 'package:flutter/material.dart';

/// Reusable background wrapper that applies the natural pale cream background
/// and subtle green leaf branch decorations in the top-left and bottom-right corners.
class NatureBackground extends StatelessWidget {
  final Widget child;

  const NatureBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F5EA), // Soft cream/sage background
      child: Stack(
        children: [
          // Top-Left Leaf Branch Decoration
          Positioned(
            top: 0,
            left: 0,
            width: 140,
            height: 140,
            child: IgnorePointer(
              child: CustomPaint(painter: _TopLeftLeafPainter()),
            ),
          ),

          // Bottom-Right Leaf Branch Decoration
          Positioned(
            bottom: 0,
            right: 0,
            width: 140,
            height: 140,
            child: IgnorePointer(
              child: CustomPaint(painter: _BottomRightLeafPainter()),
            ),
          ),

          // Foreground Screen Content
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _TopLeftLeafPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stemPaint = Paint()
      ..color = const Color(0xFF8BAE68).withValues(alpha: 0.45)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leafPaint = Paint()
      ..color = const Color(0xFF7A9D57).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    final leafOutline = Paint()
      ..color = const Color(0xFF5A7A3B).withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Main curved stem from top left moving downwards-right
    final path = Path()
      ..moveTo(0, 20)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.3,
        size.width * 0.7,
        size.height * 0.75,
      );

    canvas.drawPath(path, stemPaint);

    // Draw leaves along stem
    _drawLeaf(canvas, const Offset(25, 28), -0.5, leafPaint, leafOutline);
    _drawLeaf(canvas, const Offset(42, 45), 0.8, leafPaint, leafOutline);
    _drawLeaf(canvas, const Offset(62, 60), -0.7, leafPaint, leafOutline);
    _drawLeaf(canvas, const Offset(78, 82), 0.6, leafPaint, leafOutline);
    _drawLeaf(canvas, const Offset(92, 100), -0.3, leafPaint, leafOutline);
  }

  void _drawLeaf(
    Canvas canvas,
    Offset center,
    double angle,
    Paint fill,
    Paint outline,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final leafPath = Path()
      ..moveTo(0, 0)
      ..cubicTo(12, -18, 22, -12, 28, 0)
      ..cubicTo(22, 12, 12, 18, 0, 0);

    canvas.drawPath(leafPath, fill);
    canvas.drawPath(leafPath, outline);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomRightLeafPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stemPaint = Paint()
      ..color = const Color(0xFF8BAE68).withValues(alpha: 0.4)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final leafPaint = Paint()
      ..color = const Color(0xFF7A9D57).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final leafOutline = Paint()
      ..color = const Color(0xFF5A7A3B).withValues(alpha: 0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Stem curve from bottom right upwards-left
    final path = Path()
      ..moveTo(size.width, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.6,
        size.width * 0.2,
        size.height * 0.15,
      );

    canvas.drawPath(path, stemPaint);

    _drawLeaf(
      canvas,
      Offset(size.width * 0.75, size.height * 0.68),
      2.2,
      leafPaint,
      leafOutline,
    );
    _drawLeaf(
      canvas,
      Offset(size.width * 0.6, size.height * 0.55),
      -1.8,
      leafPaint,
      leafOutline,
    );
    _drawLeaf(
      canvas,
      Offset(size.width * 0.42, size.height * 0.38),
      2.0,
      leafPaint,
      leafOutline,
    );
    _drawLeaf(
      canvas,
      Offset(size.width * 0.28, size.height * 0.22),
      -2.2,
      leafPaint,
      leafOutline,
    );
  }

  void _drawLeaf(
    Canvas canvas,
    Offset center,
    double angle,
    Paint fill,
    Paint outline,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final leafPath = Path()
      ..moveTo(0, 0)
      ..cubicTo(10, -15, 18, -10, 24, 0)
      ..cubicTo(18, 10, 10, 15, 0, 0);

    canvas.drawPath(leafPath, fill);
    canvas.drawPath(leafPath, outline);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
