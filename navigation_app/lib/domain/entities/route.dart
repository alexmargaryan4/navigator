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
  final bool hasTolls;

  /// Whether this is the recommended/primary route among alternatives.
  final bool isPrimary;

  double get distanceKm => distanceMeters / 1000;

  Duration get duration => Duration(seconds: durationSeconds.round());
}
