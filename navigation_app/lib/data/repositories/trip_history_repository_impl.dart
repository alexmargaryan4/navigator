import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../domain/entities/trip_history_entry.dart';
import '../../domain/repositories/trip_history_repository.dart';
import '../local/local_json_store.dart';

class TripHistoryRepositoryImpl implements TripHistoryRepository {
  TripHistoryRepositoryImpl({LocalJsonStore? store})
      : _store = store ?? const LocalJsonStore('trip_history_v1');

  final LocalJsonStore _store;

  @override
  Future<Result<List<TripHistoryEntry>>> getAll() async {
    try {
      final raw = await _store.readList();
      final entries = raw.map(TripHistoryEntry.fromJson).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return Result.ok(entries);
    } catch (e) {
      return Result.err(UnknownFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> add(TripHistoryEntry entry) async {
    try {
      final raw = await _store.readList();
      raw.add(entry.toJson());
      // Keep only the newest [TripHistoryRepository.maxEntries] — sort
      // newest-first, then truncate, so an unbounded local history file
      // never accumulates on a device with no backend to prune it.
      raw.sort((a, b) {
        final da = DateTime.tryParse(a['date'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse(b['date'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
      final trimmed = raw.take(TripHistoryRepository.maxEntries).toList();
      await _store.writeList(trimmed);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(UnknownFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> clear() async {
    try {
      await _store.writeList([]);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(UnknownFailure(technicalDetail: e.toString()));
    }
  }
}
