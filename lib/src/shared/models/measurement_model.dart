
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Measurement {
  final int? id;
  final String imagePath;
  final double? personHeight;
  final double treeHeight;
  final double? latitude;
  final double? longitude;
  final String? speciesName;
  final DateTime timestamp;

  Measurement({
    this.id,
    required this.imagePath,
    this.personHeight,
    required this.treeHeight,
    this.latitude,
    this.longitude,
    this.speciesName,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'personHeight': personHeight,
      'treeHeight': treeHeight,
      'latitude': latitude,
      'longitude': longitude,
      'speciesName': speciesName,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Measurement.fromMap(Map<String, dynamic> map) {
    return Measurement(
      id: map['id'],
      imagePath: map['imagePath'],
      personHeight: map['personHeight'],
      treeHeight: map['treeHeight'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      speciesName: map['speciesName'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  // Helper to convert LatLng to Measurement
  Measurement copyWith({
    int? id,
    String? imagePath,
    double? personHeight,
    double? treeHeight,
    LatLng? location,
    String? speciesName,
    DateTime? timestamp,
  }) {
    return Measurement(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      personHeight: personHeight ?? this.personHeight,
      treeHeight: treeHeight ?? this.treeHeight,
      latitude: location?.latitude ?? latitude,
      longitude: location?.longitude ?? longitude,
      speciesName: speciesName ?? this.speciesName,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
