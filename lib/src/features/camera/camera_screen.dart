import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  double _z = 0.0;
  bool _isLevel = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        _z = event.z;
        _checkLevel();
      });
    });
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(_cameras![0], ResolutionPreset.high);
      await _controller!.initialize();
      if (!mounted) {
        return;
      }
      setState(() {});
    }
  }

  void _checkLevel() async {
    // Ngưỡng cho sự cân bằng, giá trị của z phải gần 0.0
    final double threshold = 0.5; // Điều chỉnh giá trị này để thay đổi độ nhạy

    // Kiểm tra nếu giá trị của z nằm trong khoảng [-threshold, threshold]
    if (_z.abs() < threshold) {
      if (!_isLevel) {
        _isLevel = true;
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 100);
        }
      }
    } else {
      _isLevel = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      body: Stack(
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: CameraPreview(_controller!),
          ),
          // Level Indicator
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: CustomPaint(
                painter: CrosshairPainter(_z, _isLevel),
                child: Container(width: 200, height: 200),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: () async {
                  try {
                    final image = await _controller!.takePicture();
                    Navigator.pop(context, image.path);
                  } catch (e) {
                    print(e);
                  }
                },
                child: const Icon(Icons.camera_alt),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CrosshairPainter extends CustomPainter {
  final double z;
  final bool isLevel;

  CrosshairPainter(this.z, this.isLevel);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final double crosshairArmLength = 20.0; // Chiều dài mỗi cánh của dấu cộng

    // Dấu cộng đứng yên (ở giữa màn hình)
    canvas.drawLine(
      Offset(center.dx - crosshairArmLength, center.dy),
      Offset(center.dx + crosshairArmLength, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - crosshairArmLength),
      Offset(center.dx, center.dy + crosshairArmLength),
      paint,
    );

    // Dấu cộng di chuyển
    // Map giá trị z (từ -9.8 đến 9.8) vào một khoảng nhỏ hơn để hiển thị
    // Khi z = 0, movingY = center.dy
    // Khi z = 9.8, movingY = center.dy - max_offset
    // Khi z = -9.8, movingY = center.dy + max_offset
    final double maxOffset = 50.0; // Khoảng cách di chuyển tối đa của dấu cộng
    final double movingY = center.dy - (z / 9.8) * maxOffset;

    final movingCrosshairPaint = Paint()
      ..color = isLevel ? Colors.green : Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(center.dx - crosshairArmLength, movingY),
      Offset(center.dx + crosshairArmLength, movingY),
      movingCrosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, movingY - crosshairArmLength),
      Offset(center.dx, movingY + crosshairArmLength),
      movingCrosshairPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CrosshairPainter oldDelegate) {
    return oldDelegate.z != z || oldDelegate.isLevel != isLevel;
  }
}
