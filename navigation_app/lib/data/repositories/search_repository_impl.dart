import '../../core/errors/result.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/place.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/mapbox_search_datasource.dart';
import '../services/hybrid_search_service.dart';

/// [SearchRepository] backed by [HybridSearchService] — every live
/// search and reverse-geocode call goes through both Mapbox and
/// Geoapify in parallel and comes back as one merged, deduplicated,
/// ranked list. The UI layer never talks to either provider directly.
class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(
    this._hybridSearch, {
    required MapboxSearchDataSource mapboxDataSource,
  }) : _mapboxDataSource = mapboxDataSource;

  final HybridSearchService _hybridSearch;

  /// Kept directly (rather than only reached through a provider
  /// adapter) for two Mapbox-specific calls that are intentionally
  /// *not* part of the hybrid fan-out: `/retrieve` (resolving a single
  /// picked suggestion's coordinates) and the single-result forward
  /// geocode used by AI navigation. Neither benefits from querying a
  /// second provider — see [resolveOne] and [resolveSelection].
  final MapboxSearchDataSource _mapboxDataSource;

  @override
  Future<Result<List<Place>>> search(
    String query, {
    GeoPoint? proximity,
    int limit = 8,
  }) {
    return _hybridSearch.search(query, proximity: proximity, limit: limit);
  }

  @override
  Future<Result<Place>> resolveOne(String query, {GeoPoint? proximity}) {
    return _mapboxDataSource.geocodeOne(query, proximity: proximity);
  }

  @override
  Future<Result<List<Place>>> searchForAi(String query, {GeoPoint? proximity}) {
    // Deliberately the exact same pipeline the search sheet uses —
    // Mapbox + Geoapify in parallel, deduplicated, ranked (see
    // HybridSearchService) — so AI navigation can never produce a
    // destination the real search UI wouldn't also have found. Per the
    // product spec, the AI is never the source of geographic truth;
    // this hybrid search is.
    return _hybridSearch.search(query, proximity: proximity, limit: 5);
  }

  @override
  Future<Result<Place>> reverseGeocode(GeoPoint point) {
    return _hybridSearch.reverseGeocode(point);
  }

  @override
  Future<Result<Place>> resolveSelection(Place place) {
    if (!place.needsCoordinateResolution) {
      // Geoapify (and already-resolved Mapbox) results carry real
      // coordinates straight from the autocomplete response — nothing
      // further to fetch.
      return Future.value(Result.ok(place));
    }
    // Only Mapbox `/suggest` entries set needsCoordinateResolution, so
    // this id is always a Mapbox id here.
    return _mapboxDataSource.retrieve(place.id);
  }
}
