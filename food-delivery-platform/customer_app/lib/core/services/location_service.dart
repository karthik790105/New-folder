import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Result from a location fetch, either a success with address details
/// or an error message explaining why it failed.
class LocationResult {
  final bool success;
  final String? address;
  final double? lat;
  final double? lng;
  final String? error;

  const LocationResult._({
    required this.success,
    this.address,
    this.lat,
    this.lng,
    this.error,
  });

  factory LocationResult.ok(String address, double lat, double lng) =>
      LocationResult._(success: true, address: address, lat: lat, lng: lng);

  factory LocationResult.fail(String error) =>
      LocationResult._(success: false, error: error);
}

class LocationService {
  /// Checks permission status, requests if needed, then returns the
  /// current GPS position reverse-geocoded to a human-readable address.
  static Future<LocationResult> getCurrentLocation() async {
    // 1. Check if location services are enabled on the device
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationResult.fail(
        'Location services are disabled. Please enable GPS in settings.',
      );
    }

    // 2. Check / request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationResult.fail(
          'Location permission denied. Please allow location access.',
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationResult.fail(
        'Location permission permanently denied. Enable it in App Settings.',
      );
    }

    try {
      // 3. Get GPS coordinates
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // 4. Reverse geocode coordinates → readable address
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        return LocationResult.ok(
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
          position.latitude,
          position.longitude,
        );
      }

      final place = placemarks.first;

      // Build a clean, readable Indian-style address string
      final parts = <String>[
        if ((place.subThoroughfare ?? '').isNotEmpty) place.subThoroughfare!,
        if ((place.thoroughfare ?? '').isNotEmpty) place.thoroughfare!,
        if ((place.subLocality ?? '').isNotEmpty) place.subLocality!,
        if ((place.locality ?? '').isNotEmpty) place.locality!,
        if ((place.administrativeArea ?? '').isNotEmpty)
          place.administrativeArea!,
        if ((place.postalCode ?? '').isNotEmpty) place.postalCode!,
      ].where((s) => s.isNotEmpty).toList();

      final address =
          parts.isNotEmpty ? parts.join(', ') : 'Current Location';

      return LocationResult.ok(address, position.latitude, position.longitude);
    } on LocationServiceDisabledException {
      return LocationResult.fail('GPS is turned off. Please enable it.');
    } catch (e) {
      return LocationResult.fail('Failed to get location: ${e.toString()}');
    }
  }

  /// Opens the device location settings so the user can enable GPS.
  static Future<void> openSettings() => Geolocator.openLocationSettings();

  /// Opens the app-specific permission settings page.
  static Future<void> openAppSettings() => Geolocator.openAppSettings();
}
