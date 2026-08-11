import '../../domain/entities/geo_point.dart';
import '../../domain/entities/parking_spot.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/route.dart';

/// Builds the raw GeoJSON maps `maplibre_gl` sources expect.
///
/// Kept isolated here so widgets never hand-roll GeoJSON shapes inline —
/// one place to get the coordinate order right (GeoJSON is
/// `[longitude, latitude]`, the opposite of [GeoPoint]'s constructor).
abstract final class GeoJsonBuilder {
  static Map<String, dynamic> point(GeoPoint p, {Map<String, dynamic>? properties}) {
    return {
      'type': 'Feature',
      'properties': properties ?? const {},
      'geometry': {
        'type': 'Point',
        'coordinates': [p.longitude, p.latitude],
      },
    };
  }

  static Map<String, dynamic> lineString(
    List<GeoPoint> points, {
    Map<String, dynamic>? properties,
  }) {
    return {
      'type': 'Feature',
      'properties': properties ?? const {},
      'geometry': {
        'type': 'LineString',
        'coordinates': points.map((p) => [p.longitude, p.latitude]).toList(),
      },
    };
  }

  static Map<String, dynamic> featureCollection(
    List<Map<String, dynamic>> features,
  ) {
    return {'type': 'FeatureCollection', 'features': features};
  }

  static Map<String, dynamic> routeLine(NavRoute route) => featureCollection([
        lineString(route.geometry, properties: {
          'routeId': route.id,
          'isPrimary': route.isPrimary,
        }),
      ]);

  static Map<String, dynamic> alternativeRoutes(List<NavRoute> routes) =>
      featureCollection(
        routes
            .where((r) => !r.isPrimary)
            .map((r) => lineString(r.geometry, properties: {'routeId': r.id}))
            .toList(),
      );

  static Map<String, dynamic> singleMarker(GeoPoint location, {String? label}) =>
      featureCollection([
        point(location, properties: {'label': label ?? ''}),
      ]);

  static Map<String, dynamic> placeMarkers(List<Place> places) =>
      featureCollection(
        places
            .map((p) => point(p.location, properties: {
                  'id': p.id,
                  'name': p.name,
                  'category': p.category.name,
                }))
            .toList(),
      );

  static Map<String, dynamic> parkingMarkers(List<ParkingSpot> spots) =>
      featureCollection(
        spots
            .map((s) => point(s.location, properties: {
                  'id': s.id,
                  'name': s.name,
                }))
            .toList(),
      );
}
