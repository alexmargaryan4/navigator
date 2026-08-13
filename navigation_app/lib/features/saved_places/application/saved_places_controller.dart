import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/repository_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/saved_place.dart';

/// Loads/mutates the user's saved places (product spec "Сохранённые
/// места") straight from [SavedPlacesRepository] — real on-device
/// persistence, no in-memory placeholder.
class SavedPlacesController extends AutoDisposeAsyncNotifier<List<SavedPlace>> {
  @override
  Future<List<SavedPlace>> build() async {
    final repo = ref.watch(savedPlacesRepositoryProvider);
    final result = await repo.getAll();
    return result.when(ok: (places) => places, err: (f) => throw f);
  }

  Future<AppFailure?> saveFromPlace(
    Place place, {
    required String label,
    SavedPlaceIcon icon = SavedPlaceIcon.other,
  }) async {
    final repo = ref.read(savedPlacesRepositoryProvider);
    final saved = SavedPlace(
      id: 'saved_${DateTime.now().microsecondsSinceEpoch}',
      label: label,
      address: place.address,
      location: place.location,
      icon: icon,
      createdAt: DateTime.now(),
    );
    final result = await repo.save(saved);
    return result.when(
      ok: (_) {
        ref.invalidateSelf();
        return null;
      },
      err: (f) => f,
    );
  }

  Future<AppFailure?> rename(String id, String newLabel) async {
    final repo = ref.read(savedPlacesRepositoryProvider);
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
    final repo = ref.read(savedPlacesRepositoryProvider);
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

final savedPlacesControllerProvider =
    AutoDisposeAsyncNotifierProvider<SavedPlacesController, List<SavedPlace>>(
  SavedPlacesController.new,
);
