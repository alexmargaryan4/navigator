import '../../core/errors/result.dart';
import '../entities/geo_point.dart';
import '../entities/route.dart';

/// Contract for real traffic-flow data. Traffic is only ever attached to
/// existing route geometry from the routing provider's own annotations —
/// this repository never fabricates congestion levels.
abstract interface class TrafficRepository {
  /// Returns traffic-flow segments for the current map viewport, used to
  /// paint the traffic overlay on the base map (independent of any
  /// active route).
  Future<Result<List<TrafficSegment>>> trafficForViewport({
    required GeoPoint northEast,
    required GeoPoint southWest,
  });
}
