import '../../domain/entities/geo_point.dart';
import '../../domain/entities/place.dart';

/// Maps Geoapify Address Autocomplete / Geocoding API JSON into domain
/// [Place] entities. Kept isolated in the data layer, mirroring
/// `PlaceModel` for Mapbox, so the domain layer never needs to know
/// Geoapify's response shape either.
///
/// Unlike Mapbox `/suggest`, every Geoapify autocomplete feature already
/// carries real coordinates — no separate "retrieve" step is needed, so
/// [Place.needsCoordinateResolution] is always `false` here.
class GeoapifyPlaceModel {
  static Place? fromFeature(Map<String, dynamic> feature) {
    final properties = feature['properties'] as Map<String, dynamic>?;
    if (properties == null) return null;

    final lat = properties['lat'];
    final lon = properties['lon'];
    if (lat is! num || lon is! num) return null;

    final placeId = (properties['place_id'] ?? '').toString();
    if (placeId.isEmpty) return null;

    return Place(
      id: placeId,
      name: _nameOf(properties),
      address: (properties['formatted'] ?? properties['address_line2'] ?? '')
          .toString(),
      location: GeoPoint(latitude: lat.toDouble(), longitude: lon.toDouble()),
      category: _categoryFrom(properties),
      source: PlaceSource.geoapify,
      relevance: _confidenceOf(properties),
    );
  }

  static String _nameOf(Map<String, dynamic> properties) {
    final name = properties['name'];
    if (name is String && name.isNotEmpty) return name;
    final addressLine1 = properties['address_line1'];
    if (addressLine1 is String && addressLine1.isNotEmpty) return addressLine1;
    final formatted = properties['formatted'];
    if (formatted is String && formatted.isNotEmpty) return formatted;
    return 'Unknown';
  }

  /// Geoapify's `rank.confidence` (0–1) — used as a base relevance
  /// signal before [HybridSearchService] applies its own scoring.
  static double _confidenceOf(Map<String, dynamic> properties) {
    final rank = properties['rank'] as Map<String, dynamic>?;
    final confidence = rank?['confidence'];
    if (confidence is num) return confidence.toDouble();
    return 0.5;
  }

  static PlaceCategory _categoryFrom(Map<String, dynamic> properties) {
    final category = (properties['category'] ?? '').toString().toLowerCase();

    if (category.contains('parking')) return PlaceCategory.parking;
    if (category.contains('catering') || category.contains('restaurant') ||
        category.contains('food')) {
      return PlaceCategory.restaurant;
    }
    if (category.contains('commercial') || category.contains('shop')) {
      return PlaceCategory.shop;
    }
    if (category.contains('airport')) return PlaceCategory.airport;
    if (category.contains('hospital') || category.contains('healthcare')) {
      return PlaceCategory.hospital;
    }
    if (category.contains('fuel') || category.contains('gas')) {
      return PlaceCategory.gasStation;
    }
    if (category.contains('tourism') || category.contains('attraction')) {
      return PlaceCategory.attraction;
    }
    if (category.contains('heritage') || category.contains('monument')) {
      return PlaceCategory.landmark;
    }

    final resultType = (properties['result_type'] ?? '').toString();
    return switch (resultType) {
      'building' || 'amenity' => PlaceCategory.address,
      'street' => PlaceCategory.street,
      'city' || 'suburb' || 'district' => PlaceCategory.city,
      'country' => PlaceCategory.country,
      _ => PlaceCategory.other,
    };
  }
}
