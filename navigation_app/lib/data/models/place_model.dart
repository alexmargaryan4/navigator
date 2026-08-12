import '../../domain/entities/geo_point.dart';
import '../../domain/entities/place.dart';

/// Maps Mapbox Search Box / Geocoding API JSON into domain [Place]
/// entities. Kept isolated in the data layer so the domain layer never
/// needs to know Mapbox's response shape.
class PlaceModel {
  static Place fromSearchBoxFeature(Map<String, dynamic> feature) {
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
    final coordinates = (geometry['coordinates'] as List?) ?? const [0, 0];

    return Place(
      id: (properties['mapbox_id'] ?? feature['id'] ?? '').toString(),
      name: (properties['name'] ?? properties['place_name'] ?? 'Unknown')
          .toString(),
      address: (properties['full_address'] ?? properties['place_formatted'] ?? '')
          .toString(),
      location: GeoPoint(
        longitude: (coordinates[0] as num).toDouble(),
        latitude: (coordinates[1] as num).toDouble(),
      ),
      category: _categoryFrom(properties),
      source: PlaceSource.mapbox,
    );
  }

  /// Maps a Search Box `/suggest` entry.
  ///
  /// `/suggest` results intentionally do not include coordinates (Mapbox
  /// requires a separate `/retrieve` call per selection) — [location] is
  /// therefore a placeholder `(0, 0)` and callers MUST call
  /// `MapboxSearchDataSource.retrieve` with [Place.id] before using this
  /// place for routing, centering the map, or anything coordinate-based.
  /// Returns `null` if the suggestion is missing a usable id.
  static Place? fromSearchSuggestion(Map<String, dynamic> suggestion) {
    final mapboxId = suggestion['mapbox_id'];
    if (mapboxId == null) return null;

    return Place(
      id: mapboxId.toString(),
      name: (suggestion['name'] ?? 'Unknown').toString(),
      address: (suggestion['full_address'] ??
              suggestion['place_formatted'] ??
              '')
          .toString(),
      location: const GeoPoint(latitude: 0, longitude: 0),
      category: _categoryFrom(suggestion),
      source: PlaceSource.mapbox,
      needsCoordinateResolution: true,
    );
  }

  static Place fromGeocodingFeature(Map<String, dynamic> feature) {
    final center = (feature['center'] as List?) ?? const [0, 0];
    final placeType = (feature['place_type'] as List?)?.cast<String>() ?? const [];

    return Place(
      id: (feature['id'] ?? '').toString(),
      name: (feature['text'] ?? feature['place_name'] ?? 'Unknown').toString(),
      address: (feature['place_name'] ?? '').toString(),
      location: GeoPoint(
        longitude: (center[0] as num).toDouble(),
        latitude: (center[1] as num).toDouble(),
      ),
      category: _categoryFromPlaceType(placeType),
      source: PlaceSource.mapbox,
    );
  }

  static PlaceCategory _categoryFrom(Map<String, dynamic> properties) {
    final poiCategories =
        (properties['poi_category'] as List?)?.cast<String>() ?? const [];
    final joined = poiCategories.join(',').toLowerCase();

    if (joined.contains('parking')) return PlaceCategory.parking;
    if (joined.contains('restaurant') || joined.contains('food')) {
      return PlaceCategory.restaurant;
    }
    if (joined.contains('shop') || joined.contains('store')) {
      return PlaceCategory.shop;
    }
    if (joined.contains('airport')) return PlaceCategory.airport;
    if (joined.contains('hospital') || joined.contains('clinic')) {
      return PlaceCategory.hospital;
    }
    if (joined.contains('gas') || joined.contains('fuel')) {
      return PlaceCategory.gasStation;
    }
    if (joined.contains('landmark')) return PlaceCategory.landmark;
    if (joined.contains('attraction') || joined.contains('tourism')) {
      return PlaceCategory.attraction;
    }

    final featureType = (properties['feature_type'] ?? '').toString();
    return switch (featureType) {
      'address' => PlaceCategory.address,
      'place' => PlaceCategory.city,
      'street' => PlaceCategory.street,
      'country' => PlaceCategory.country,
      _ => PlaceCategory.other,
    };
  }

  static PlaceCategory _categoryFromPlaceType(List<String> placeType) {
    if (placeType.contains('address')) return PlaceCategory.address;
    if (placeType.contains('place')) return PlaceCategory.city;
    if (placeType.contains('country')) return PlaceCategory.country;
    if (placeType.contains('poi')) return PlaceCategory.other;
    return PlaceCategory.other;
  }
}
