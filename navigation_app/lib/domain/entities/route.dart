import 'geo_point.dart';
import 'travel_mode.dart';

/// A single turn-by-turn maneuver instruction within a [NavRoute].
class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuverLocation,
    required this.maneuverType,
    this.roadName,
  });

  final String instruction;
  final double distanceMeters;
  final double durationSeconds;
  final GeoPoint maneuverLocation;

  /// Raw maneuver type/modifier from the routing provider (e.g.
  /// "turn-right", "roundabout", "arrive"). Kept as a string so the UI
  /// layer can map it to the correct icon without the domain layer
  /// needing to know about presentation concerns.
  final String maneuverType;

  final String? roadName;
}

/// One leg of traffic congestion annotation along a route, matching a
/// contiguous slice of the route geometry. Only ever populated from real
/// provider data (see requirement 42 — traffic is never fabricated).
enum TrafficLevel { low, moderate, heavy, severe, unknown }

class TrafficSegment {
  const TrafficSegment({
    required this.startIndex,
    required this.endIndex,
    required this.level,
  });

  /// Indices into the parent route's [NavRoute.geometry] list.
  final int startIndex;
  final int endIndex;
  final TrafficLevel level;
}

/// The real, provider-reported legal speed limit for a contiguous slice
/// of the route geometry — only ever populated when the routing
/// provider actually supplies it (Mapbox `maxspeed` annotation on the
/// `driving-traffic` profile). A stretch of road the provider has no
/// data for is represented by simply having no [SpeedLimitSegment]
/// covering it — never a guessed value (product spec «Ограничение
/// скорости»: never fabricate a limit).
class SpeedLimitSegment {
  const SpeedLimitSegment({
    required this.startIndex,
    required this.endIndex,
    required this.speedKph,
  });

  /// Indices into the parent route's [NavRoute.geometry] list.
  final int startIndex;
  final int endIndex;

  /// Always a real km/h figure from the provider — mph values reported
  /// by Mapbox for imperial regions are converted to km/h at parse time
  /// so the rest of the app only ever deals with one unit.
  final double speedKph;
}

/// A calculated route between two points, with real geometry and
/// metadata sourced entirely from the routing provider.
class NavRoute {
  const NavRoute({
    required this.id,
    required this.mode,
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
    this.trafficSegments = const [],
    this.speedLimitSegments = const [],
    this.hasTolls = false,
    this.isPrimary = false,
  });

  final String id;
  final TravelMode mode;

  /// Ordered polyline points describing the route path, decoded from the
  /// provider's geometry (e.g. Mapbox's encoded polyline6).
  final List<GeoPoint> geometry;

  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;
  final List<TrafficSegment> trafficSegments;

  /// Real posted speed limits along the route, where the provider
  /// supplies them (product spec «Ограничение скорости»). Empty when
  /// the provider has no data for this route/region — the UI must show
  /// "unavailable" in that case, never a fabricated number.
  final List<SpeedLimitSegment> speedLimitSegments;
  final bool hasTolls;

  /// Whether this is the recommended/primary route among alternatives.
  final bool isPrimary;

  double get distanceKm => distanceMeters / 1000;

  Duration get duration => Duration(seconds: durationSeconds.round());

  /// The real posted speed limit (km/h) nearest to [geometryIndex], or
  /// `null` if the provider has no data covering that point.
  double? speedLimitAt(int geometryIndex) {
    for (final segment in speedLimitSegments) {
      if (geometryIndex >= segment.startIndex && geometryIndex < segment.endIndex) {
        return segment.speedKph;
      }
    }
    return null;
  }

  NavRoute copyWith({
    String? id,
    TravelMode? mode,
    List<GeoPoint>? geometry,
    double? distanceMeters,
    double? durationSeconds,
    List<RouteStep>? steps,
    List<TrafficSegment>? trafficSegments,
    List<SpeedLimitSegment>? speedLimitSegments,
    bool? hasTolls,
    bool? isPrimary,
  }) {
    return NavRoute(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      geometry: geometry ?? this.geometry,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      steps: steps ?? this.steps,
      trafficSegments: trafficSegments ?? this.trafficSegments,
      speedLimitSegments: speedLimitSegments ?? this.speedLimitSegments,
      hasTolls: hasTolls ?? this.hasTolls,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}
