import 'package:geolocator/geolocator.dart';

/// A single, app-wide GPS position sample.
class LocationSample {
  const LocationSample({
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.speedMps,
    required this.accuracyMeters,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;

  /// Degrees, 0-360, where available. `null` when the platform can't
  /// provide a reliable heading (e.g. standing still).
  final double? heading;

  /// Ground speed in meters/second, where available.
  final double? speedMps;

  final double accuracyMeters;
  final DateTime timestamp;

  factory LocationSample.fromPosition(Position p) => LocationSample(
        latitude: p.latitude,
        longitude: p.longitude,
        heading: p.heading.isNaN ? null : p.heading,
        speedMps: p.speed.isNaN ? null : p.speed,
        accuracyMeters: p.accuracy,
        timestamp: p.timestamp,
      );
}

/// Streams live GPS updates at a cadence appropriate for turn-by-turn
/// navigation vs. idle map browsing.
///
/// Kept as a thin wrapper over `geolocator` so consumers (Riverpod
/// providers) depend on an app-owned abstraction rather than a
/// third-party package directly — this keeps swapping location providers
/// or mocking location in tests simple.
class LocationTracker {
  const LocationTracker();

  /// A stream suitable for continuous turn-by-turn navigation: frequent,
  /// high-accuracy updates.
  Stream<LocationSample> navigationStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );
    return Geolocator.getPositionStream(locationSettings: settings)
        .map(LocationSample.fromPosition);
  }

  /// A stream suitable for idle map browsing: less frequent, still
  /// accurate, but friendlier to battery life.
  Stream<LocationSample> idleStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
    return Geolocator.getPositionStream(locationSettings: settings)
        .map(LocationSample.fromPosition);
  }

  Future<LocationSample?> lastKnown() async {
    final p = await Geolocator.getLastKnownPosition();
    return p == null ? null : LocationSample.fromPosition(p);
  }

  Future<LocationSample> current() async {
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return LocationSample.fromPosition(p);
  }
}
