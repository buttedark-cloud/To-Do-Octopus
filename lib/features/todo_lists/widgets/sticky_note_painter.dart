import 'package:flutter/material.dart';

/// Рисует фон карточки-стикера с загнутым уголком снизу справа.
class StickyNotePainter extends CustomPainter {
  final Color baseColor;
  StickyNotePainter({required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;
    const double cornerSize = 35.0;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cornerSize)
      ..lineTo(size.width - cornerSize, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);

    final foldPaint = Paint()
      ..color = Color.alphaBlend(Colors.black.withOpacity(0.15), baseColor)
      ..style = PaintingStyle.fill;
    final foldPath = Path()
      ..moveTo(size.width - cornerSize, size.height)
      ..lineTo(size.width - cornerSize, size.height - cornerSize)
      ..lineTo(size.width, size.height - cornerSize)
      ..close();
    canvas.drawPath(foldPath, foldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Обрезает виджет по форме стикера с уголком (используется через PhysicalShape).
class StickyNoteClipper extends CustomClipper<Path> {
  final Path Function(Size) pathBuilder;
  StickyNoteClipper(this.pathBuilder);

  @override
  Path getClip(Size size) => pathBuilder(size);

  @override
  bool shouldReclip(covariant CustomClipper oldClipper) => false;
}
