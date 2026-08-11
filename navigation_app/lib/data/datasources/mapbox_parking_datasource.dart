import '../../core/config/app_config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/networking/api_client.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/parking_spot.dart';

/// Uses Mapbox's Search Box `/category/parking` endpoint to find real
/// nearby parking POIs. Only fields Mapbox actually returns are ever
/// surfaced — price/hours/rating are `null` when Mapbox doesn't supply
/// them for a given POI (see requirement 43: never invent data).
class MapboxParkingDataSource {
  MapboxParkingDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  static const String _base = '${AppConfig.mapboxBaseUrl}/search/searchbox/v1';

  Future<Result<List<ParkingSpot>>> nearbyParking({
    required GeoPoint center,
    double radiusMeters = 1500,
    int limit = 20,
  }) async {
    if (!AppConfig.hasMapKey) {
      return const Result.err(ConfigurationFailure());
    }

    final uri = Uri.parse('$_base/category/parking').replace(queryParameters: {
      'access_token': AppConfig.mapApiKey,
      'proximity': '${center.longitude},${center.latitude}',
      'limit': '$limit',
    });

    final result = await _client.getJson(uri);
    return result.when(
      ok: (json) {
        final features =
            (json['features'] as List? ?? []).cast<Map<String, dynamic>>();
        final spots = features
            .map(_toParkingSpot)
            .whereType<ParkingSpot>()
            .where((s) => s.distanceMeters == null || s.distanceMeters! <= radiusMeters)
            .toList();
        return Result.ok(spots);
      },
      err: (f) => Result.err(f),
    );
  }

  ParkingSpot? _toParkingSpot(Map<String, dynamic> feature) {
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
    final coordinates = (geometry['coordinates'] as List?) ?? const [0, 0];
    if (coordinates.length < 2) return null;

    final metadata = properties['metadata'] as Map<String, dynamic>? ?? {};

    return ParkingSpot(
      id: (properties['mapbox_id'] ?? feature['id'] ?? '').toString(),
      name: (properties['name'] ?? 'Parking').toString(),
      location: GeoPoint(
        longitude: (coordinates[0] as num).toDouble(),
        latitude: (coordinates[1] as num).toDouble(),
      ),
      address: (properties['full_address'] ?? properties['place_formatted'] ?? '')
          .toString(),
      distanceMeters: (properties['distance'] as num?)?.toDouble(),
      priceInfo: metadata['open_hours'] == null ? null : null, // Mapbox
      // Search Box does not currently expose structured parking price
      // data — left null rather than guessed. Kept as an explicit
      // no-op branch (not omitted) so future provider fields are easy
      // to wire in without hunting for where price should go.
      openingHours: _openingHoursText(metadata),
      rating: (metadata['rating'] as num?)?.toDouble(),
    );
  }

  String? _openingHoursText(Map<String, dynamic> metadata) {
    final openHours = metadata['open_hours'];
    if (openHours is Map && openHours['is_24_hours'] == true) {
      return 'Open 24 hours';
    }
    return null;
  }
}
