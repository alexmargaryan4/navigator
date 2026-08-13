import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/geo_point.dart';
import '../../../domain/entities/nav_warning.dart';
import '../../../domain/entities/place.dart';
import '../../../domain/entities/route.dart';
import '../../../domain/entities/route_stop.dart';
import '../../../domain/entities/travel_mode.dart';
import '../../../domain/repositories/routing_repository.dart';

/// The lifecycle stage of a trip, from an idle map through to active
/// turn-by-turn guidance (product spec §20-23).
enum TripPhase {
  /// No destination selected — plain map browsing.
  idle,

  /// A destination has been picked (search result, POI, or AI command)
  /// and its info card is showing, but routes haven't been requested yet.
  destinationSelected,

  /// Routes have been calculated and are shown for the user to review /
  /// pick between alternatives, before committing to navigation.
  routePreview,

  /// Turn-by-turn navigation is actively running.
  navigating,
}

/// The single source of truth for "what trip is the user planning or
/// running right now" — shared by the map, route-preview sheet, and
/// active-navigation UI so they always agree on state.
class TripState {
  const TripState({
    this.phase = TripPhase.idle,
    this.destination,
    this.stops = const [],
    this.mode = TravelMode.driving,
    this.options = const RouteOptions(),
    this.routes = const [],
    this.selectedRouteId,
    this.isCalculatingRoute = false,
    this.failure,
    this.currentStepIndex = 0,
    this.remainingDistanceMeters,
    this.remainingDurationSeconds,
    this.isFollowingUser = true,
    this.currentSpeedKph,
    this.currentSpeedLimitKph,
    this.activeWarnings = const [],
  });

  final TripPhase phase;
  final Place? destination;

  /// Intermediate stops for a multi-stop trip (product spec «Маршрут с
  /// несколькими остановками»), in visiting order. Empty for a plain
  /// A→B trip. Ordering here is the single source of truth the route is
  /// calculated against — reordering (drag-and-drop) recalculates.
  final List<RouteStop> stops;
  final TravelMode mode;
  final RouteOptions options;
  final List<NavRoute> routes;
  final String? selectedRouteId;
  final bool isCalculatingRoute;
  final AppFailure? failure;

  /// Index into the active route's [NavRoute.steps] for the maneuver
  /// currently being guided.
  final int currentStepIndex;

  /// Live-updating remaining distance/time during active navigation,
  /// recomputed from GPS progress against the active route — never
  /// re-fabricated, only derived from real route geometry.
  final double? remainingDistanceMeters;
  final double? remainingDurationSeconds;

  /// Whether the map camera should keep following the user (spec §52) —
  /// set to `false` the moment the user manually pans the map.
  final bool isFollowingUser;

  /// The user's real, GPS-reported ground speed right now, in km/h
  /// (product spec «Ограничение скорости»). `null` whenever the
  /// platform hasn't supplied a speed sample yet — never a guessed
  /// value.
  final double? currentSpeedKph;

  /// The real, provider-reported speed limit at the user's current
  /// position on the active route, in km/h. `null` whenever the
  /// routing provider has no data for this stretch of road — the UI
  /// must render "no data" rather than a fabricated number.
  final double? currentSpeedLimitKph;

  /// Proactive, ahead-of-time warnings for the active route (product
  /// spec «Умные предупреждения»), nearest first — every entry is
  /// derived from real route data, see [NavWarning].
  final List<NavWarning> activeWarnings;

  /// Whether the user's current real speed exceeds the real posted
  /// limit — `false` whenever either figure is unavailable, since a
  /// speeding warning must never be shown on a guess.
  bool get isSpeeding {
    final speed = currentSpeedKph;
    final limit = currentSpeedLimitKph;
    if (speed == null || limit == null) return false;
    return speed > limit + _speedingToleranceKph;
  }

  static const double _speedingToleranceKph = 5;

  NavRoute? get selectedRoute {
    if (routes.isEmpty) return null;
    if (selectedRouteId == null) {
      return routes.where((r) => r.isPrimary).firstOrNull ?? routes.first;
    }
    for (final r in routes) {
      if (r.id == selectedRouteId) return r;
    }
    return routes.first;
  }

  bool get isActive => phase == TripPhase.navigating;

  /// Whether this trip currently has intermediate stops (product spec
  /// «Маршрут с несколькими остановками»).
  bool get isMultiStop => stops.isNotEmpty;

  TripState copyWith({
    TripPhase? phase,
    Place? destination,
    bool clearDestination = false,
    List<RouteStop>? stops,
    TravelMode? mode,
    RouteOptions? options,
    List<NavRoute>? routes,
    String? selectedRouteId,
    bool clearSelectedRouteId = false,
    bool? isCalculatingRoute,
    AppFailure? failure,
    bool clearFailure = false,
    int? currentStepIndex,
    double? remainingDistanceMeters,
    double? remainingDurationSeconds,
    bool? isFollowingUser,
    double? currentSpeedKph,
    bool clearCurrentSpeedKph = false,
    double? currentSpeedLimitKph,
    bool clearCurrentSpeedLimitKph = false,
    List<NavWarning>? activeWarnings,
  }) {
    return TripState(
      phase: phase ?? this.phase,
      destination: clearDestination ? null : (destination ?? this.destination),
      stops: stops ?? this.stops,
      mode: mode ?? this.mode,
      options: options ?? this.options,
      routes: routes ?? this.routes,
      selectedRouteId:
          clearSelectedRouteId ? null : (selectedRouteId ?? this.selectedRouteId),
      isCalculatingRoute: isCalculatingRoute ?? this.isCalculatingRoute,
      failure: clearFailure ? null : (failure ?? this.failure),
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      remainingDistanceMeters:
          remainingDistanceMeters ?? this.remainingDistanceMeters,
      remainingDurationSeconds:
          remainingDurationSeconds ?? this.remainingDurationSeconds,
      isFollowingUser: isFollowingUser ?? this.isFollowingUser,
      currentSpeedKph: clearCurrentSpeedKph
          ? null
          : (currentSpeedKph ?? this.currentSpeedKph),
      currentSpeedLimitKph: clearCurrentSpeedLimitKph
          ? null
          : (currentSpeedLimitKph ?? this.currentSpeedLimitKph),
      activeWarnings: activeWarnings ?? this.activeWarnings,
    );
  }

  static const idleState = TripState();
}

/// Small null-safe convenience used by [TripState.selectedRoute].
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Placeholder for a resolved origin point — kept here rather than in
/// [TripState] since origin always tracks live GPS, not trip selection.
class TripOrigin {
  const TripOrigin(this.point);
  final GeoPoint point;
}
