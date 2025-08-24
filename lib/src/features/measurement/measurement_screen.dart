import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tree_measure_app/src/features/camera/camera_screen.dart';
import 'package:tree_measure_app/src/shared/widgets/measurement_painter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tree_measure_app/src/services/plantnet_service.dart';
import 'dart:ui' as ui;

class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key});

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

enum _DraggedObject {
  topTree,
  bottomTree,
  topPerson,
  bottomPerson,
  dbhP1,
  dbhP2,
  none,
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  File? _pickedImage;
  double? _personHeight;
  double? _calculatedTreeHeight;
  String? _calculatedTreeDiameter;

  Offset? _topTreeLine;
  Offset? _bottomTreeLine;
  Offset? _topPersonLine;
  Offset? _bottomPersonLine;
  Offset? _dbhLineP1;
  Offset? _dbhLineP2;

  double? _pixelToMeterRatio;
  bool _isCalibrating = false;
  _DraggedObject _draggedObject = _DraggedObject.none;
  Size? _imageSize;
  Size? _layoutSize;
  Size? _displaySize;
  bool _isLoadingPlantNet = false; // New variable

  final ImagePicker _picker = ImagePicker();
  final PlantNetService _plantNetService = PlantNetService(); // New instance

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (pickedFile != null) {
      _reset();
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
      await _processImageForPlantNet(_pickedImage!);
    }
  }

  Future<void> _takePhotoWithSpiritLevel() async {
    final imagePath = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (context) => CameraScreen()));
    if (imagePath != null) {
      _reset();
      setState(() {
        _pickedImage = File(imagePath);
      });
      await _processImageForPlantNet(_pickedImage!);
    }
  }

  Future<void> _processImageForPlantNet(File imageFile) async {
    setState(() {
      _isLoadingPlantNet = true;
    });
    _showSnackBar('Identifying plant...');

    final decodedImage = await decodeImageFromList(
      await imageFile.readAsBytes(),
    );
    setState(() {
      _imageSize = Size(
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      );
    });

    final results = await _plantNetService.identifyPlant(imageFile);

    setState(() {
      _isLoadingPlantNet = false;
    });

    if (results.containsKey('error')) {
      _showSnackBar('PlantNet Error: ${results['error']}');
      _showPersonHeightDialog(); // Proceed even if PlantNet fails
      return;
    }

    final List<dynamic> predictions = results['results'] ?? [];
    if (predictions.isNotEmpty) {
      await _showPlantNetResultsDialog(predictions);
    } else {
      _showSnackBar('No plant identified. Proceeding to measurement.');
      _showPersonHeightDialog(); // Proceed if no plant identified
    }
  }

  Future<void> _showPlantNetResultsDialog(List<dynamic> predictions) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Plant Identification Results'),
          content: SingleChildScrollView(
            child: ListBody(
              children: predictions.take(3).map((prediction) {
                final species = prediction['species'];
                final commonNames =
                    (species['commonNames'] as List?)?.join(', ') ?? 'N/A';
                final scientificName =
                    species['scientificNameWithoutAuthor'] ?? 'N/A';
                final score = (prediction['score'] * 100).toStringAsFixed(2);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    '${commonNames} (${scientificName}) - ${score}% confidence',
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Confirm & Proceed'),
              onPressed: () {
                Navigator.of(context).pop();
                _showPersonHeightDialog();
              },
            ),
            TextButton(
              child: const Text('Cancel & Reset'),
              onPressed: () {
                Navigator.of(context).pop();
                _reset();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPersonHeightDialog() async {
    final TextEditingController heightController = TextEditingController();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Your Height (in meters)'),
          content: TextField(
            controller: heightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Your Height',
              hintText: 'e.g., 1.75',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                _reset();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                final height = double.tryParse(heightController.text);
                if (height != null && height > 0) {
                  setState(() {
                    _personHeight = height;
                    _isCalibrating = true;
                  });
                  Navigator.of(context).pop();
                } else {
                  _showSnackBar('Please enter a valid positive height.');
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _initCalibrationLines(Size layoutSize) {
    if (_imageSize == null || _topTreeLine != null || !_isCalibrating) return;

    final double imageAspectRatio = _imageSize!.width / _imageSize!.height;
    final double layoutAspectRatio = layoutSize.width / layoutSize.height;
    Size displaySize;
    if (imageAspectRatio > layoutAspectRatio) {
      displaySize = Size(layoutSize.width, layoutSize.width / imageAspectRatio);
    } else {
      displaySize = Size(
        layoutSize.height * imageAspectRatio,
        layoutSize.height,
      );
    }

    final topOffset = (layoutSize.height - displaySize.height) / 2;

    // Initialize lines only once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _layoutSize = layoutSize;
        _displaySize = displaySize;
        _topTreeLine = Offset(0, topOffset + displaySize.height * 0.25);
        _bottomTreeLine = Offset(0, topOffset + displaySize.height * 0.75);
        _topPersonLine = Offset(0, topOffset + displaySize.height * 0.4);
        _bottomPersonLine = Offset(0, topOffset + displaySize.height * 0.6);
      });
    });
  }

  void _onPanStart(DragStartDetails details) {
    final pos = details.localPosition;
    const double minDistance = 20.0;
    _DraggedObject potentialDrag = _DraggedObject.none;

    if (_isCalibrating && _topTreeLine != null && _bottomTreeLine != null) {
      if ((pos.dy - _topTreeLine!.dy).abs() < minDistance)
        potentialDrag = _DraggedObject.topTree;
      else if ((pos.dy - _bottomTreeLine!.dy).abs() < minDistance)
        potentialDrag = _DraggedObject.bottomTree;
      else if ((pos.dy - _topPersonLine!.dy).abs() < minDistance)
        potentialDrag = _DraggedObject.topPerson;
      else if ((pos.dy - _bottomPersonLine!.dy).abs() < minDistance)
        potentialDrag = _DraggedObject.bottomPerson;
    } else if (!_isCalibrating && _dbhLineP1 != null && _dbhLineP2 != null) {
      if ((pos - _dbhLineP1!).distance < minDistance)
        potentialDrag = _DraggedObject.dbhP1;
      else if ((pos - _dbhLineP2!).distance < minDistance)
        potentialDrag = _DraggedObject.dbhP2;
    }
    if (potentialDrag != _DraggedObject.none) {
      setState(() => _draggedObject = potentialDrag);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_draggedObject == _DraggedObject.none) return;
    setState(() {
      final pos = details.localPosition;
      switch (_draggedObject) {
        case _DraggedObject.topTree:
          _topTreeLine = Offset(_topTreeLine!.dx, pos.dy);
          break;
        case _DraggedObject.bottomTree:
          _bottomTreeLine = Offset(_bottomTreeLine!.dx, pos.dy);
          break;
        case _DraggedObject.topPerson:
          _topPersonLine = Offset(_topPersonLine!.dx, pos.dy);
          break;
        case _DraggedObject.bottomPerson:
          _bottomPersonLine = Offset(_bottomPersonLine!.dx, pos.dy);
          break;
        case _DraggedObject.dbhP1:
          _dbhLineP1 = Offset(pos.dx, _dbhLineP1!.dy);
          _updateDiameter();
          break;
        case _DraggedObject.dbhP2:
          _dbhLineP2 = Offset(pos.dx, _dbhLineP2!.dy);
          _updateDiameter();
          break;
        case _DraggedObject.none:
          break;
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _draggedObject = _DraggedObject.none);
  }

  void _confirmCalibration() {
    if (_topTreeLine == null ||
        _bottomTreeLine == null ||
        _topPersonLine == null ||
        _bottomPersonLine == null ||
        _personHeight == null ||
        _layoutSize == null) // Add guard for layoutSize
      return;

    final double personPixelHeight =
        (_bottomPersonLine!.dy - _topPersonLine!.dy).abs();
    if (personPixelHeight < 10) {
      // Avoid division by zero or tiny values
      _showSnackBar(
        'The distance between the person lines is too small. Please re-adjust.',
      );
      return;
    }

    final ratio = _personHeight! / personPixelHeight;
    final double treePixelHeight = (_bottomTreeLine!.dy - _topTreeLine!.dy)
        .abs();
    final calculatedTreeHeight = treePixelHeight * ratio;

    final double dbhHeightInPixels = 1.3 / ratio;
    final double dbhLineY = _bottomTreeLine!.dy - dbhHeightInPixels;

    if (dbhLineY < _topTreeLine!.dy || dbhLineY > _bottomTreeLine!.dy) {
      _showSnackBar(
        '1.3m mark is outside the calibrated tree height. Please re-calibrate.',
      );
      return;
    }

    setState(() {
      _pixelToMeterRatio = ratio;
      _calculatedTreeHeight = calculatedTreeHeight;
      _isCalibrating = false;
      // Use layoutSize.width instead of screenWidth
      final containerWidth = _layoutSize!.width;
      _dbhLineP1 = Offset(containerWidth * 0.4, dbhLineY);
      _dbhLineP2 = Offset(containerWidth * 0.6, dbhLineY);
      _updateDiameter();
    });
  }

  void _updateDiameter() {
    if (_dbhLineP1 == null || _dbhLineP2 == null || _pixelToMeterRatio == null)
      return;
    final pixelWidth = (_dbhLineP2!.dx - _dbhLineP1!.dx).abs();
    final diameterInMeters = pixelWidth * _pixelToMeterRatio!;
    setState(() {
      _calculatedTreeDiameter = (diameterInMeters * 100).toStringAsFixed(1);
    });
  }

  Future<void> _saveMeasurement() async {
    try {
      final RenderRepaintBoundary boundary =
          _repaintBoundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save the image to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = await File('${tempDir.path}/temp_image.png').create();
      await tempFile.writeAsBytes(pngBytes);

      final result = await GallerySaver.saveImage(
        tempFile.path,
        albumName: "TreeMeasureApp",
      );

      if (result == true) {
        _showSnackBar('Image saved to Gallery!');
        _reset();
      } else {
        _showSnackBar('Failed to save image.');
      }
    } catch (e) {
      _showSnackBar('An error occurred while saving: $e');
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    Color color,
    double fontSize,
  ) {
    final paragraphBuilder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.left,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: color,
              background: Paint()..color = Colors.black.withOpacity(0.5),
            ),
          )
          ..addText(text);
    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 400.0));
    canvas.drawParagraph(paragraph, position);
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.locationWhenInUse,
      Permission.storage,
    ].request();

    if (!mounted) return;
    if (statuses[Permission.camera] != PermissionStatus.granted) {
      _showSnackBar('Camera permission is required to take photos.');
    }
    if (!mounted) return;
    if (statuses[Permission.locationWhenInUse] != PermissionStatus.granted) {
      _showSnackBar('Location permission is required for GPS functionality.');
    }
    if (!mounted) return;
    if (statuses[Permission.storage] != PermissionStatus.granted) {
      _showSnackBar('Storage permission is required to save images.');
    }
  }

  void _reset() {
    setState(() {
      _pickedImage = null;
      _personHeight = null;
      _calculatedTreeHeight = null;
      _calculatedTreeDiameter = null;
      _topTreeLine = null;
      _bottomTreeLine = null;
      _topPersonLine = null;
      _bottomPersonLine = null;
      _dbhLineP1 = null;
      _dbhLineP2 = null;
      _pixelToMeterRatio = null;
      _isCalibrating = false;
      _draggedObject = _DraggedObject.none;
      _imageSize = null;
      _layoutSize = null;
      _displaySize = null;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tree Measurement'),
        actions: [
          if (_isCalibrating && _topTreeLine != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _confirmCalibration,
              tooltip: 'Confirm Calibration',
            ),
          if (_calculatedTreeHeight != null && _calculatedTreeDiameter != null)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveMeasurement,
              tooltip: 'Save Measurement',
            ),
          if (_pickedImage != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
              tooltip: 'Reset',
            ),
        ],
      ),
      body: _isLoadingPlantNet
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Identifying plant with PlantNet...'),
                ],
              ),
            )
          : _MeasurementBody(
              repaintBoundaryKey: _repaintBoundaryKey,
              pickedImage: _pickedImage,
              isCalibrating: _isCalibrating,
              personHeight: _personHeight,
              calculatedTreeHeight: _calculatedTreeHeight,
              calculatedDiameter: _calculatedTreeDiameter,
              topTreeLine: _topTreeLine,
              bottomTreeLine: _bottomTreeLine,
              topPersonLine: _topPersonLine,
              bottomPersonLine: _bottomPersonLine,
              dbhLineP1: _dbhLineP1,
              dbhLineP2: _dbhLineP2,
              onPickImage: _pickImage,
              onLayoutReady: _initCalibrationLines,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onTakePhotoPressed: _takePhotoWithSpiritLevel,
            ),
    );
  }
}

class _MeasurementBody extends StatelessWidget {
  final GlobalKey repaintBoundaryKey;
  final File? pickedImage;
  final bool isCalibrating;
  final double? personHeight;
  final double? calculatedTreeHeight;
  final String? calculatedDiameter;
  final Offset? topTreeLine,
      bottomTreeLine,
      topPersonLine,
      bottomPersonLine,
      dbhLineP1,
      dbhLineP2;
  final void Function(ImageSource) onPickImage;
  final void Function(Size) onLayoutReady;
  final void Function(DragStartDetails) onPanStart;
  final void Function(DragUpdateDetails) onPanUpdate;
  final void Function(DragEndDetails) onPanEnd;
  final VoidCallback onTakePhotoPressed;

  const _MeasurementBody({
    super.key,
    required this.repaintBoundaryKey,
    this.pickedImage,
    required this.isCalibrating,
    this.personHeight,
    this.calculatedTreeHeight,
    this.calculatedDiameter,
    this.topTreeLine,
    this.bottomTreeLine,
    this.topPersonLine,
    this.bottomPersonLine,
    this.dbhLineP1,
    this.dbhLineP2,
    required this.onPickImage,
    required this.onLayoutReady,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onTakePhotoPressed,
  });

  @override
  Widget build(BuildContext context) {
    String instructions = '1. Pick an image of a tree and a person next to it.';
    if (pickedImage != null && personHeight == null) {
      instructions = 'Waiting for your height input...';
    } else if (isCalibrating) {
      instructions =
          '2. Drag the red lines to the top and bottom of the tree.\n3. Drag the green lines to the top and bottom of the person.\n4. Press the checkmark to confirm.';
    } else if (pickedImage != null && personHeight != null) {
      instructions =
          '5. Adjust the horizontal line to match the tree trunk\'s width at 1.3m.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: pickedImage != null
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    // Use a post-frame callback to initialize lines after the layout is built.
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => onLayoutReady(constraints.biggest),
                    );
                    return RepaintBoundary(
                      key: repaintBoundaryKey,
                      child: GestureDetector(
                        onPanStart: onPanStart,
                        onPanUpdate: onPanUpdate,
                        onPanEnd: onPanEnd,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.file(pickedImage!, fit: BoxFit.contain),
                            CustomPaint(
                              size: constraints.biggest,
                              painter: MeasurementPainter(
                                topTreeLine: topTreeLine,
                                bottomTreeLine: bottomTreeLine,
                                topPersonLine: topPersonLine,
                                bottomPersonLine: bottomPersonLine,
                                dbhLineP1: dbhLineP1,
                                dbhLineP2: dbhLineP2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Text('Pick an image to start measuring'),
                  ),
                ),
        ),
        Visibility(
          visible: calculatedTreeHeight != null && calculatedDiameter != null,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Calculated Tree Height: ${calculatedTreeHeight?.toStringAsFixed(2) ?? ''} m',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Calculated Diameter: ${calculatedDiameter ?? ''} cm',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 100.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(instructions, textAlign: TextAlign.center),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onTakePhotoPressed,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => onPickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
