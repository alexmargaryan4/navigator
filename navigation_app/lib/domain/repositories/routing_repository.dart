import '../../core/errors/result.dart';
import '../entities/geo_point.dart';
import '../entities/route.dart';
import '../entities/travel_mode.dart';

/// Options that shape route calculation. Every option here maps to a
/// real routing-provider parameter — nothing here is decorative.
class RouteOptions {
  const RouteOptions({
    this.avoidTolls = false,
    this.avoidHighways = false,
    this.alternatives = true,
    this.departAt,
  });

  final bool avoidTolls;
  final bool avoidHighways;
  final bool alternatives;

  /// When set, requests traffic-aware ETA for this future departure time.
  /// `null` means "now".
  final DateTime? departAt;
}

/// Contract for real route calculation. Implementations must call a real
/// routing provider and must never invent geometry, distance, or ETA.
abstract interface class RoutingRepository {
  Future<Result<List<NavRoute>>> calculateRoute({
    required GeoPoint origin,
    required GeoPoint destination,
    required TravelMode mode,
    RouteOptions options = const RouteOptions(),
  });

  /// Recalculates the active route when the user deviates, reusing the
  /// same [mode]/[options] as the original request.
  Future<Result<NavRoute>> recalculate({
    required GeoPoint currentLocation,
    required GeoPoint destination,
    required TravelMode mode,
    RouteOptions options = const RouteOptions(),
  });
}
