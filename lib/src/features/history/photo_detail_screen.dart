import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoDetailScreen extends StatelessWidget {
  final AssetEntity image;

  const PhotoDetailScreen({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết ảnh'),
      ),
      body: Center(
        child: FutureBuilder<Uint8List?>(
          future: image.originBytes,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
              return Image.memory(snapshot.data!);
            }
            return const CircularProgressIndicator();
          },
        ),
      ),
    );
  }
}
