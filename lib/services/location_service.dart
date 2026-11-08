import 'package:geolocator/geolocator.dart';

import '../models/place.dart';

class LocationException implements Exception {
  final String message;
  LocationException(this.message);
  @override
  String toString() => message;
}

class LocationService {
  /// The user's current position as a [Place] the trip planner can use.
  static Future<Place> currentPlace() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('Location services are turned off.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw LocationException('Location permission is needed to plan from where you are.');
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).timeout(const Duration(seconds: 15));
    return Place(
      id: 'me:${pos.latitude},${pos.longitude}',
      name: 'My location',
      lat: pos.latitude,
      lng: pos.longitude,
      type: 'coord',
    );
  }
}
