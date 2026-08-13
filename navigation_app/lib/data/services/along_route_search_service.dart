import 'dart:math' as math;

import '../../core/config/app_config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/networking/api_client.dart';
import '../../domain/entities/along_route_poi.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/route.dart';
import '../datasources/mapbox_parking_datasource.dart';

/// Finds real POIs "along the way" (product spec «По пути»): parking,
/// gas stations, cafes, restaurants, shops, EV charging.
///
/// The key requirement this exists to satisfy: results must be close to
/// the *route geometry*, not merely close to the user's current
/// location. A plain "nearby search" from the user's position would
/// happily return a great cafe that is nowhere near the road ahead —
/// this service instead:
///
///  1. Samples the active route's geometry at even intervals so a long
///     route is covered by a handful of proximity searches, not one.
///  2. Queries Mapbox's real category search around each sample point.
///  3. Deduplicates POIs found by more than one sample.
///  4. Computes each POI's real distance to the *closest point on the
///     route line* (not to any single sample point) and drops anything
///     farther than [maxDistanceFromRouteMeters].
///  5. Orders results by how soon the user will pass them.
///
/// Every field on [AlongRoutePoi] is real provider data — nothing here
/// is fabricated.
class AlongRouteSearchService {
  AlongRouteSearchService({
    MapboxParkingDataSource? parkingDataSource,
    ApiClient? client,
  })  : _client = client ?? ApiClient(),
        _parkingDataSource = parkingDataSource ??
            MapboxParkingDataSource(client: client ?? ApiClient());

  final ApiClient _client;
  // Reused for its category-search HTTP shape (parking is just one
  // category of the same Search Box endpoint family) — see
  // [_searchCategoryNear] for the general-purpose version used for every
  // other category.
  final MapboxParkingDataSource _parkingDataSource;

  static const String _searchBoxBase =
      '${AppConfig.mapboxBaseUrl}/search/searchbox/v1';

  /// How far apart (meters) route samples are placed. Small enough to
  /// catch POIs along winding urban routes, large enough that a long
  /// highway trip doesn't fire dozens of API calls.
  static const double _sampleSpacingMeters = 4000;
  static const int _maxSamples = 6;
  static const double _maxDistanceFromRouteMeters = 800;

  Future<Result<List<AlongRoutePoi>>> searchAlongRoute({
    required NavRoute route,
    required AlongRoutePoiCategory category,
    int limitPerSample = 6,
  }) async {
    if (!AppConfig.hasMapKey) {
      return const Result.err(ConfigurationFailure());
    }
    if (route.geometry.length < 2) {
      return const Result.ok(<AlongRoutePoi>[]);
    }

    final samples = _sampleRoute(route.geometry);
    if (samples.isEmpty) {
      return const Result.ok(<AlongRoutePoi>[]);
    }

    final responses = await Future.wait(samples.map(
      (s) => category == AlongRoutePoiCategory.parking
          ? _viaParkingDataSource(s, limitPerSample)
          : _searchCategoryNear(
              category: category,
              proximity: s,
              limit: limitPerSample,
            ),
    ));

    final byId = <String, AlongRoutePoi>{};
    var anyOk = false;
    AppFailure? lastFailure;

    for (final response in responses) {
      response.when(
        ok: (pois) {
          anyOk = true;
          for (final poi in pois) {
            // First sighting wins for name/address; if a later sample
            // computes a smaller distance-to-route, keep the smaller one.
            final existing = byId[poi.id];
            if (existing == null ||
                poi.distanceFromRouteMeters < existing.distanceFromRouteMeters) {
              byId[poi.id] = poi;
            }
          }
        },
        err: (f) => lastFailure = f,
      );
    }

    if (!anyOk) {
      return Result.err(lastFailure ?? const UnknownFailure());
    }

    final withRouteDistance = byId.values
        .map((poi) => _withRealDistanceToRoute(poi, route.geometry))
        .where((poi) => poi.distanceFromRouteMeters <= _maxDistanceFromRouteMeters)
        .toList()
      ..sort((a, b) => (a.distanceAlongRouteMeters ?? 0)
          .compareTo(b.distanceAlongRouteMeters ?? 0));

    return Result.ok(withRouteDistance);
  }

  // ---------------------------------------------------------------------
  // Sampling
  // ---------------------------------------------------------------------

  /// Picks up to [_maxSamples] points along the route geometry, spaced
  /// roughly [_sampleSpacingMeters] apart, always including the very
  /// first point (so results near the start of the trip aren't missed).
  List<GeoPoint> _sampleRoute(List<GeoPoint> geometry) {
    final cumulative = <double>[0];
    for (var i = 1; i < geometry.length; i++) {
      cumulative.add(cumulative.last + geometry[i - 1].distanceTo(geometry[i]));
    }
    final totalLength = cumulative.last;
    if (totalLength <= 0) return [geometry.first];

    final spacing = totalLength / _maxSamples > _sampleSpacingMeters
        ? totalLength / _maxSamples
        : _sampleSpacingMeters;

    final samples = <GeoPoint>[];
    var nextTarget = 0.0;
    var index = 0;
    while (nextTarget <= totalLength && samples.length < _maxSamples) {
      while (index < cumulative.length - 1 && cumulative[index] < nextTarget) {
        index++;
      }
      samples.add(geometry[index]);
      nextTarget += spacing;
    }
    if (samples.isEmpty) samples.add(geometry.first);
    return samples;
  }

  // ---------------------------------------------------------------------
  // Provider calls
  // ---------------------------------------------------------------------

  Future<Result<List<AlongRoutePoi>>> _viaParkingDataSource(
    GeoPoint proximity,
    int limit,
  ) async {
    final result = await _parkingDataSource.nearbyParking(
      center: proximity,
      radiusMeters: _maxDistanceFromRouteMeters * 3,
      limit: limit,
    );
    return result.when(
      ok: (spots) => Result.ok(spots
          .map((s) => AlongRoutePoi(
                id: s.id,
                name: s.name,
                location: s.location,
                address: s.address,
                category: AlongRoutePoiCategory.parking,
                distanceFromRouteMeters: 0, // recomputed in searchAlongRoute
                rating: s.rating,
                openingHours: s.openingHours,
              ))
          .toList()),
      err: (f) => Result.err(f),
    );
  }

  Future<Result<List<AlongRoutePoi>>> _searchCategoryNear({
    required AlongRoutePoiCategory category,
    required GeoPoint proximity,
    required int limit,
  }) async {
    final uri = Uri.parse('$_searchBoxBase/category/${category.mapboxCategory}')
        .replace(queryParameters: {
      'access_token': AppConfig.mapApiKey,
      'proximity': '${proximity.longitude},${proximity.latitude}',
      'limit': '$limit',
    });

    final result = await _client.getJson(uri);
    return result.when(
      ok: (json) {
        final features =
            (json['features'] as List? ?? []).cast<Map<String, dynamic>>();
        final pois = features
            .map((f) => _toPoi(f, category))
            .whereType<AlongRoutePoi>()
            .toList();
        return Result.ok(pois);
      },
      err: (f) => Result.err(f),
    );
  }

  AlongRoutePoi? _toPoi(
    Map<String, dynamic> feature,
    AlongRoutePoiCategory category,
  ) {
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
    final coordinates = (geometry['coordinates'] as List?) ?? const [0, 0];
    if (coordinates.length < 2) return null;

    final metadata = properties['metadata'] as Map<String, dynamic>? ?? {};
    final openHours = metadata['open_hours'];
    final openingHours =
        (openHours is Map && openHours['is_24_hours'] == true)
            ? 'Open 24 hours'
            : null;

    return AlongRoutePoi(
      id: (properties['mapbox_id'] ?? feature['id'] ?? '').toString(),
      name: (properties['name'] ?? category.label).toString(),
      location: GeoPoint(
        longitude: (coordinates[0] as num).toDouble(),
        latitude: (coordinates[1] as num).toDouble(),
      ),
      address:
          (properties['full_address'] ?? properties['place_formatted'] ?? '')
              .toString(),
      category: category,
      distanceFromRouteMeters: 0, // recomputed in searchAlongRoute
      rating: (metadata['rating'] as num?)?.toDouble(),
      openingHours: openingHours,
    );
  }

  // ---------------------------------------------------------------------
  // Real distance-to-route-line computation
  // ---------------------------------------------------------------------

  /// Recomputes [AlongRoutePoi.distanceFromRouteMeters] and
  /// [AlongRoutePoi.distanceAlongRouteMeters] against the *whole* route
  /// polyline (every segment, not just the sample point that happened to
  /// find this POI) — this is what actually enforces "near the route",
  /// as opposed to "near wherever we searched from".
  AlongRoutePoi _withRealDistanceToRoute(
    AlongRoutePoi poi,
    List<GeoPoint> geometry,
  ) {
    var minDistance = double.infinity;
    var distanceAlongAtClosest = 0.0;
    var cumulative = 0.0;

    for (var i = 0; i < geometry.length - 1; i++) {
      final a = geometry[i];
      final b = geometry[i + 1];
      final segmentLength = a.distanceTo(b);

      final projection = _closestPointOnSegment(a, b, poi.location);
      final distance = projection.distanceTo(poi.location);
      if (distance < minDistance) {
        minDistance = distance;
        distanceAlongAtClosest = cumulative + a.distanceTo(projection);
      }
      cumulative += segmentLength;
    }

    return AlongRoutePoi(
      id: poi.id,
      name: poi.name,
      location: poi.location,
      address: poi.address,
      category: poi.category,
      distanceFromRouteMeters: minDistance.isFinite ? minDistance : 0,
      distanceAlongRouteMeters: distanceAlongAtClosest,
      rating: poi.rating,
      openingHours: poi.openingHours,
    );
  }

  /// Approximate closest point on segment a→b to point p, working in a
  /// local equirectangular projection (accurate enough at the scale of a
  /// single route segment; avoids pulling in a full geodesy library for
  /// this).
  GeoPoint _closestPointOnSegment(GeoPoint a, GeoPoint b, GeoPoint p) {
    final latRad = a.latitude * 3.141592653589793 / 180;
    final lonScale = _cos(latRad);

    final ax = a.longitude * lonScale;
    final ay = a.latitude;
    final bx = b.longitude * lonScale;
    final by = b.latitude;
    final px = p.longitude * lonScale;
    final py = p.latitude;

    final abx = bx - ax;
    final aby = by - ay;
    final apx = px - ax;
    final apy = py - ay;

    final abLenSq = abx * abx + aby * aby;
    final t = abLenSq == 0 ? 0.0 : ((apx * abx + apy * aby) / abLenSq).clamp(0.0, 1.0);

    final projX = ax + abx * t;
    final projY = ay + aby * t;

    return GeoPoint(latitude: projY, longitude: projX / lonScale);
  }

  double _cos(double radians) => math.cos(radians);
}
