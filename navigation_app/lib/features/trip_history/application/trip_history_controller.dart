import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/repository_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/trip_history_entry.dart';

/// Loads/clears the user's trip history (product spec "История
/// маршрутов") straight from [TripHistoryRepository]. Entries are
/// written by [TripController] whenever a trip is started or completed
/// — this controller is read/delete only, it never fabricates entries.
class TripHistoryController
    extends AutoDisposeAsyncNotifier<List<TripHistoryEntry>> {
  @override
  Future<List<TripHistoryEntry>> build() async {
    final repo = ref.watch(tripHistoryRepositoryProvider);
    final result = await repo.getAll();
    return result.when(ok: (entries) => entries, err: (f) => throw f);
  }

  Future<AppFailure?> clear() async {
    final repo = ref.read(tripHistoryRepositoryProvider);
    final result = await repo.clear();
    return result.when(
      ok: (_) {
        ref.invalidateSelf();
        return null;
      },
      err: (f) => f,
    );
  }
}

final tripHistoryControllerProvider = AutoDisposeAsyncNotifierProvider<
    TripHistoryController, List<TripHistoryEntry>>(
  TripHistoryController.new,
);
