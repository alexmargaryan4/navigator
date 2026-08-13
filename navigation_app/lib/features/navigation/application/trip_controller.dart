import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/location_providers.dart';
import '../../../app/providers/repository_providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/location/location_tracker.dart';
import '../../../domain/entities/favorite_route.dart';
import '../../../domain/entities/geo_point.dart';
import '../../../domain/entities/nav_warning.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/route.dart';
import '../../../domain/entities/route_stop.dart';
import '../../../domain/entities/travel_mode.dart';
import '../../../domain/entities/trip_history_entry.dart';
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

  // How far ahead (product spec «Умные предупреждения»: "заранее, а не
  // в последний момент") each warning category starts surfacing, and
  // the dedupe keys already spoken/shown for the *current* route so a
  // GPS update every second or two doesn't re-announce the same event.
  static const double _turnWarningLeadMeters = 400;
  static const double _complexIntersectionLeadMeters = 600;
  static const double _exitLeadMeters = 700;
  static const double _speedLimitChangeLeadMeters = 250;
  static const double _heavyTrafficLeadMeters = 800;
  final Set<String> _announcedWarningKeys = {};
  bool _announcedSpeeding = false;

  // Origin captured at the moment routes were calculated, kept only so
  // a completed/started trip can be recorded to history with the real
  // start point it was actually calculated from (see _recordHistory) —
  // never re-derived or guessed after the fact.
  GeoPoint? _lastCalculatedOrigin;
  int _idCounter = 0;
  String _newLocalId() => 'stop_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

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
    _announcedWarningKeys.clear();
    _announcedSpeeding = false;
    state = state.copyWith(
      phase: TripPhase.destinationSelected,
      destination: place,
      stops: const [],
      routes: const [],
      clearSelectedRouteId: true,
      clearFailure: true,
    );
  }

  void clearDestination() {
    _navSub?.cancel();
    _announcedStepIndices.clear();
    _announcedWarningKeys.clear();
    _announcedSpeeding = false;
    state = TripState.idleState;
  }

  // -------------------------------------------------------------------
  // Multi-stop trips (spec «Маршрут с несколькими остановками»)
  // -------------------------------------------------------------------

  /// Appends [place] as a new stop before the destination. Requires a
  /// destination to already be selected — a stop is meaningless without
  /// a final destination to route toward.
  void addStop(Place place) {
    if (state.destination == null) return;
    final stop = RouteStop(id: _newLocalId(), place: place);
    state = state.copyWith(stops: [...state.stops, stop]);
    if (state.phase == TripPhase.routePreview) {
      calculateRoutes();
    }
  }

  void removeStop(String stopId) {
    state = state.copyWith(
      stops: state.stops.where((s) => s.id != stopId).toList(),
    );
    if (state.phase == TripPhase.routePreview) {
      calculateRoutes();
    }
  }

  /// Moves the stop at [oldIndex] to [newIndex] (drag-and-drop
  /// reordering) and recalculates the route so it reflects the new
  /// visiting order, per the product requirement that reordering always
  /// triggers a fresh calculation rather than just reshuffling the list.
  void reorderStops(int oldIndex, int newIndex) {
    final stops = [...state.stops];
    if (oldIndex < 0 || oldIndex >= stops.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    target = target.clamp(0, stops.length - 1);
    final moved = stops.removeAt(oldIndex);
    stops.insert(target, moved);
    state = state.copyWith(stops: stops);
    if (state.phase == TripPhase.routePreview) {
      calculateRoutes();
    }
  }

  /// Replaces the final destination, keeping any existing stops.
  void setDestination(Place place) {
    state = state.copyWith(destination: place, clearFailure: true);
    if (state.phase == TripPhase.routePreview) {
      calculateRoutes();
    }
  }

  /// Re-launches a previously saved/completed trip (a [FavoriteRoute] or
  /// a [TripHistoryEntry], both reduced to plain endpoints by the
  /// caller) using the endpoints' own real, previously-resolved
  /// coordinates — never re-geocoded or guessed. [stopEndpoints] become
  /// this trip's stops, [destinationEndpoint] its destination.
  Future<void> startTripFromEndpoints({
    required Place destinationPlace,
    List<Place> stopPlaces = const [],
    TravelMode? mode,
  }) async {
    _announcedStepIndices.clear();
    _announcedWarningKeys.clear();
    _announcedSpeeding = false;
    state = state.copyWith(
      phase: TripPhase.destinationSelected,
      destination: destinationPlace,
      stops: stopPlaces
          .map((p) => RouteStop(id: _newLocalId(), place: p))
          .toList(),
      mode: mode ?? state.mode,
      routes: const [],
      clearSelectedRouteId: true,
      clearFailure: true,
    );
    await calculateRoutes();
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
    _lastCalculatedOrigin = origin;

    state = state.copyWith(isCalculatingRoute: true, clearFailure: true);

    final repo = ref.read(routingRepositoryProvider);
    final result = state.stops.isEmpty
        ? await repo.calculateRoute(
            origin: origin,
            destination: destination.location,
            mode: state.mode,
            options: state.options,
          )
        : await repo.calculateMultiStopRoute(
            origin: origin,
            waypoints: state.stops.map((s) => s.place.location).toList(),
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
        .map((r) => r.id == sorted.first.id ? r.copyWith(isPrimary: true) : r)
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
    // Guards against double-invocation (e.g. a fast double-tap on the
    // "Start Navigation" button landing before the UI has rebuilt past
    // routePreview) re-running the whole method — which would recreate
    // the GPS subscription and, critically, write a *second*
    // TripHistoryStatus.started entry for the same trip.
    if (state.selectedRoute == null || state.phase == TripPhase.navigating) {
      return;
    }

    _announcedStepIndices.clear();
    _announcedWarningKeys.clear();
    _announcedSpeeding = false;
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

    _recordHistory(TripHistoryStatus.started);
  }

  void stopNavigation() {
    _navSub?.cancel();
    _navSub = null;
    ref.read(textToSpeechServiceProvider).stop();
    _announcedStepIndices.clear();
    _announcedWarningKeys.clear();
    _announcedSpeeding = false;
    state = state.copyWith(
      phase: TripPhase.routePreview,
      currentStepIndex: 0,
    );
  }

  void endTrip() {
    // Reaching (or nearly reaching) the last maneuver counts as
    // completed for history purposes; ending earlier is recorded as
    // merely started — a real, if approximate, signal derived from
    // actual route progress rather than an arbitrary flag.
    final route = state.selectedRoute;
    if (route != null && state.phase == TripPhase.navigating) {
      final isNearEnd = route.steps.isEmpty ||
          state.currentStepIndex >= route.steps.length - 1;
      _recordHistory(
        isNearEnd ? TripHistoryStatus.completed : TripHistoryStatus.started,
      );
    }

    _navSub?.cancel();
    _navSub = null;
    ref.read(textToSpeechServiceProvider).stop();
    _announcedStepIndices.clear();
    _announcedWarningKeys.clear();
    _announcedSpeeding = false;
    state = TripState.idleState;
  }

  /// Persists this trip to local history (product spec «История
  /// маршрутов»). Every figure recorded is the routing provider's own
  /// number for the *selected* route — never recomputed or guessed.
  Future<void> _recordHistory(TripHistoryStatus status) async {
    final destination = state.destination;
    final route = state.selectedRoute;
    final origin = _lastCalculatedOrigin;
    if (destination == null || route == null || origin == null) return;

    final entry = TripHistoryEntry(
      id: 'trip_${DateTime.now().microsecondsSinceEpoch}',
      origin: FavoriteRouteEndpoint(
        name: 'Start',
        address: '',
        location: origin,
      ),
      destination: FavoriteRouteEndpoint(
        name: destination.name,
        address: destination.address,
        location: destination.location,
      ),
      stops: state.stops
          .map((s) => FavoriteRouteEndpoint(
                name: s.place.name,
                address: s.place.address,
                location: s.place.location,
              ))
          .toList(),
      mode: state.mode,
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
      date: DateTime.now(),
      status: status,
    );

    final repo = ref.read(tripHistoryRepositoryProvider);
    await repo.add(entry);
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

    // Current real speed (product spec «Ограничение скорости»: "также
    // показывай текущую скорость пользователя") — straight from the
    // GPS sample, converted to km/h; left as null when the platform
    // hasn't supplied a speed reading rather than showing a stale or
    // guessed figure.
    final currentSpeedKph = sample.speedMps == null ? null : sample.speedMps! * 3.6;

    // The real posted speed limit at the user's current position,
    // looked up from the routing provider's own maxspeed annotations —
    // never fabricated when the provider has no data for this stretch.
    final geometryIndex = _nearestGeometryIndex(route, userPoint);
    final currentSpeedLimitKph = route.speedLimitAt(geometryIndex);

    final warnings = _buildWarnings(
      route: route,
      geometryIndex: geometryIndex,
      userPoint: userPoint,
      nextStep: nextStep,
      distanceToNextStep: distanceToNext,
    );

    _announceWarnings(warnings, tts);
    _announceSpeedingIfNeeded(
      currentSpeedKph: currentSpeedKph,
      currentSpeedLimitKph: currentSpeedLimitKph,
      tts: tts,
    );

    state = state.copyWith(
      currentStepIndex: nextIndex,
      remainingDistanceMeters: remainingDistance,
      remainingDurationSeconds: remainingDuration,
      currentSpeedKph: currentSpeedKph,
      clearCurrentSpeedKph: currentSpeedKph == null,
      currentSpeedLimitKph: currentSpeedLimitKph,
      clearCurrentSpeedLimitKph: currentSpeedLimitKph == null,
      activeWarnings: warnings,
    );
  }

  double get lastBearing => _lastBearing;

  /// Index into [NavRoute.geometry] of the point nearest [userPoint] —
  /// the coordinate space [NavRoute.speedLimitAt] and
  /// [NavRoute.trafficSegments] are indexed against, which is denser
  /// and distinct from the maneuver-level [NavRoute.steps] list. A
  /// linear scan is deliberate and cheap enough here: route geometries
  /// for a single trip are at most a few thousand points, and this runs
  /// once per GPS sample (roughly once a second), not per frame.
  int _nearestGeometryIndex(NavRoute route, GeoPoint userPoint) {
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < route.geometry.length; i++) {
      final distance = _distanceMeters(userPoint, route.geometry[i]);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  /// Builds this update's proactive warning list (product spec «Умные
  /// предупреждения») entirely from real data already attached to the
  /// active route — the upcoming maneuver's own type/road name, and the
  /// routing provider's own traffic/speed-limit annotations. Nothing
  /// here is invented: a category with no real data backing it (road
  /// closures, roadworks, hazards — none of which Mapbox's Directions
  /// API supplies) simply never appears.
  List<NavWarning> _buildWarnings({
    required NavRoute route,
    required int geometryIndex,
    required GeoPoint userPoint,
    required RouteStep nextStep,
    required double distanceToNextStep,
  }) {
    final warnings = <NavWarning>[];

    // Upcoming turn / complex intersection / exit — all derived from
    // the same real next maneuver, split into the product's three
    // categories by its real maneuver type.
    final maneuverType = nextStep.maneuverType;
    if (maneuverType.contains('roundabout') || maneuverType.contains('rotary')) {
      if (distanceToNextStep <= _complexIntersectionLeadMeters) {
        warnings.add(NavWarning(
          type: NavWarningType.complexIntersection,
          distanceMeters: distanceToNextStep,
          roadName: nextStep.roadName,
        ));
      }
    } else if (maneuverType.contains('ramp') || maneuverType.contains('exit')) {
      if (distanceToNextStep <= _exitLeadMeters) {
        warnings.add(NavWarning(
          type: NavWarningType.upcomingExit,
          distanceMeters: distanceToNextStep,
          roadName: nextStep.roadName,
        ));
      }
    } else if (maneuverType.contains('turn') &&
        distanceToNextStep <= _turnWarningLeadMeters) {
      warnings.add(NavWarning(
        type: NavWarningType.upcomingTurn,
        distanceMeters: distanceToNextStep,
        roadName: nextStep.roadName,
      ));
    }

    // Speed-limit change ahead — only ever built from a real, different
    // SpeedLimitSegment than the one the user is currently in.
    final currentLimit = route.speedLimitAt(geometryIndex);
    for (final segment in route.speedLimitSegments) {
      if (segment.startIndex <= geometryIndex) continue;
      final distanceAhead =
          _distanceMeters(userPoint, route.geometry[segment.startIndex]);
      if (distanceAhead > _speedLimitChangeLeadMeters) continue;
      if (currentLimit != null && (segment.speedKph - currentLimit).abs() < 0.01) {
        break;
      }
      warnings.add(NavWarning(
        type: NavWarningType.speedLimitChange,
        distanceMeters: distanceAhead,
        speedKph: segment.speedKph,
      ));
      break;
    }

    // Heavy/severe traffic ahead — only from the provider's own
    // congestion annotation for this route.
    for (final segment in route.trafficSegments) {
      if (segment.startIndex <= geometryIndex) continue;
      if (segment.level != TrafficLevel.heavy && segment.level != TrafficLevel.severe) {
        continue;
      }
      final distanceAhead =
          _distanceMeters(userPoint, route.geometry[segment.startIndex]);
      if (distanceAhead > _heavyTrafficLeadMeters) continue;
      warnings.add(NavWarning(
        type: NavWarningType.heavyTraffic,
        distanceMeters: distanceAhead,
      ));
      break;
    }

    warnings.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return warnings;
  }

  /// Speaks each new warning exactly once (product spec: "заранее, а не
  /// в последний момент" + visual *and* voice together) — dedupe keyed
  /// off [NavWarning.dedupeKey] so repeated GPS samples while still
  /// approaching the same event don't re-announce it.
  void _announceWarnings(List<NavWarning> warnings, dynamic tts) {
    for (final warning in warnings) {
      final key = warning.dedupeKey;
      if (_announcedWarningKeys.contains(key)) continue;
      _announcedWarningKeys.add(key);

      final phrase = switch (warning.type) {
        NavWarningType.heavyTraffic => ManeuverPhrasing.heavyTrafficAhead,
        NavWarningType.speedLimitChange =>
          ManeuverPhrasing.speedLimitChangeAhead(warning.speedKph!),
        // Turn/intersection/exit warnings are already covered by the
        // primary maneuver announcement in the caller — this list only
        // adds the visual "look ahead" card for those, to avoid
        // speaking the same upcoming turn twice.
        NavWarningType.upcomingTurn ||
        NavWarningType.complexIntersection ||
        NavWarningType.upcomingExit =>
          null,
      };
      if (phrase != null) {
        tts.speak(phrase);
      }
    }
  }

  /// Speaks a speeding warning once per "speeding episode" — i.e. once
  /// when the user's real speed first exceeds the real limit, then
  /// stays silent until they've dropped back under it, so it doesn't
  /// repeat every second while still over. Both figures must be real
  /// (see [TripState.isSpeeding]) — never triggered from a guess.
  void _announceSpeedingIfNeeded({
    required double? currentSpeedKph,
    required double? currentSpeedLimitKph,
    required dynamic tts,
  }) {
    const tolerance = 5.0;
    final isSpeeding = currentSpeedKph != null &&
        currentSpeedLimitKph != null &&
        currentSpeedKph > currentSpeedLimitKph + tolerance;

    if (isSpeeding && !_announcedSpeeding) {
      _announcedSpeeding = true;
      tts.speak(ManeuverPhrasing.speedingWarning(currentSpeedLimitKph));
    } else if (!isSpeeding) {
      _announcedSpeeding = false;
    }
  }

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
