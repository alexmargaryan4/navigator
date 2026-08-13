import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../domain/entities/saved_place.dart';
import '../../domain/repositories/saved_places_repository.dart';
import '../local/local_json_store.dart';

class SavedPlacesRepositoryImpl implements SavedPlacesRepository {
  SavedPlacesRepositoryImpl({LocalJsonStore? store})
      : _store = store ?? const LocalJsonStore('saved_places_v1');

  final LocalJsonStore _store;

  @override
  Future<Result<List<SavedPlace>>> getAll() async {
    try {
      final raw = await _store.readList();
      final places = raw.map(SavedPlace.fromJson).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Result.ok(places);
    } catch (e) {
      return Result.err(UnknownFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> save(SavedPlace place) async {
    try {
      final raw = await _store.readList();
      final withoutExisting =
          raw.where((j) => j['id'] != place.id).toList();
      withoutExisting.add(place.toJson());
      await _store.writeList(withoutExisting);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(UnknownFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> rename(String id, String newLabel) async {
    try {
      final raw = await _store.readList();
      final updated = raw.map((j) {
        if (j['id'] == id) {
          return {...j, 'label': newLabel};
        }
        return j;
      }).toList();
      await _store.writeList(updated);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(UnknownFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      final raw = await _store.readList();
      raw.removeWhere((j) => j['id'] == id);
      await _store.writeList(raw);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(UnknownFailure(technicalDetail: e.toString()));
    }
  }
}
