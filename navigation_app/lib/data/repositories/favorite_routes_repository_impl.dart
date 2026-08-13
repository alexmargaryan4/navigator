import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../domain/entities/favorite_route.dart';
import '../../domain/repositories/favorite_routes_repository.dart';
import '../local/local_json_store.dart';

class FavoriteRoutesRepositoryImpl implements FavoriteRoutesRepository {
  FavoriteRoutesRepositoryImpl({LocalJsonStore? store})
      : _store = store ?? const LocalJsonStore('favorite_routes_v1');

  final LocalJsonStore _store;

  @override
  Future<Result<List<FavoriteRoute>>> getAll() async {
    try {
      final raw = await _store.readList();
      final routes = raw.map(FavoriteRoute.fromJson).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Result.ok(routes);
    } catch (e) {
      return Result.err(UnknownFailure(technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> save(FavoriteRoute route) async {
    try {
      final raw = await _store.readList();
      final withoutExisting =
          raw.where((j) => j['id'] != route.id).toList();
      withoutExisting.add(route.toJson());
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
