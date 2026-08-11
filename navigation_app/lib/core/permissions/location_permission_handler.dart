import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// The resolved state of location permission + service availability.
enum LocationPermissionState {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

/// Wraps `geolocator` + `permission_handler` behind a single, testable
/// API so the rest of the app never talks to platform channels directly.
class LocationPermissionHandler {
  const LocationPermissionHandler();

  Future<LocationPermissionState> checkAndRequest() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionState.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionState.granted;
      case LocationPermission.deniedForever:
        return LocationPermissionState.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionState.denied;
    }
  }

  /// Opens the OS-level app settings screen so the user can manually
  /// grant a permanently-denied permission.
  Future<void> openAppSettings() => ph.openAppSettings();

  /// Opens the OS-level location services screen (e.g. to toggle GPS on).
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
