import '../../core/config/app_config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/networking/api_client.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/place.dart';
import '../../domain/repositories/search_provider.dart';
import '../models/geoapify_place_model.dart';

/// Talks directly to Geoapify's Address Autocomplete API and Reverse
/// Geocoding API. No backend proxy — same direct-from-Flutter approach
/// as [MapboxSearchDataSource].
///
/// Geoapify is used purely as a *supplementary* search source alongside
/// Mapbox (see [HybridSearchService]) — it is never used for map tiles,
/// routing, or traffic, and Mapbox remains the sole source for those.
/// It specifically helps with small settlements and POIs — e.g. towns
/// and villages in Armenia — that Mapbox's own index sometimes misses.
class GeoapifySearchDataSource {
  GeoapifySearchDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  static const String _autocompleteUrl =
      '${AppConfig.geoapifyBaseUrl}/v1/geocode/autocomplete';
  static const String _reverseUrl =
      '${AppConfig.geoapifyBaseUrl}/v1/geocode/reverse';

  Future<Result<List<Place>>> autocomplete(
    String query, {
    GeoPoint? proximity,
    int limit = 8,
  }) async {
    if (!AppConfig.hasGeoapifyKey) {
      return const Result.err(ConfigurationFailure());
    }
    final uri = Uri.parse(_autocompleteUrl).replace(queryParameters: {
      'text': query,
      'apiKey': AppConfig.geoapifyApiKey,
      'format': 'json',
      'limit': '$limit',
      if (proximity != null)
        'bias': 'proximity:${proximity.longitude},${proximity.latitude}',
    });

    final result = await _client.getJson(uri);
    return result.when(
      ok: (json) {
        final results =
            (json['results'] as List? ?? []).cast<Map<String, dynamic>>();
        // The `format=json` response nests fields directly rather than
        // under a GeoJSON `properties` key — normalize to the same
        // `{'properties': {...}}` shape GeoapifyPlaceModel expects so
        // one mapper works for both this and reverse geocoding.
        final places = results
            .map((r) => GeoapifyPlaceModel.fromFeature({'properties': r}))
            .whereType<Place>()
            .toList();
        return Result.ok(places);
      },
      err: (f) => Result.err(f),
    );
  }

  Future<Result<Place>> reverseGeocode(GeoPoint point) async {
    if (!AppConfig.hasGeoapifyKey) {
      return const Result.err(ConfigurationFailure());
    }
    final uri = Uri.parse(_reverseUrl).replace(queryParameters: {
      'lat': '${point.latitude}',
      'lon': '${point.longitude}',
      'apiKey': AppConfig.geoapifyApiKey,
      'format': 'json',
      'limit': '1',
    });

    final result = await _client.getJson(uri);
    return result.when(
      ok: (json) {
        final results =
            (json['results'] as List? ?? []).cast<Map<String, dynamic>>();
        if (results.isEmpty) {
          return const Result.err(GeocodingFailure());
        }
        final place =
            GeoapifyPlaceModel.fromFeature({'properties': results.first});
        if (place == null) return const Result.err(GeocodingFailure());
        return Result.ok(place);
      },
      err: (f) => Result.err(f),
    );
  }
}

/// Adapts [GeoapifySearchDataSource] to the provider-agnostic
/// [SearchProvider] contract so [HybridSearchService] can run it
/// side-by-side with [MapboxSearchProvider] (see that class for why the
/// abstraction exists).
class GeoapifySearchProvider implements SearchProvider {
  GeoapifySearchProvider(this._dataSource);

  final GeoapifySearchDataSource _dataSource;

  @override
  String get name => 'geoapify';

  @override
  Future<Result<List<Place>>> search(
    String query, {
    GeoPoint? proximity,
    int limit = 8,
  }) {
    return _dataSource.autocomplete(query, proximity: proximity, limit: limit);
  }

  @override
  Future<Result<Place>> reverseGeocode(GeoPoint point) {
    return _dataSource.reverseGeocode(point);
  }
}
