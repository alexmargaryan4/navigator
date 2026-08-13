import '../../core/errors/result.dart';
import '../entities/trip_history_entry.dart';

/// Local persistence contract for trip history. Newest-first ordering
/// is the repository's responsibility so every consumer sees the same
/// order without re-sorting.
abstract interface class TripHistoryRepository {
  Future<Result<List<TripHistoryEntry>>> getAll();
  Future<Result<void>> add(TripHistoryEntry entry);
  Future<Result<void>> clear();

  /// Caps how many entries are retained on disk — old entries beyond
  /// this are dropped silently on the next [add], so history can't grow
  /// unbounded on a device with no backend to offload to.
  static const int maxEntries = 100;
}
