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
    List<GeoPoint> waypoints = const [],
  }) async {
    if (!AppConfig.hasMapKey) {
      return const Result.err(ConfigurationFailure());
    }

    final allPoints = [origin, ...waypoints, destination];
    final coords =
        allPoints.map((p) => '${p.longitude},${p.latitude}').join(';');

    final excludeParts = <String>[
      if (options.avoidTolls) 'toll',
      if (options.avoidHighways) 'motorway',
    ];

    final isTrafficAware = mode == TravelMode.driving;

    // Alternatives only make sense for a plain two-point request — Mapbox
    // doesn't return meaningfully different alternatives for a
    // multi-waypoint request, and requesting them anyway just wastes a
    // quota call, so they're switched off whenever waypoints are present.
    final requestAlternatives = options.alternatives && waypoints.isEmpty;

    final uri = Uri.parse('$_base/${mode.mapboxProfile}/$coords').replace(
      queryParameters: {
        'access_token': AppConfig.mapApiKey,
        'geometries': 'polyline6',
        'overview': 'full',
        'steps': 'true',
        'alternatives': requestAlternatives ? 'true' : 'false',
        'annotations': isTrafficAware
            ? 'congestion,duration,distance,maxspeed'
            : 'duration,distance',
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
    final speedLimitSegments = <SpeedLimitSegment>[];
    var tolls = false;
    var geometryOffset = 0;

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
        trafficSegments.addAll(
          _collapseCongestion(congestion, offset: geometryOffset),
        );
      }

      final maxspeed = (annotation?['maxspeed'] as List?)
          ?.cast<Map<String, dynamic>>();
      if (maxspeed != null) {
        speedLimitSegments.addAll(
          _collapseMaxspeed(maxspeed, offset: geometryOffset),
        );
      }

      // Each leg's annotation arrays cover that leg's own coordinate
      // count (distance array length = coordinates - 1); advance the
      // offset so a multi-leg (multi-stop) route's segments still index
      // correctly into the single combined [geometry] list.
      final legDistances = (annotation?['distance'] as List?)?.length ?? 0;
      geometryOffset += legDistances;

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
      speedLimitSegments: speedLimitSegments,
      hasTolls: tolls && hasTollsRequested,
      isPrimary: index == 0,
    );
  }

  /// Collapses a per-coordinate-pair congestion string list (Mapbox's
  /// format) into contiguous [TrafficSegment] runs, so the UI doesn't
  /// need to re-derive this on every rebuild. [offset] shifts indices so
  /// they land correctly in a multi-leg route's combined geometry list.
  List<TrafficSegment> _collapseCongestion(
    List<String> congestion, {
    int offset = 0,
  }) {
    final segments = <TrafficSegment>[];
    if (congestion.isEmpty) return segments;

    int start = 0;
    TrafficLevel currentLevel = _levelFrom(congestion.first);

    for (var i = 1; i < congestion.length; i++) {
      final level = _levelFrom(congestion[i]);
      if (level != currentLevel) {
        segments.add(TrafficSegment(
          startIndex: start + offset,
          endIndex: i + offset,
          level: currentLevel,
        ));
        start = i;
        currentLevel = level;
      }
    }
    segments.add(TrafficSegment(
      startIndex: start + offset,
      endIndex: congestion.length + offset,
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

  /// Collapses Mapbox's per-coordinate-pair `maxspeed` annotation
  /// (`{"speed": 60, "unit": "km/h"}` / `{"unknown": true}` /
  /// `{"none": true}`) into contiguous [SpeedLimitSegment] runs.
  /// Unknown/none/unparseable entries simply produce no segment for that
  /// stretch — never a fabricated value (product spec requirement: never
  /// invent a speed limit).
  List<SpeedLimitSegment> _collapseMaxspeed(
    List<Map<String, dynamic>> maxspeed, {
    int offset = 0,
  }) {
    final segments = <SpeedLimitSegment>[];
    if (maxspeed.isEmpty) return segments;

    double? start;
    int? runStart;

    void flush(int endIndex) {
      if (runStart != null && start != null) {
        segments.add(SpeedLimitSegment(
          startIndex: runStart! + offset,
          endIndex: endIndex + offset,
          speedKph: start!,
        ));
      }
      runStart = null;
      start = null;
    }

    for (var i = 0; i < maxspeed.length; i++) {
      final value = _speedKphFrom(maxspeed[i]);
      if (value == null) {
        flush(i);
        continue;
      }
      if (start == null) {
        start = value;
        runStart = i;
      } else if ((value - start!).abs() > 0.01) {
        flush(i);
        start = value;
        runStart = i;
      }
    }
    flush(maxspeed.length);
    return segments;
  }

  /// Converts a single Mapbox `maxspeed` annotation entry to km/h, or
  /// `null` when the provider marked it unknown/absent.
  double? _speedKphFrom(Map<String, dynamic> entry) {
    if (entry['unknown'] == true || entry['none'] == true) return null;
    final speed = entry['speed'];
    if (speed is! num) return null;
    final unit = (entry['unit'] as String?) ?? 'km/h';
    return unit == 'mph' ? speed.toDouble() * 1.609344 : speed.toDouble();
  }
}
