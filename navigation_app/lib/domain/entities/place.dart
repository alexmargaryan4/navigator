import 'geo_point.dart';

enum PlaceCategory {
  address,
  city,
  street,
  country,
  restaurant,
  shop,
  airport,
  hospital,
  gasStation,
  landmark,
  attraction,
  parking,
  other,
}

/// Which search provider a [Place] came from. Used by the hybrid search
/// pipeline for deduplication/ranking signals and by the UI layer to
/// decide whether a coordinate-resolve step (`/retrieve`) is needed
/// before the place can be used for routing/centering — see
/// [Place.needsCoordinateResolution].
///
/// Deliberately lives in the domain layer (not `data/`) because
/// [Place] itself — a domain entity — needs to carry it. It says *which*
/// provider answered, never how to talk to that provider.
enum PlaceSource { mapbox, geoapify }

/// A geocoded place or point of interest, as returned by the search /
/// geocoding provider. Every field is real provider data — nothing here
/// is ever synthesized client-side.
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.category,
    this.source,
    this.needsCoordinateResolution = false,
    this.matchedProviders = const [],
    this.relevance = 0,
  });

  final String id;
  final String name;
  final String address;
  final GeoPoint location;
  final PlaceCategory category;

  /// Which provider this particular result came from. `null` for places
  /// constructed outside the hybrid search pipeline (e.g. reverse
  /// geocoding), where the distinction doesn't matter.
  final PlaceSource? source;

  /// True when [location] is a placeholder and the real coordinates
  /// still need to be resolved (Mapbox Search Box `/suggest` entries —
  /// see `MapboxSearchDataSource`) before this place can be used for
  /// routing, centering the map, or distance/dedup calculations.
  /// Geoapify autocomplete results always carry real coordinates
  /// up front, so this is always `false` for [PlaceSource.geoapify].
  final bool needsCoordinateResolution;

  /// When the hybrid search service finds the same real-world place
  /// returned by more than one provider, it merges them into a single
  /// result and records every provider that matched here. An empty list
  /// means this place was only checked against a single provider's
  /// results (e.g. it's a raw, not-yet-merged candidate).
  final List<PlaceSource> matchedProviders;

  /// Internal ranking score assigned by [HybridSearchService] — higher
  /// is more relevant. Not sourced from any provider; purely a
  /// client-side ordering signal, kept on the entity so the UI/tests can
  /// inspect final ordering without reaching into service internals.
  final double relevance;

  Place copyWith({
    String? id,
    String? name,
    String? address,
    GeoPoint? location,
    PlaceCategory? category,
    PlaceSource? source,
    bool? needsCoordinateResolution,
    List<PlaceSource>? matchedProviders,
    double? relevance,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      location: location ?? this.location,
      category: category ?? this.category,
      source: source ?? this.source,
      needsCoordinateResolution:
          needsCoordinateResolution ?? this.needsCoordinateResolution,
      matchedProviders: matchedProviders ?? this.matchedProviders,
      relevance: relevance ?? this.relevance,
    );
  }
}
