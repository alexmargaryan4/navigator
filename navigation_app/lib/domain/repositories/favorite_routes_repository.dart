import '../../core/errors/result.dart';
import '../entities/favorite_route.dart';

/// Local persistence contract for the user's favorite (saved) routes.
abstract interface class FavoriteRoutesRepository {
  Future<Result<List<FavoriteRoute>>> getAll();
  Future<Result<void>> save(FavoriteRoute route);
  Future<Result<void>> rename(String id, String newLabel);
  Future<Result<void>> delete(String id);
}
