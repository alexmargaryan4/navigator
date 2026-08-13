import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/repository_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/favorite_route.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/route_stop.dart';
import '../../../domain/entities/travel_mode.dart';

/// Loads/mutates the user's favorite (saved) whole routes (product spec
/// "Избранные маршруты") straight from [FavoriteRoutesRepository] — real
/// on-device persistence, no in-memory placeholder.
class FavoriteRoutesController
    extends AutoDisposeAsyncNotifier<List<FavoriteRoute>> {
  @override
  Future<List<FavoriteRoute>> build() async {
    final repo = ref.watch(favoriteRoutesRepositoryProvider);
    final result = await repo.getAll();
    return result.when(ok: (routes) => routes, err: (f) => throw f);
  }

  /// Saves the current trip (origin resolved by the caller, destination
  /// + stops as real, already-geocoded [Place]s) as a new favorite
  /// route under [label] — e.g. "Дом → Работа".
  Future<AppFailure?> save({
    required String label,
    required Place origin,
    required Place destination,
    List<RouteStop> stops = const [],
    TravelMode mode = TravelMode.driving,
  }) async {
    final repo = ref.read(favoriteRoutesRepositoryProvider);
    final route = FavoriteRoute(
      id: 'favorite_route_${DateTime.now().microsecondsSinceEpoch}',
      label: label,
      origin: FavoriteRouteEndpoint(
        name: origin.name,
        address: origin.address,
        location: origin.location,
      ),
      destination: FavoriteRouteEndpoint(
        name: destination.name,
        address: destination.address,
        location: destination.location,
      ),
      stops: stops
          .map((s) => FavoriteRouteEndpoint(
                name: s.place.name,
                address: s.place.address,
                location: s.place.location,
              ))
          .toList(),
      mode: mode,
      createdAt: DateTime.now(),
    );
    final result = await repo.save(route);
    return result.when(
      ok: (_) {
        ref.invalidateSelf();
        return null;
      },
      err: (f) => f,
    );
  }

  Future<AppFailure?> rename(String id, String newLabel) async {
    final repo = ref.read(favoriteRoutesRepositoryProvider);
    final result = await repo.rename(id, newLabel);
    return result.when(
      ok: (_) {
        ref.invalidateSelf();
        return null;
      },
      err: (f) => f,
    );
  }

  Future<AppFailure?> delete(String id) async {
    final repo = ref.read(favoriteRoutesRepositoryProvider);
    final result = await repo.delete(id);
    return result.when(
      ok: (_) {
        ref.invalidateSelf();
        return null;
      },
      err: (f) => f,
    );
  }
}

final favoriteRoutesControllerProvider = AutoDisposeAsyncNotifierProvider<
    FavoriteRoutesController, List<FavoriteRoute>>(
  FavoriteRoutesController.new,
);
