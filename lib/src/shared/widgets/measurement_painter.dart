
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class MeasurementPainter extends CustomPainter {
  final Offset? topTreeLine;
  final Offset? bottomTreeLine;
  final Offset? topPersonLine;
  final Offset? bottomPersonLine;
  final Offset? dbhLineP1;
  final Offset? dbhLineP2;

  MeasurementPainter({
    this.topTreeLine,
    this.bottomTreeLine,
    this.topPersonLine,
    this.bottomPersonLine,
    this.dbhLineP1,
    this.dbhLineP2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final treeLinePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0;

    final treeHandlePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final personLinePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2.0;

    final personHandlePaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    // Draw calibration lines (top and bottom of the tree)
    if (topTreeLine != null) {
      canvas.drawLine(Offset(0, topTreeLine!.dy), Offset(size.width, topTreeLine!.dy), treeLinePaint);
      canvas.drawCircle(Offset(size.width / 2, topTreeLine!.dy), 5, treeHandlePaint);
      _drawLabel(canvas, 'Tree Top', Offset(10, topTreeLine!.dy - 20), Colors.red);
    }

    if (bottomTreeLine != null) {
      canvas.drawLine(Offset(0, bottomTreeLine!.dy), Offset(size.width, bottomTreeLine!.dy), treeLinePaint);
      canvas.drawCircle(Offset(size.width / 2, bottomTreeLine!.dy), 5, treeHandlePaint);
      _drawLabel(canvas, 'Tree Bottom', Offset(10, bottomTreeLine!.dy + 5), Colors.red);
    }

    // Draw calibration lines (top and bottom of the person)
    if (topPersonLine != null) {
      canvas.drawLine(Offset(0, topPersonLine!.dy), Offset(size.width, topPersonLine!.dy), personLinePaint);
      canvas.drawCircle(Offset(size.width / 2, topPersonLine!.dy), 5, personHandlePaint);
      _drawLabel(canvas, 'Person Top', Offset(10, topPersonLine!.dy - 20), Colors.green);
    }

    if (bottomPersonLine != null) {
      canvas.drawLine(Offset(0, bottomPersonLine!.dy), Offset(size.width, bottomPersonLine!.dy), personLinePaint);
      canvas.drawCircle(Offset(size.width / 2, bottomPersonLine!.dy), 5, personHandlePaint);
      _drawLabel(canvas, 'Person Bottom', Offset(10, bottomPersonLine!.dy + 5), Colors.green);
    }

    // Draw DBH measurement line
    if (dbhLineP1 != null && dbhLineP2 != null) {
      final dbhLinePaint = Paint()
        ..color = Colors.blue
        ..strokeWidth = 2.0;
      final dbhHandlePaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;
      canvas.drawLine(dbhLineP1!, dbhLineP2!, dbhLinePaint);
      canvas.drawCircle(dbhLineP1!, 5, dbhHandlePaint);
      canvas.drawCircle(dbhLineP2!, 5, dbhHandlePaint);
      _drawLabel(canvas, 'DBH', Offset(dbhLineP1!.dx, dbhLineP1!.dy - 20), Colors.blue);
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset position, Color color) {
    final textStyle = ui.TextStyle(
      color: Colors.white,
      fontSize: 16.0,
      fontWeight: FontWeight.bold,
    );
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: 16.0,
      ),
    )
      ..pushStyle(textStyle)
      ..addText(text);
    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 120.0));

    final backgroundPaint = Paint()
      ..color = color.withOpacity(0.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(position.dx - 5, position.dy - 5, paragraph.width + 10, paragraph.height + 10),
        const Radius.circular(5.0),
      ),
      backgroundPaint,
    );

    canvas.drawParagraph(paragraph, position);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is MeasurementPainter) {
      return oldDelegate.topTreeLine != topTreeLine ||
          oldDelegate.bottomTreeLine != bottomTreeLine ||
          oldDelegate.topPersonLine != topPersonLine ||
          oldDelegate.bottomPersonLine != bottomPersonLine ||
          oldDelegate.dbhLineP1 != dbhLineP1 ||
          oldDelegate.dbhLineP2 != dbhLineP2;
    }
    return true;
  }
}
