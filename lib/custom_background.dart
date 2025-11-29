import 'package:flutter/material.dart';

/// Custom painter for main background with gradient
class MainBackground extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Create a gradient from light grey to white
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.grey[100]!,
          Colors.white,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

