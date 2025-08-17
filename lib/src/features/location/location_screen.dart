
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  GoogleMapController? _mapController;
  LatLng? _pickedLocation;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    print('Getting current location...');
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the 
      // App to enable the location services.
      _showSnackBar('Location services are disabled.');
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        _showSnackBar('Location permissions are denied');
        return Future.error('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      _showSnackBar('Location permissions are permanently denied, we cannot request permissions.');
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _pickedLocation = LatLng(position.latitude, position.longitude);
        print('Current location found: $_pickedLocation');
        _addMarker(_pickedLocation!);
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_pickedLocation!, 15),
      );
    } catch (e) {
      _showSnackBar('Could not get current location: $e');
    }
  }

  void _addMarker(LatLng position) {
    print('Adding marker at: $position');
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('pickedLocation'),
          position: position,
          draggable: true,
          onDragEnd: (newPosition) {
            print('Marker dragged to: $newPosition');
            setState(() {
              _pickedLocation = newPosition;
            });
          },
        ),
      };
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    print('Map created!');
    _mapController = controller;
    if (_pickedLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_pickedLocation!, 15),
      );
    }
  }

  void _selectLocation(LatLng position) {
    print('Map tapped at: $position');
    setState(() {
      _pickedLocation = position;
      _addMarker(position);
    });
  }

  void _confirmLocation() {
    if (_pickedLocation != null) {
      print('Location confirmed: $_pickedLocation');
      Navigator.of(context).pop(_pickedLocation);
    } else {
      _showSnackBar('Please select a location.');
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
        title: const Text('Select Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _confirmLocation,
          ),
        ],
      ),
      body: _pickedLocation == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _pickedLocation!,
                zoom: 15,
              ),
              onTap: _selectLocation,
              markers: _markers,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
