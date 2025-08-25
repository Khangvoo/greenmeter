import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:ultralytics_yolo/yolo_result.dart';
import 'package:ultralytics_yolo/yolo_task.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import 'package:tree_measure_app/src/features/measurement/static_measurement_screen.dart';

class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key});

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  // Chiều cao của người làm mẫu (mét)
  double _referenceHeight = 1.7;

  // Kết quả đo đạc
  double? _treeHeight;
  double? _treeDiameter;

  // Kết quả nhận dạng từ YOLO
  List<YOLOResult> _detectionResults = [];

  // Controller cho dialog nhập chiều cao
  final TextEditingController _heightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _heightController.text = _referenceHeight.toString();
  }

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  // Hiển thị dialog để người dùng nhập chiều cao tham chiếu
  Future<void> _showReferenceHeightDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Nhập chiều cao người mẫu (m)'),
          content: TextField(
            controller: _heightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: "Ví dụ: 1.7"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                setState(() {
                  _referenceHeight =
                      double.tryParse(_heightController.text) ?? 1.7;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đo lường cây (YOLO)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.image_search),
            tooltip: 'Đo từ ảnh tĩnh',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StaticMeasurementScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Chiều cao người mẫu',
            onPressed: _showReferenceHeightDialog,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          YOLOView(
            modelPath: 'assets/models/yolov8n.tflite',
            task: YOLOTask.detect,
            onResult: (results) {
              if (mounted) {
                setState(() {
                  _detectionResults = results;
                  _calculateMeasurements();
                });
              }
            },
            onPerformanceMetrics: (metrics) {
              // ignore: avoid_print
              print('Performance: ${metrics.fps.toStringAsFixed(1)} FPS');
            },
          ),
          CustomPaint(
            painter: MeasurementPainter(
              results: _detectionResults,
              treeHeight: _treeHeight,
              treeDiameter: _treeDiameter,
            ),
          ),
        ],
      ),
    );
  }

  void _calculateMeasurements() {
    final YOLOResult? person = _detectionResults.cast<YOLOResult?>().firstWhere(
      (res) => res?.className == 'person',
      orElse: () => null,
    );

    // Tìm cây lớn nhất trong khung hình (nếu có nhiều cây)
    YOLOResult? tree;
    double maxTreeHeight = 0;
    for (final res in _detectionResults) {
      if (res.className == 'tree' || res.className == 'potted plant') {
        if (res.boundingBox.height > maxTreeHeight) {
          maxTreeHeight = res.boundingBox.height;
          tree = res;
        }
      }
    }

    if (person != null && tree != null) {
      final personPixelHeight = person.boundingBox.height;
      if (personPixelHeight == 0) return;
      final metersPerPixel = _referenceHeight / personPixelHeight;

      final treePixelHeight = tree.boundingBox.height;
      final newTreeHeight = treePixelHeight * metersPerPixel;

      final treePixelWidth = tree.boundingBox.width;
      final newTreeDiameter = treePixelWidth * metersPerPixel;

      if (mounted) {
        setState(() {
          _treeHeight = newTreeHeight;
          _treeDiameter = newTreeDiameter;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _treeHeight = null;
          _treeDiameter = null;
        });
      }
    }
  }
}

class MeasurementPainter extends CustomPainter {
  final List<YOLOResult> results;
  final double? treeHeight;
  final double? treeDiameter;

  MeasurementPainter({
    required this.results,
    this.treeHeight,
    this.treeDiameter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final result in results) {
      final box = result.boundingBox;
      final paint = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRect(box, paint);

      final textPainter = TextPainter(textDirection: TextDirection.ltr);

      textPainter.text = TextSpan(
        text:
            '${result.className} ${(result.confidence * 100).toStringAsFixed(1)}%',
        style: const TextStyle(
          color: Colors.white,
          backgroundColor: Colors.black54,
          fontSize: 14,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(box.left, box.top - 20));

      if ((result.className == 'tree' || result.className == 'potted plant') &&
          treeHeight != null &&
          treeDiameter != null) {
        textPainter.text = TextSpan(
          text: 'Cao: ${treeHeight!.toStringAsFixed(2)} m',
          style: const TextStyle(
            color: Colors.white,
            backgroundColor: Colors.black54,
            fontSize: 16,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(box.right + 5, box.top));

        textPainter.text = TextSpan(
          text: 'Đường kính: ${treeDiameter!.toStringAsFixed(2)} m',
          style: const TextStyle(
            color: Colors.white,
            backgroundColor: Colors.black54,
            fontSize: 16,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(box.right + 5, box.top + 20));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
