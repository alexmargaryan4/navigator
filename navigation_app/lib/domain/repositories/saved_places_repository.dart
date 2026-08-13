import '../../core/errors/result.dart';
import '../entities/saved_place.dart';

/// Local persistence contract for the user's saved places. Backed by
/// on-device storage only (no backend — see README "Scope"), so every
/// method is effectively synchronous work wrapped in a Future for a
/// consistent async API with the rest of the app.
abstract interface class SavedPlacesRepository {
  Future<Result<List<SavedPlace>>> getAll();
  Future<Result<void>> save(SavedPlace place);
  Future<Result<void>> rename(String id, String newLabel);
  Future<Result<void>> delete(String id);
}
