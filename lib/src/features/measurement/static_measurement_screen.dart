import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:ultralytics_yolo/yolo_result.dart';
import 'package:ultralytics_yolo/yolo_task.dart';
import 'package:ultralytics_yolo/yolo_view.dart';

class StaticMeasurementScreen extends StatefulWidget {
  const StaticMeasurementScreen({super.key});

  @override
  State<StaticMeasurementScreen> createState() =>
      _StaticMeasurementScreenState();
}

class _StaticMeasurementScreenState extends State<StaticMeasurementScreen> {
  final ImagePicker _picker = ImagePicker();
  YOLO? _yolo;

  // Dữ liệu hình ảnh và kết quả
  File? _imageFile;
  ui.Image? _displayImage;
  List<YOLOResult> _results = [];
  bool _isLoading = false;

  // Chiều cao tham chiếu và kết quả đo
  double _referenceHeight = 1.7;
  double? _treeHeight;
  double? _treeDiameter;

  final TextEditingController _heightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _heightController.text = _referenceHeight.toString();
    _loadYoloModel();
  }

  Future<void> _loadYoloModel() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final yolo = YOLO(
        modelPath: 'flutter_assets/assets/models/yolov8n.tflite',
        task: YOLOTask.detect,
      );
      await yolo.loadModel();
      setState(() {
        _yolo = yolo;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error loading YOLO model: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _yolo?.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final decodedImage = await decodeImageFromList(file.readAsBytesSync());
      setState(() {
        _imageFile = file;
        _displayImage = decodedImage;
        _results = []; // Xóa kết quả cũ
        _treeHeight = null;
        _treeDiameter = null;
      });
    }
  }

  Future<void> _processImage() async {
    if (_imageFile == null || _yolo == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final Uint8List imageBytes = await _imageFile!.readAsBytes();
      final resultsMap = await _yolo!.predict(imageBytes);

      final List<YOLOResult> results = (resultsMap['detections'] as List)
          .map((e) => YOLOResult.fromMap(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _results = results;
        _calculateMeasurements();
      });
    } catch (e) {
      // ignore: avoid_print
      print("Error processing image: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateMeasurements() {
    final YOLOResult? person = _results.cast<YOLOResult?>().firstWhere(
      (res) => res?.className == 'person',
      orElse: () => null,
    );

    YOLOResult? tree;
    double maxTreeHeight = 0;
    for (final res in _results) {
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
      _treeHeight = treePixelHeight * metersPerPixel;

      final treePixelWidth = tree.boundingBox.width;
      _treeDiameter = treePixelWidth * metersPerPixel;
    } else {
      _treeHeight = null;
      _treeDiameter = null;
    }
    // Cập nhật UI sau khi tính toán
    setState(() {});
  }

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
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                setState(() {
                  _referenceHeight =
                      double.tryParse(_heightController.text) ?? 1.7;
                });
                Navigator.of(context).pop();
                // Tính toán lại nếu đã có kết quả
                if (_results.isNotEmpty) _calculateMeasurements();
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
        title: const Text('Đo từ ảnh tĩnh'),
        actions: [
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
          if (_displayImage == null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text('Vui lòng chọn một ảnh để bắt đầu'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _pickImage,
                    child: const Text('Chọn ảnh từ thư viện'),
                  ),
                ],
              ),
            )
          else
            InteractiveViewer(
              maxScale: 5.0,
              child: CustomPaint(
                painter: StaticMeasurementPainter(
                  image: _displayImage!,
                  results: _results,
                  treeHeight: _treeHeight,
                  treeDiameter: _treeDiameter,
                ),
                size: Size.infinite, // Cho phép painter vẽ full size
              ),
            ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: _imageFile != null
          ? FloatingActionButton.extended(
              onPressed: _processImage,
              label: const Text('Bắt đầu đo'),
              icon: const Icon(Icons.analytics),
            )
          : FloatingActionButton(
              onPressed: _pickImage,
              tooltip: 'Chọn ảnh',
              child: const Icon(Icons.add_photo_alternate),
            ),
    );
  }
}

class StaticMeasurementPainter extends CustomPainter {
  final ui.Image image;
  final List<YOLOResult> results;
  final double? treeHeight;
  final double? treeDiameter;

  StaticMeasurementPainter({
    required this.image,
    required this.results,
    this.treeHeight,
    this.treeDiameter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Tính toán tỉ lệ và offset để vẽ ảnh vào trung tâm canvas
    final paint = Paint();
    final inputSize = Size(image.width.toDouble(), image.height.toDouble());
    final fittedSizes = applyBoxFit(BoxFit.contain, inputSize, size);
    final sourceRect = Alignment.center.inscribe(
      fittedSizes.source,
      Rect.fromLTWH(0, 0, inputSize.width, inputSize.height),
    );
    final destinationRect = Alignment.center.inscribe(
      fittedSizes.destination,
      Rect.fromLTWH(0, 0, size.width, size.height),
    );

    canvas.drawImageRect(image, sourceRect, destinationRect, paint);

    // Tính toán tỉ lệ scale để vẽ bounding box
    final scaleX = destinationRect.width / sourceRect.width;
    final scaleY = destinationRect.height / sourceRect.height;
    final offsetX = destinationRect.left;
    final offsetY = destinationRect.top;

    // Vẽ bounding box và kết quả
    for (final result in results) {
      final boundingBox = result.boundingBox;

      // Scale the boundingBox to fit the canvas
      final scaledBox = Rect.fromLTWH(
        boundingBox.left * scaleX + offsetX,
        boundingBox.top * scaleY + offsetY,
        boundingBox.width * scaleX,
        boundingBox.height * scaleY,
      );

      final boxPaint = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRect(scaledBox, boxPaint);

      final textPainter = TextPainter(textDirection: TextDirection.ltr);

      // Hiển thị tên class và độ tin cậy
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
      textPainter.paint(canvas, Offset(scaledBox.left, scaledBox.top - 20));

      // Hiển thị kết quả đo nếu là cây
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
        textPainter.paint(canvas, Offset(scaledBox.right + 5, scaledBox.top));

        textPainter.text = TextSpan(
          text: 'ĐK: ${treeDiameter!.toStringAsFixed(2)} m',
          style: const TextStyle(
            color: Colors.white,
            backgroundColor: Colors.black54,
            fontSize: 16,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(scaledBox.right + 5, scaledBox.top + 20),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}