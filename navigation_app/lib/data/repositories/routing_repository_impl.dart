import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/route.dart';
import '../../domain/entities/travel_mode.dart';
import '../../domain/repositories/routing_repository.dart';
import '../datasources/mapbox_routing_datasource.dart';

class RoutingRepositoryImpl implements RoutingRepository {
  RoutingRepositoryImpl(this._dataSource);

  final MapboxRoutingDataSource _dataSource;

  @override
  Future<Result<List<NavRoute>>> calculateRoute({
    required GeoPoint origin,
    required GeoPoint destination,
    required TravelMode mode,
    RouteOptions options = const RouteOptions(),
  }) {
    return _dataSource.directions(
      origin: origin,
      destination: destination,
      mode: mode,
      options: options,
    );
  }

  @override
  Future<Result<NavRoute>> recalculate({
    required GeoPoint currentLocation,
    required GeoPoint destination,
    required TravelMode mode,
    RouteOptions options = const RouteOptions(),
  }) async {
    final result = await _dataSource.directions(
      origin: currentLocation,
      destination: destination,
      mode: mode,
      // A recalculation should always be traffic-aware "now" — never
      // reuse a stale departAt from the original request.
      options: RouteOptions(
        avoidTolls: options.avoidTolls,
        avoidHighways: options.avoidHighways,
        alternatives: false,
      ),
    );
    return result.when(
      ok: (routes) => routes.isEmpty
          ? const Result.err(RoutingFailure())
          : Result.ok(routes.first),
      err: (f) => Result.err(f),
    );
  }
}
