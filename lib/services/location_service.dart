import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/attendance_record.dart';

/// Service for collecting GPS location data during student registration
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Check if location services are enabled on the device
  Future<bool> isLocationEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check current location permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission from the user
  Future<LocationPermission> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermission.deniedForever;
    }

    return permission;
  }

  /// Get current GPS position with high accuracy
  /// Returns null if permission is denied or location is unavailable
  Future<Position?> getCurrentPosition() async {
    try {
      final permission = await requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('[LocationService] Location permission denied');
        return null;
      }

      final isEnabled = await isLocationEnabled();
      if (!isEnabled) {
        print('[LocationService] Location services disabled');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('[LocationService] Position: ${position.latitude}, ${position.longitude} '
          '(accuracy: ${position.accuracy}m)');

      return position;
    } catch (e) {
      print('[LocationService] Error getting position: $e');
      return null;
    }
  }

  /// Reverse geocode coordinates to a human-readable address
  Future<String?> getAddressFromPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final addressParts = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((part) => part != null && part.isNotEmpty).toList();

        final address = addressParts.join(', ');
        print('[LocationService] Address: $address');
        return address;
      }
    } catch (e) {
      print('[LocationService] Error reverse geocoding: $e');
    }
    return null;
  }

  /// Collect full location data for attendance record
  /// Returns AttendanceLocation with coordinates and address
  Future<AttendanceLocation?> collectLocation() async {
    final position = await getCurrentPosition();
    if (position == null) return null;

    String? address;
    try {
      address = await getAddressFromPosition(position);
    } catch (e) {
      print('[LocationService] Could not get address: $e');
    }

    return AttendanceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      address: address,
      timestamp: DateTime.now(),
    );
  }

  /// Show a rationale dialog explaining why location is needed
  /// Call this before requesting permission if you want to explain first
  String getPermissionRationale() {
    return 'Location data is collected during attendance registration to verify '
        'that students are physically present in the classroom. '
        'This helps prevent remote/fraudulent check-ins. '
        'Your location is only shared with your lecturer and is not used for tracking.';
  }
}
