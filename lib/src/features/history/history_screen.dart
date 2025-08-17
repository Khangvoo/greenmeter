import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with WidgetsBindingObserver {
  List<AssetEntity> _images = [];
  bool _isLoading = false;
  PermissionStatus _photoPermissionStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissionAndLoadImages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestPermissionAndLoadImages(); // Reload images when app resumes
    }
  }

  Future<void> _requestPermissionAndLoadImages() async {
    setState(() {
      _isLoading = true;
    });

    final status = await Permission.photos.request();
    setState(() {
      _photoPermissionStatus = status;
    });

    if (status.isGranted) {
      await _loadImages();
    } else {
      // Handle the case where permission is not granted
      // Maybe show a message or a button to open settings
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadImages() async {
    _images.clear(); // Clear existing images before loading new ones
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );

    if (albums.isNotEmpty) {
      AssetPathEntity? targetAlbum;
      try {
        targetAlbum = albums.firstWhere(
          (album) => album.name.toLowerCase() == 'treemeasureapp',
        );
      } catch (e) {
        targetAlbum = null;
      }

      if (targetAlbum != null) {
        final List<AssetEntity> assets = await targetAlbum.getAssetListRange(
          start: 0,
          end: await targetAlbum.assetCountAsync,
        );
        setState(() {
          _images = assets;
        });
      } else {
        setState(() {
          _images = [];
        });
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _requestPermissionAndLoadImages,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _photoPermissionStatus.isGranted
          ? (_isLoading
              ? const Center(child: CircularProgressIndicator())
              : _images.isEmpty
                  ? const Center(child: Text('Không có ảnh nào trong thư viện.'))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4.0,
                        mainAxisSpacing: 4.0,
                      ),
                      itemCount: _images.length,
                      itemBuilder: (context, index) {
                        final asset = _images[index];
                        return FutureBuilder<Uint8List?>(
                          future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                              );
                            }
                            return const Center(child: CircularProgressIndicator());
                          },
                        );
                      },
                    ))
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Cần quyền truy cập ảnh để xem lịch sử.'),
                  ElevatedButton(
                    onPressed: () {
                      openAppSettings(); // Open app settings to allow user to grant permission
                    },
                    child: const Text('Mở cài đặt'),
                  ),
                ],
              ),
            ),
    );
  }
}