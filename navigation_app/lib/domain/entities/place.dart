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
  });

  final String id;
  final String name;
  final String address;
  final GeoPoint location;
  final PlaceCategory category;
}
