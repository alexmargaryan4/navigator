import '../../core/errors/result.dart';
import '../entities/geo_point.dart';
import '../entities/place.dart';

/// Contract for resolving free-text queries into real [Place]s.
///
/// Implementations must only ever return data returned by the provider —
/// never synthesize or guess coordinates/addresses.
abstract interface class SearchRepository {
  /// Autocomplete-style search, optionally biased toward [proximity] so
  /// nearby results are ranked first.
  Future<Result<List<Place>>> search(
    String query, {
    GeoPoint? proximity,
    int limit = 8,
  });

  /// Resolves a single best-match place for [query] (used by AI
  /// navigation, where a single destination must be picked).
  Future<Result<Place>> resolveOne(String query, {GeoPoint? proximity});

  /// Reverse-geocodes a coordinate into a human-readable place (e.g. for
  /// "long-press on map" or showing the current road name).
  Future<Result<Place>> reverseGeocode(GeoPoint point);

  /// Resolves the final, usable coordinates for a result the user just
  /// tapped in the search list.
  ///
  /// This is the single call site the UI needs after a selection —
  /// which provider the result came from, and whether that provider
  /// needs an extra round trip to get coordinates, stays an
  /// implementation detail here rather than leaking into the search
  /// screen. Concretely: Geoapify results already carry real
  /// coordinates and are returned as-is; Mapbox `/suggest` results
  /// (`Place.needsCoordinateResolution == true`) are resolved via
  /// Mapbox `/retrieve` first.
  Future<Result<Place>> resolveSelection(Place place);
}
