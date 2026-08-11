import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/location_providers.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/geo_point.dart';
import '../../../domain/entities/parking_spot.dart';

/// State for the dedicated Parking feature (product spec §43): a real
/// nearby-parking search around the user's current position.
class ParkingState {
  const ParkingState({
    this.isLoading = false,
    this.spots = const [],
    this.failure,
  });

  final bool isLoading;
  final List<ParkingSpot> spots;
  final AppFailure? failure;

  ParkingState copyWith({
    bool? isLoading,
    List<ParkingSpot>? spots,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return ParkingState(
      isLoading: isLoading ?? this.isLoading,
      spots: spots ?? this.spots,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Loads real nearby parking around the user's last-known location.
///
/// Never invents availability, price, or hours — every [ParkingSpot]
/// field surfaced to the UI traces back to what [ParkingRepository]
/// actually returned (see requirement 43).
class ParkingController extends AutoDisposeNotifier<ParkingState> {
  @override
  ParkingState build() {
    // Kick off an initial search as soon as the screen mounts, centered
    // on wherever we already know the user to be.
    Future.microtask(refresh);
    return const ParkingState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final tracker = ref.read(locationTrackerProvider);
    final last = await tracker.lastKnown();
    final GeoPoint? center = last == null
        ? null
        : GeoPoint(latitude: last.latitude, longitude: last.longitude);

    if (center == null) {
      state = state.copyWith(
        isLoading: false,
        failure: const LocationUnavailableFailure(),
      );
      return;
    }

    final repo = ref.read(parkingRepositoryProvider);
    final result = await repo.nearbyParking(center: center);

    result.when(
      ok: (spots) => state = state.copyWith(isLoading: false, spots: spots),
      err: (f) => state = state.copyWith(isLoading: false, failure: f),
    );
  }
}

final parkingControllerProvider =
    AutoDisposeNotifierProvider<ParkingController, ParkingState>(
  ParkingController.new,
);
