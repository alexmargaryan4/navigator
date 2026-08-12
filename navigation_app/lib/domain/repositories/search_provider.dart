import '../../core/errors/result.dart';
import '../entities/geo_point.dart';
import '../entities/place.dart';

/// Contract implemented by every individual search backend (Mapbox,
/// Geoapify, and any future provider — Google, HERE, etc).
///
/// [HybridSearchService] fans a query out to every registered
/// [SearchProvider] in parallel, then merges/dedupes/ranks the combined
/// results. Adding a new provider means writing one class that
/// implements this interface and registering it with the service —
/// nothing about the merge/dedup/ranking pipeline needs to change.
///
/// Implementations must never throw for expected failure modes (network
/// errors, missing API key, provider outage, no results) — always
/// return a [Result.err] so [HybridSearchService] can degrade
/// gracefully and fall back to whichever other providers are still
/// working.
abstract interface class SearchProvider {
  /// A short, stable identifier used for dedup/ranking bookkeeping and
  /// logs (e.g. `'mapbox'`, `'geoapify'`). Not shown to the user.
  String get name;

  /// Autocomplete-style free-text search, optionally biased toward
  /// [proximity]. Returns up to [limit] candidate places.
  Future<Result<List<Place>>> search(
    String query, {
    GeoPoint? proximity,
    int limit = 8,
  });

  /// Reverse-geocodes a coordinate into a human-readable place.
  Future<Result<Place>> reverseGeocode(GeoPoint point);
}
