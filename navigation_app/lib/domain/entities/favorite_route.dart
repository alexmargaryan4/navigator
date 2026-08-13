import 'geo_point.dart';
import 'place.dart';
import 'travel_mode.dart';

/// A lightweight, storable endpoint for a [FavoriteRoute] — just enough
/// to re-run the trip later (name + real coordinates), not a full
/// [Place] (category/source/relevance are search-time concerns that
/// don't need to survive being saved to disk).
class FavoriteRouteEndpoint {
  const FavoriteRouteEndpoint({
    required this.name,
    required this.address,
    required this.location,
  });

  final String name;
  final String address;
  final GeoPoint location;

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'lat': location.latitude,
        'lng': location.longitude,
      };

  factory FavoriteRouteEndpoint.fromJson(Map<String, dynamic> json) =>
      FavoriteRouteEndpoint(
        name: json['name'] as String,
        address: json['address'] as String? ?? '',
        location: GeoPoint(
          latitude: (json['lat'] as num).toDouble(),
          longitude: (json['lng'] as num).toDouble(),
        ),
      );

  /// Converts back to a real, already-geocoded [Place] so the trip
  /// controller can re-launch this endpoint exactly as if the user had
  /// just picked it from search — never re-geocoded or guessed.
  Place toPlace() => Place(
        id: 'endpoint_${location.latitude}_${location.longitude}',
        name: name,
        address: address,
        location: location,
        category: PlaceCategory.other,
      );
}

/// A whole saved trip the user can launch with one tap (product spec
/// "Избранные маршруты"), e.g. "Дом → Работа". Optionally carries
/// intermediate stops so a favorite can also be a saved multi-stop trip.
class FavoriteRoute {
  const FavoriteRoute({
    required this.id,
    required this.label,
    required this.origin,
    required this.destination,
    this.stops = const [],
    this.mode = TravelMode.driving,
    required this.createdAt,
  });

  final String id;

  /// User-chosen name, e.g. "Дом → Работа". Falls back to
  /// "origin → destination" in the UI when the user didn't set one.
  final String label;
  final FavoriteRouteEndpoint origin;
  final FavoriteRouteEndpoint destination;
  final List<FavoriteRouteEndpoint> stops;
  final TravelMode mode;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'stops': stops.map((s) => s.toJson()).toList(),
        'mode': mode.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FavoriteRoute.fromJson(Map<String, dynamic> json) => FavoriteRoute(
        id: json['id'] as String,
        label: json['label'] as String,
        origin: FavoriteRouteEndpoint.fromJson(
            json['origin'] as Map<String, dynamic>),
        destination: FavoriteRouteEndpoint.fromJson(
            json['destination'] as Map<String, dynamic>),
        stops: ((json['stops'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(FavoriteRouteEndpoint.fromJson)
            .toList(),
        mode: TravelMode.values.firstWhere(
          (m) => m.name == json['mode'],
          orElse: () => TravelMode.driving,
        ),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
