import '../../core/errors/result.dart';
import '../entities/geo_point.dart';
import '../entities/parking_spot.dart';

/// Contract for real nearby-parking search. Implementations must only
/// surface fields actually supplied by the places/POI provider.
abstract interface class ParkingRepository {
  Future<Result<List<ParkingSpot>>> nearbyParking({
    required GeoPoint center,
    double radiusMeters = 1500,
    int limit = 20,
  });
}
