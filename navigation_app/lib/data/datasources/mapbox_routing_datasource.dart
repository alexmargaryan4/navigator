import '../../core/config/app_config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/networking/api_client.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/route.dart';
import '../../domain/entities/travel_mode.dart';
import '../../domain/repositories/routing_repository.dart';
import '../models/polyline_codec.dart';

/// Talks directly to the Mapbox Directions API.
///
/// Traffic-aware ETAs and congestion annotations are only requested for
/// [TravelMode.driving] (Mapbox's `driving-traffic` profile) — walking
/// and cycling profiles don't support live traffic, so [NavRoute]s for
/// those modes simply have empty [NavRoute.trafficSegments].
class MapboxRoutingDataSource {
  MapboxRoutingDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  static const String _base = '${AppConfig.mapboxBaseUrl}/directions/v5/mapbox';

  Future<Result<List<NavRoute>>> directions({
    required GeoPoint origin,
    required GeoPoint destination,
    required TravelMode mode,
    required RouteOptions options,
  }) async {
    if (!AppConfig.hasMapKey) {
      return const Result.err(ConfigurationFailure());
    }

    final coords =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';

    final excludeParts = <String>[
      if (options.avoidTolls) 'toll',
      if (options.avoidHighways) 'motorway',
    ];

    final isTrafficAware = mode == TravelMode.driving;

    final uri = Uri.parse('$_base/${mode.mapboxProfile}/$coords').replace(
      queryParameters: {
        'access_token': AppConfig.mapApiKey,
        'geometries': 'polyline6',
        'overview': 'full',
        'steps': 'true',
        'alternatives': options.alternatives ? 'true' : 'false',
        'annotations': isTrafficAware ? 'congestion,duration,distance' : 'duration,distance',
        'banner_instructions': 'true',
        if (excludeParts.isNotEmpty) 'exclude': excludeParts.join(','),
      },
    );

    final result = await _client.getJson(uri);
    return result.when(
      ok: (json) {
        final code = json['code'] as String?;
        if (code != null && code != 'Ok') {
          return const Result.err(RoutingFailure());
        }
        final rawRoutes =
            (json['routes'] as List? ?? []).cast<Map<String, dynamic>>();
        if (rawRoutes.isEmpty) {
          return const Result.err(RoutingFailure());
        }

        final routes = <NavRoute>[];
        for (var i = 0; i < rawRoutes.length; i++) {
          routes.add(_parseRoute(
            rawRoutes[i],
            mode: mode,
            index: i,
            hasTollsRequested: !options.avoidTolls,
          ));
        }
        return Result.ok(routes);
      },
      err: (f) => Result.err(f),
    );
  }

  NavRoute _parseRoute(
    Map<String, dynamic> raw, {
    required TravelMode mode,
    required int index,
    required bool hasTollsRequested,
  }) {
    final geometryEncoded = raw['geometry'] as String? ?? '';
    final geometry = PolylineCodec.decode(geometryEncoded, precision: 6);

    final legs = (raw['legs'] as List? ?? []).cast<Map<String, dynamic>>();
    final steps = <RouteStep>[];
    final trafficSegments = <TrafficSegment>[];
    var tolls = false;

    for (final leg in legs) {
      final legSteps = (leg['steps'] as List? ?? []).cast<Map<String, dynamic>>();
      for (final step in legSteps) {
        final maneuver = step['maneuver'] as Map<String, dynamic>? ?? {};
        final location = (maneuver['location'] as List?) ?? const [0, 0];
        steps.add(RouteStep(
          instruction: (maneuver['instruction'] ?? '').toString(),
          distanceMeters: (step['distance'] as num? ?? 0).toDouble(),
          durationSeconds: (step['duration'] as num? ?? 0).toDouble(),
          maneuverLocation: GeoPoint(
            longitude: (location[0] as num).toDouble(),
            latitude: (location[1] as num).toDouble(),
          ),
          maneuverType: [
            (maneuver['type'] ?? '').toString(),
            (maneuver['modifier'] ?? '').toString(),
          ].where((s) => s.isNotEmpty).join('-'),
          roadName: (step['name'] as String?)?.isNotEmpty == true
              ? step['name'] as String
              : null,
        ));
      }

      final annotation = leg['annotation'] as Map<String, dynamic>?;
      final congestion = (annotation?['congestion'] as List?)?.cast<String>();
      if (congestion != null) {
        trafficSegments.addAll(_collapseCongestion(congestion));
      }

      final tollFlag = leg['toll'] ?? leg['has_toll'];
      if (tollFlag == true) tolls = true;
    }

    return NavRoute(
      id: 'route_$index',
      mode: mode,
      geometry: geometry,
      distanceMeters: (raw['distance'] as num? ?? 0).toDouble(),
      durationSeconds: (raw['duration'] as num? ?? 0).toDouble(),
      steps: steps,
      trafficSegments: trafficSegments,
      hasTolls: tolls && hasTollsRequested,
      isPrimary: index == 0,
    );
  }

  /// Collapses a per-coordinate-pair congestion string list (Mapbox's
  /// format) into contiguous [TrafficSegment] runs, so the UI doesn't
  /// need to re-derive this on every rebuild.
  List<TrafficSegment> _collapseCongestion(List<String> congestion) {
    final segments = <TrafficSegment>[];
    if (congestion.isEmpty) return segments;

    int start = 0;
    TrafficLevel currentLevel = _levelFrom(congestion.first);

    for (var i = 1; i < congestion.length; i++) {
      final level = _levelFrom(congestion[i]);
      if (level != currentLevel) {
        segments.add(TrafficSegment(
          startIndex: start,
          endIndex: i,
          level: currentLevel,
        ));
        start = i;
        currentLevel = level;
      }
    }
    segments.add(TrafficSegment(
      startIndex: start,
      endIndex: congestion.length,
      level: currentLevel,
    ));
    return segments;
  }

  TrafficLevel _levelFrom(String value) => switch (value) {
        'low' => TrafficLevel.low,
        'moderate' => TrafficLevel.moderate,
        'heavy' => TrafficLevel.heavy,
        'severe' => TrafficLevel.severe,
        _ => TrafficLevel.unknown,
      };
}
