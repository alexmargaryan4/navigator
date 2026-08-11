import '../../core/errors/result.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/parking_spot.dart';
import '../../domain/repositories/parking_repository.dart';
import '../datasources/mapbox_parking_datasource.dart';

class ParkingRepositoryImpl implements ParkingRepository {
  ParkingRepositoryImpl(this._dataSource);

  final MapboxParkingDataSource _dataSource;

  @override
  Future<Result<List<ParkingSpot>>> nearbyParking({
    required GeoPoint center,
    double radiusMeters = 1500,
    int limit = 20,
  }) {
    return _dataSource.nearbyParking(
      center: center,
      radiusMeters: radiusMeters,
      limit: limit,
    );
  }
}
