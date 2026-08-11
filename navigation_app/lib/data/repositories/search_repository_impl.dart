import '../../core/errors/result.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/place.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/mapbox_search_datasource.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._dataSource);

  final MapboxSearchDataSource _dataSource;

  @override
  Future<Result<List<Place>>> search(
    String query, {
    GeoPoint? proximity,
    int limit = 8,
  }) {
    return _dataSource.suggest(query, proximity: proximity, limit: limit);
  }

  @override
  Future<Result<Place>> resolveOne(String query, {GeoPoint? proximity}) {
    return _dataSource.geocodeOne(query, proximity: proximity);
  }

  @override
  Future<Result<Place>> reverseGeocode(GeoPoint point) {
    return _dataSource.reverseGeocode(point);
  }

  /// Resolves full coordinates for a suggestion previously returned by
  /// [search] (Search Box `/suggest` entries carry no coordinates — see
  /// `PlaceModel.fromSearchSuggestion`). Call this when the user taps a
  /// search result, right before centering the map / starting routing.
  Future<Result<Place>> retrieveSuggestion(String mapboxId) {
    return _dataSource.retrieve(mapboxId);
  }
}
