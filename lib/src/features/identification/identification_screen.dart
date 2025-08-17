import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tree_measure_app/src/shared/services/plant_net_service.dart';

class IdentificationScreen extends StatefulWidget {
  const IdentificationScreen({super.key});

  @override
  State<IdentificationScreen> createState() => _IdentificationScreenState();
}

class _IdentificationScreenState extends State<IdentificationScreen> {
  File? _pickedImage;
  bool _isLoading = false;
  List<dynamic> _identificationResults = [];
  final PlantNetService _plantNetService = PlantNetService();

  Future<void> _saveImageToAlbum(File imageFile) async {
    try {
      final result = await GallerySaver.saveImage(
        imageFile.path,
        albumName: "TreeMeasureApp",
      );
      if (result == true) {
        _showSnackBar('Image saved to album TreeMeasureApp!');
      } else {
        _showSnackBar('Failed to save image.');
      }
    } catch (e) {
      _showSnackBar('An error occurred while saving: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedImageFile = await picker.pickImage(source: source, imageQuality: 70);

    if (pickedImageFile != null) {
      final imageFile = File(pickedImageFile.path);
      setState(() {
        _pickedImage = imageFile;
        _identificationResults = []; // Clear previous results
      });
      // Save image only if it's from the camera
      if (source == ImageSource.camera) {
        await _saveImageToAlbum(imageFile);
      }
    }
  }

  Future<void> _identifyPlant() async {
    if (_pickedImage == null) {
      _showSnackBar('Please pick an image first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _identificationResults = [];
    });

    try {
      final results = await _plantNetService.identifyPlant(_pickedImage!);
      setState(() {
        _identificationResults = results['results'] ?? [];
      });
    } catch (e) {
      _showSnackBar('Error identifying plant: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identify Species'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_pickedImage != null)
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(width: 1, color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.file(
                    _pickedImage!,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(width: 1, color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: const Center(
                    child: Text('No image selected'),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera),
                    label: const Text('Take Photo'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.image),
                    label: const Text('Pick from Gallery'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _identifyPlant,
                      icon: const Icon(Icons.search),
                      label: const Text('Identify Plant'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
              const SizedBox(height: 20),
              if (_identificationResults.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Identification Results:',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _identificationResults.length > 5 ? 5 : _identificationResults.length, // Show top 5 results
                      itemBuilder: (context, index) {
                        final result = _identificationResults[index];
                        final speciesName = result['species']['commonNames'] != null && result['species']['commonNames'].isNotEmpty
                            ? result['species']['commonNames'][0]
                            : result['species']['scientificNameWithoutAuthor'];
                        final score = (result['score'] * 100).toStringAsFixed(2);
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          child: ListTile(
                            title: Text(speciesName),
                            subtitle: Text('Score: $score%'),
                            // You can add more details here if needed
                          ),
                        );
                      },
                    ),
                  ],
                )
              else if (!_isLoading && _pickedImage != null)
                const Text('No identification results found.'),
            ],
          ),
        ),
      ),
    );
  }
}