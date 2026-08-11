import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/location_providers.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/location/location_tracker.dart';
import '../../../domain/entities/geo_point.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/route.dart';
import '../../../domain/entities/travel_mode.dart';
import '../../../domain/repositories/routing_repository.dart';
import '../../../services/voice/maneuver_phrasing.dart';
import 'trip_state.dart';

/// Owns the entire trip lifecycle: destination selection → route
/// calculation → route preview → active turn-by-turn navigation.
///
/// This is intentionally the *only* place that mutates [TripState] — the
/// map, route-preview sheet, and navigation HUD all read from it and
/// call its methods, so there is exactly one source of truth for what
/// the current trip looks like (spec §20-24).
class TripController extends Notifier<TripState> {
  StreamSubscription<LocationSample>? _navSub;
  double _lastBearing = 0;
  static const double _offRouteThresholdMeters = 45;
  static const double _maneuverAnnounceThresholdMeters = 300;
  final Set<int> _announcedStepIndices = {};

  @override
  TripState build() {
    ref.onDispose(() => _navSub?.cancel());
    return TripState.idleState;
  }

  // -------------------------------------------------------------------
  // Destination selection
  // -------------------------------------------------------------------

  void selectDestination(Place place) {
    _announcedStepIndices.clear();
    state = state.copyWith(
      phase: TripPhase.destinationSelected,
      destination: place,
      routes: const [],
      clearSelectedRouteId: true,
      clearFailure: true,
    );
  }

  void clearDestination() {
    _navSub?.cancel();
    _announcedStepIndices.clear();
    state = TripState.idleState;
  }

  void setMode(TravelMode mode) {
    state = state.copyWith(mode: mode);
    if (state.phase == TripPhase.routePreview) {
      calculateRoutes();
    }
  }

  void setOptions(RouteOptions options) {
    state = state.copyWith(options: options);
    if (state.phase == TripPhase.routePreview) {
      calculateRoutes();
    }
  }

  void selectRoute(String routeId) {
    state = state.copyWith(selectedRouteId: routeId);
  }

  // -------------------------------------------------------------------
  // Route calculation (spec §21: destination marker → routes sequence)
  // -------------------------------------------------------------------

  Future<void> calculateRoutes() async {
    final destination = state.destination;
    if (destination == null) return;

    final origin = await _resolveOrigin();
    if (origin == null) {
      state = state.copyWith(
        failure: const LocationUnavailableFailure(),
      );
      return;
    }

    state = state.copyWith(isCalculatingRoute: true, clearFailure: true);

    final repo = ref.read(routingRepositoryProvider);
    final result = await repo.calculateRoute(
      origin: origin,
      destination: destination.location,
      mode: state.mode,
      options: state.options,
    );

    result.when(
      ok: (routes) {
        final marked = _markPrimary(routes);
        state = state.copyWith(
          phase: TripPhase.routePreview,
          routes: marked,
          clearSelectedRouteId: true,
          isCalculatingRoute: false,
        );
      },
      err: (f) {
        state = state.copyWith(isCalculatingRoute: false, failure: f);
      },
    );
  }

  List<NavRoute> _markPrimary(List<NavRoute> routes) {
    if (routes.isEmpty) return routes;
    if (routes.any((r) => r.isPrimary)) return routes;
    // The provider doesn't flag a primary route itself — the shortest
    // duration among real results is used as the recommended one.
    final sorted = [...routes]..sort(
        (a, b) => a.durationSeconds.compareTo(b.durationSeconds));
    return routes
        .map((r) => r.id == sorted.first.id
            ? NavRoute(
                id: r.id,
                mode: r.mode,
                geometry: r.geometry,
                distanceMeters: r.distanceMeters,
                durationSeconds: r.durationSeconds,
                steps: r.steps,
                trafficSegments: r.trafficSegments,
                hasTolls: r.hasTolls,
                isPrimary: true,
              )
            : r)
        .toList();
  }

  Future<GeoPoint?> _resolveOrigin() async {
    final tracker = ref.read(locationTrackerProvider);
    final last = await tracker.lastKnown();
    if (last != null) {
      return GeoPoint(latitude: last.latitude, longitude: last.longitude);
    }
    try {
      final current = await tracker.current();
      return GeoPoint(latitude: current.latitude, longitude: current.longitude);
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------
  // Active navigation (spec §22-24, §50: turn-by-turn)
  // -------------------------------------------------------------------

  void startNavigation() {
    if (state.selectedRoute == null) return;

    _announcedStepIndices.clear();
    state = state.copyWith(
      phase: TripPhase.navigating,
      currentStepIndex: 0,
      isFollowingUser: true,
      remainingDistanceMeters: state.selectedRoute!.distanceMeters,
      remainingDurationSeconds: state.selectedRoute!.durationSeconds,
    );

    final tts = ref.read(textToSpeechServiceProvider);
    final tracker = ref.read(locationTrackerProvider);

    _navSub?.cancel();
    _navSub = tracker.navigationStream().listen((sample) {
      _onLocationUpdate(sample, tts);
    });
  }

  void stopNavigation() {
    _navSub?.cancel();
    _navSub = null;
    ref.read(textToSpeechServiceProvider).stop();
    _announcedStepIndices.clear();
    state = state.copyWith(
      phase: TripPhase.routePreview,
      currentStepIndex: 0,
    );
  }

  void endTrip() {
    _navSub?.cancel();
    _navSub = null;
    ref.read(textToSpeechServiceProvider).stop();
    _announcedStepIndices.clear();
    state = TripState.idleState;
  }

  void setFollowingUser(bool following) {
    state = state.copyWith(isFollowingUser: following);
  }

  void _onLocationUpdate(LocationSample sample, dynamic tts) {
    final route = state.selectedRoute;
    if (route == null || route.steps.isEmpty) return;

    final userPoint = GeoPoint(latitude: sample.latitude, longitude: sample.longitude);
    final stepIndex = state.currentStepIndex.clamp(0, route.steps.length - 1);
    final step = route.steps[stepIndex];

    final distanceToManeuver =
        _distanceMeters(userPoint, step.maneuverLocation);

    // Advance to the next maneuver once close enough that continuing to
    // guide toward this one would be stale.
    var nextIndex = stepIndex;
    if (distanceToManeuver < 20 && stepIndex < route.steps.length - 1) {
      nextIndex = stepIndex + 1;
    }

    // Recompute remaining distance/time from real route geometry rather
    // than fabricating a number: sum this step's remaining distance plus
    // every subsequent step's full distance.
    var remainingDistance = distanceToManeuver;
    var remainingDuration = route.steps[nextIndex].durationSeconds *
        (distanceToManeuver / math.max(step.distanceMeters, 1));
    for (var i = nextIndex + 1; i < route.steps.length; i++) {
      remainingDistance += route.steps[i].distanceMeters;
      remainingDuration += route.steps[i].durationSeconds;
    }

    if (sample.heading != null) {
      _lastBearing = sample.heading!;
    }

    if (nextIndex != stepIndex) {
      _announcedStepIndices.clear();
    }

    // Voice guidance: announce once per step, when within the standard
    // "in 300 meters" threshold (spec §49-50).
    final nextStep = route.steps[nextIndex];
    final distanceToNext = nextIndex == stepIndex
        ? distanceToManeuver
        : _distanceMeters(userPoint, nextStep.maneuverLocation);
    if (distanceToNext <= _maneuverAnnounceThresholdMeters &&
        !_announcedStepIndices.contains(nextIndex)) {
      _announcedStepIndices.add(nextIndex);
      final phrase = ManeuverPhrasing.upcoming(nextStep, distanceMeters: distanceToNext);
      tts.speak(phrase);
    }

    state = state.copyWith(
      currentStepIndex: nextIndex,
      remainingDistanceMeters: remainingDistance,
      remainingDurationSeconds: remainingDuration,
    );
  }

  double get lastBearing => _lastBearing;

  double _distanceMeters(GeoPoint a, GeoPoint b) {
    const earthRadius = 6371000.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(lat1) * math.cos(lat2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadius * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);
}

final tripControllerProvider =
    NotifierProvider<TripController, TripState>(TripController.new);
