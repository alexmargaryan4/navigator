import '../../core/config/app_config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/networking/api_client.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/place.dart';
import '../../domain/repositories/search_provider.dart';
import '../models/place_model.dart';

/// Talks directly to Mapbox's Search Box API (autocomplete + retrieve)
/// and Geocoding API (reverse geocoding). No backend proxy — see the
/// product architecture requirement that Flutter calls providers
/// directly.
class MapboxSearchDataSource {
  MapboxSearchDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  static const String _searchBoxBase = '${AppConfig.mapboxBaseUrl}/search/searchbox/v1';
  static const String _geocodingBase = '${AppConfig.mapboxBaseUrl}/geocoding/v5/mapbox.places';

  Future<Result<List<Place>>> suggest(
    String query, {
    GeoPoint? proximity,
    int limit = 8,
  }) async {
    if (!AppConfig.hasMapKey) {
      return const Result.err(ConfigurationFailure());
    }
    final uri = Uri.parse('$_searchBoxBase/suggest').replace(queryParameters: {
      'q': query,
      'access_token': AppConfig.mapApiKey,
      'session_token': _sessionToken,
      'limit': '$limit',
      if (proximity != null)
        'proximity': '${proximity.longitude},${proximity.latitude}',
    });

    final result = await _client.getJson(uri);
    return result.when(
      ok: (json) {
        final suggestions = (json['suggestions'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        // Suggestions from /suggest don't carry coordinates — resolve
        // each via /retrieve is expensive for a full list, so for list
        // display we use the geocoding endpoint instead when precise
        // coordinates are needed immediately. Here we surface what the
        // Search Box API actually gives us for a suggestion list.
        final places = suggestions
            .map((s) => PlaceModel.fromSearchSuggestion(s))
            .whereType<Place>()
            .toList();
        return Result.ok(places);
      },
      err: (f) => Result.err(f),
    );
  }

  /// Resolves a previously-suggested `mapboxId` into a full [Place] with
  /// coordinates, via the Search Box `/retrieve` endpoint.
  Future<Result<Place>> retrieve(String mapboxId) async {
    if (!AppConfig.hasMapKey) {
      return const Result.err(ConfigurationFailure());
    }
    final encodedId = Uri.encodeComponent(mapboxId);
    final uri = Uri.parse('$_searchBoxBase/retrieve/$encodedId').replace(
      queryParameters: {
        'access_token': AppConfig.mapApiKey,
        'session_token': _sessionToken,
      },
    );
    final result = await _client.getJson(uri);
    return result.when(
      ok: (json) {
        final features = (json['features'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        if (features.isEmpty) {
          return const Result.err(GeocodingFailure());
        }
        return Result.ok(PlaceModel.fromSearchBoxFeature(features.first));
      },
      err: (f) => Result.err(f),
    );
  }

  /// Forward geocoding via the Geocoding API — used for a single
  /// best-match resolution (e.g. AI navigation destination text), where
  /// we don't need an interactive suggestion list.
  Future<Result<Place>> geocodeOne(String query, {GeoPoint? proximity}) async {
    if (!AppConfig.hasMapKey) {
      return const Result.err(ConfigurationFailure());
    }
    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse('$_geocodingBase/$encoded.json').replace(
      queryParameters: {
        'access_token': AppConfig.mapApiKey,
        'limit': '1',
        if (proximity != null)
          'proximity': '${proximity.longitude},${proximity.latitude}',
      },
    );
    final result = await _client.getJson(uri);
    return result.when(
      ok: (json) {
        final features = (json['features'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        if (features.isEmpty) {
          return const Result.err(GeocodingFailure());
        }
        return Result.ok(PlaceModel.fromGeocodingFeature(features.first));
      },
      err: (f) => Result.err(f),
    );
  }

  Future<Result<Place>> reverseGeocode(GeoPoint point) async {
    if (!AppConfig.hasMapKey) {
      return const Result.err(ConfigurationFailure());
    }
    final uri = Uri.parse(
      '$_geocodingBase/${point.longitude},${point.latitude}.json',
    ).replace(queryParameters: {
      'access_token': AppConfig.mapApiKey,
      'limit': '1',
    });
    final result = await _client.getJson(uri);
    return result.when(
      ok: (json) {
        final features = (json['features'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        if (features.isEmpty) {
          return const Result.err(GeocodingFailure());
        }
        return Result.ok(PlaceModel.fromGeocodingFeature(features.first));
      },
      err: (f) => Result.err(f),
    );
  }

  /// A single session token reused for the lifetime of the datasource so
  /// Mapbox bills a suggest→retrieve flow as one session, per their
  /// pricing model. Regenerated each time the app restarts.
  static final String _sessionToken =
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);
}

/// Adapts [MapboxSearchDataSource] to the provider-agnostic
/// [SearchProvider] contract so [HybridSearchService] can run it
/// side-by-side with any other provider (Geoapify, and future ones)
/// without knowing anything Mapbox-specific.
///
/// Mapbox `/suggest` results don't carry coordinates — resolving them is
/// comparatively expensive (one `/retrieve` call per suggestion) and is
/// only actually needed for the single result the user taps, not the
/// whole list. So this provider intentionally surfaces suggestions with
/// [Place.needsCoordinateResolution] set to true and a `(0, 0)`
/// placeholder location; [HybridSearchService] and downstream ranking
/// account for that (see `HybridSearchService._rankingLocation`), and
/// the UI layer resolves the real coordinates via
/// `SearchRepositoryImpl.resolveSelection` only for the picked result.
class MapboxSearchProvider implements SearchProvider {
  MapboxSearchProvider(this._dataSource);

  final MapboxSearchDataSource _dataSource;

  @override
  String get name => 'mapbox';

  @override
  Future<Result<List<Place>>> search(
    String query, {
    GeoPoint? proximity,
    int limit = 8,
  }) {
    return _dataSource.suggest(query, proximity: proximity, limit: limit);
  }

  @override
  Future<Result<Place>> reverseGeocode(GeoPoint point) {
    return _dataSource.reverseGeocode(point);
  }
}
