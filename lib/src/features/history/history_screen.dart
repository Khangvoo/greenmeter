import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

import 'photo_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with WidgetsBindingObserver {
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

  Future<void> _deleteImage(AssetEntity asset) async {
    try {
      final result = await PhotoManager.editor.deleteWithIds([asset.id]);
      if (result.isNotEmpty) {
        setState(() {
          _images.remove(asset);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xóa ảnh')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Không thể xóa ảnh')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa ảnh: $e')));
    }
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
                : ListView.builder(
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      final asset = _images[index];
                      return Dismissible(
                        key: Key(asset.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) {
                          _deleteImage(asset);
                        },
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PhotoDetailScreen(image: asset),
                              ),
                            );
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(8.0),
                              leading: FutureBuilder<Uint8List?>(
                                future: asset.thumbnailDataWithSize(
                                  const ThumbnailSize(100, 100),
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                          ConnectionState.done &&
                                      snapshot.data != null) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Image.memory(
                                        snapshot.data!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  }
                                  return const SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
                              ),
                              title: Text(
                                DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                ).format(asset.createDateTime),
                              ),
                            ),
                          ),
                        ),
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
