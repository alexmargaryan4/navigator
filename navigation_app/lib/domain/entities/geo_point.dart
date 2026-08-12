import 'dart:math' as math;

/// A plain latitude/longitude pair used throughout the domain layer.
///
/// Deliberately independent of any map SDK's native point type — data and
/// domain layers must never import a map/routing package directly.
class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  static const double _earthRadiusMeters = 6371000;

  /// Great-circle distance to [other], in meters, via the haversine
  /// formula. Used by the hybrid search pipeline both to decide whether
  /// two providers' results describe the same real-world place
  /// (deduplication) and as a "distance from the user" ranking signal —
  /// never for turn-by-turn routing, where the routing provider's own
  /// road-network distance is used instead.
  double distanceTo(GeoPoint other) {
    final lat1 = latitude * math.pi / 180;
    final lat2 = other.latitude * math.pi / 180;
    final dLat = (other.latitude - latitude) * math.pi / 180;
    final dLon = (other.longitude - longitude) * math.pi / 180;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}
