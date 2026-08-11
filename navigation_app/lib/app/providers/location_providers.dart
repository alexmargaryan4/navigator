import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/location_tracker.dart';
import '../../core/permissions/location_permission_handler.dart';
import 'repository_providers.dart';

/// Resolves the current permission/service state once, on demand — call
/// [LocationPermissionNotifier.request] from UI (e.g. the map screen's
/// first frame, or a "enable location" button) rather than requesting
/// automatically on app start, so the OS prompt always has clear context.
class LocationPermissionNotifier extends AsyncNotifier<LocationPermissionState> {
  @override
  Future<LocationPermissionState> build() async {
    // Don't request on build — just report last-known state as "denied"
    // until the UI explicitly asks, to avoid surprising permission
    // prompts before the user has interacted with anything.
    return LocationPermissionState.denied;
  }

  Future<void> request() async {
    final handler = ref.read(locationPermissionHandlerProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(handler.checkAndRequest);
  }
}

final locationPermissionProvider = AsyncNotifierProvider<
    LocationPermissionNotifier, LocationPermissionState>(
  LocationPermissionNotifier.new,
);

/// Idle-cadence GPS stream — suitable for centering the map and showing
/// the user's live position while browsing (not actively navigating).
final idleLocationStreamProvider = StreamProvider.autoDispose<LocationSample>((ref) {
  final tracker = ref.watch(locationTrackerProvider);
  return tracker.idleStream();
});

/// High-frequency GPS stream used only while turn-by-turn navigation is
/// active — kept as a separate provider so it is trivially cancellable
/// (and battery-friendly) the moment navigation ends.
final navigationLocationStreamProvider =
    StreamProvider.autoDispose<LocationSample>((ref) {
  final tracker = ref.watch(locationTrackerProvider);
  return tracker.navigationStream();
});

/// The most recent known location, used to seed the map's initial camera
/// position before the first stream event arrives.
final lastKnownLocationProvider = FutureProvider.autoDispose<LocationSample?>((ref) {
  final tracker = ref.watch(locationTrackerProvider);
  return tracker.lastKnown();
});
