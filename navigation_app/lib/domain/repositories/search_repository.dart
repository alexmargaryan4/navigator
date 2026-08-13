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
  ///
  /// Deprecated for AI navigation's destination-resolution flow — see
  /// [searchForAi]. The AI must never have a destination silently picked
  /// for it without the option to see alternatives (product spec «Защита
  /// от неправильных мест при AI-поиске»); this remains for any
  /// non-interactive caller that genuinely needs exactly one result with
  /// no user in the loop.
  Future<Result<Place>> resolveOne(String query, {GeoPoint? proximity});

  /// Resolves [query] the same way the real search UI does — through
  /// the full hybrid Mapbox+Geoapify pipeline, deduplicated and ranked —
  /// for the AI navigation pipeline (product spec «AI Navigator Mode» /
  /// «Защита от неправильных мест при AI-поиске»).
  ///
  /// The AI only ever supplies [query] text; it never supplies
  /// coordinates. This is the single real geocoding step in that
  /// pipeline — the AI layer is not allowed to skip it. Returns the full
  /// ranked candidate list so the caller can auto-accept a
  /// high-confidence top result while still letting the user see and
  /// pick a different one.
  Future<Result<List<Place>>> searchForAi(String query, {GeoPoint? proximity});

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
