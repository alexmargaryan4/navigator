import 'geo_point.dart';

/// A real parking location returned by the places/POI provider.
///
/// Every optional field is `null` when the provider doesn't supply it —
/// the UI must render "Not available" rather than inventing a value
/// (see requirement 43).
class ParkingSpot {
  const ParkingSpot({
    required this.id,
    required this.name,
    required this.location,
    required this.address,
    this.distanceMeters,
    this.priceInfo,
    this.openingHours,
    this.rating,
  });

  final String id;
  final String name;
  final GeoPoint location;
  final String address;
  final double? distanceMeters;
  final String? priceInfo;
  final String? openingHours;
  final double? rating;
}
