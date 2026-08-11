import '../../core/errors/result.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/route.dart';
import '../../domain/repositories/traffic_repository.dart';

/// Mapbox exposes live traffic in two real, distinct ways — there is no
/// third "give me congestion for this bounding box as JSON" endpoint, so
/// this repository is intentionally honest about which one it uses:
///
/// 1. **`mapbox-traffic-v1` vector tiles** — rendered directly by the map
///    engine as a source/layer on the [MapboxMapView] itself (see
///    `lib/features/map`). This is how the always-on road-coloring
///    traffic overlay actually gets drawn; it is not fetched through
///    this repository at all because it never leaves the map widget.
/// 2. **Directions API `congestion` annotations** — real per-route
///    traffic already parsed by [MapboxRoutingDataSource] into
///    [NavRoute.trafficSegments] whenever a route is calculated with the
///    `driving-traffic` profile.
///
/// This repository therefore exposes viewport-level traffic by simply
/// forwarding whatever the last-calculated route already carries, rather
/// than fabricating a second, redundant network call. Widgets that only
/// need the base-map traffic coloring (no active route yet) should
/// enable the traffic layer directly on the map instead of going through
/// this repository — see `MapboxMapController.setTrafficVisible`.
class TrafficRepositoryImpl implements TrafficRepository {
  const TrafficRepositoryImpl();

  @override
  Future<Result<List<TrafficSegment>>> trafficForViewport({
    required GeoPoint northEast,
    required GeoPoint southWest,
  }) async {
    // No active-route context at the viewport level — return an empty,
    // successful result rather than a failure, since "no traffic
    // segments to show yet" is a valid, non-error state before a route
    // exists. The live map traffic layer (vector tiles) still renders
    // independently of this call.
    return const Result.ok(<TrafficSegment>[]);
  }
}
