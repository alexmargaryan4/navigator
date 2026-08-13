import 'geo_point.dart';

/// The «По пути» categories the app knows how to search for along an
/// active route. Each maps to a real Mapbox Search Box category — see
/// [AlongRoutePoiCategoryX.mapboxCategory].
enum AlongRoutePoiCategory {
  parking,
  gasStation,
  cafe,
  restaurant,
  shop,
  evCharging,
}

extension AlongRoutePoiCategoryX on AlongRoutePoiCategory {
  /// Mapbox Search Box `/category/{category}` slug.
  String get mapboxCategory => switch (this) {
        AlongRoutePoiCategory.parking => 'parking',
        AlongRoutePoiCategory.gasStation => 'gas_station',
        AlongRoutePoiCategory.cafe => 'cafe',
        AlongRoutePoiCategory.restaurant => 'restaurant',
        AlongRoutePoiCategory.shop => 'grocery',
        AlongRoutePoiCategory.evCharging => 'charging_station',
      };

  String get label => switch (this) {
        AlongRoutePoiCategory.parking => 'Parking',
        AlongRoutePoiCategory.gasStation => 'Gas station',
        AlongRoutePoiCategory.cafe => 'Cafe',
        AlongRoutePoiCategory.restaurant => 'Restaurant',
        AlongRoutePoiCategory.shop => 'Shop',
        AlongRoutePoiCategory.evCharging => 'EV charging',
      };
}

/// A real POI found near the *route geometry* (not just near the user —
/// product spec «По пути»). [distanceFromRouteMeters] is how far this
/// POI sits from the closest point on the route, which is what makes
/// this different from a plain nearby-search result.
class AlongRoutePoi {
  const AlongRoutePoi({
    required this.id,
    required this.name,
    required this.location,
    required this.address,
    required this.category,
    required this.distanceFromRouteMeters,
    this.distanceAlongRouteMeters,
    this.rating,
    this.openingHours,
  });

  final String id;
  final String name;
  final GeoPoint location;
  final String address;
  final AlongRoutePoiCategory category;

  /// Real perpendicular-ish distance to the nearest sampled point on the
  /// route geometry — the core signal that makes this "along the route"
  /// rather than merely "near the user".
  final double distanceFromRouteMeters;

  /// How far along the route (from the origin) the nearest route point
  /// is, so results can be ordered "in the order you'll pass them".
  final double? distanceAlongRouteMeters;

  final double? rating;
  final String? openingHours;
}
